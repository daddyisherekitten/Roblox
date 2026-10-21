/* Inject WTTG2_PORT before this file: {pages:[canonical paths], sites:[
   {host:"local-alias.ann",path:"/site/index.html",title,description,dead:false}
   ], unavailablePath:"/unavailable/index.html"}. Paths stay on this local origin. */
(function (global) {
  var config = global.WTTG2_PORT || {};
  var pages = config.pageMap || Object.create(null);
  var aliases = config.aliasIndex || Object.create(null);
  var sites = config.sites || [];
  var memoryVisited = Object.create(null);
  var origin = global.location.origin;
  var unavailable = config.unavailablePath || '/unavailable/index.html';
  var wikiBuilt = false;
  var namedSites = config.siteIndex || Object.create(null);

  function pathOf(value) {
    var url = new URL(String(value), global.location.href);
    if (url.origin !== origin) return null;
    var path = url.pathname;
    if (path.charAt(path.length - 1) === '/') path += 'index.html';
    return {path:path, suffix:url.search + url.hash};
  }
  for (var i = 0; !config.pageMap && i < (config.pages || []).length; i++) {
    var page = String(config.pages[i]);
    if (page.charAt(0) === '/' && page.charAt(1) !== '/' && !/[?#]/.test(page)) pages[page.toLowerCase()] = page;
  }
  for (var j = 0; !config.aliasIndex && j < sites.length; j++) {
    if (sites[j].host) aliases[String(sites[j].host).toLowerCase()] = j;
    if (sites[j].name) namedSites[sites[j].name] = j;
  }

  function visited(site) {
    if (memoryVisited[site.host]) return true;
    try { return global.localStorage.getItem('wttg2:visited:' + site.host) === '1'; }
    catch (ignored) { return false; }
  }
  function markVisited(site) {
    memoryVisited[site.host] = true;
    try { global.localStorage.setItem('wttg2:visited:' + site.host, '1'); }
    catch (ignored) {}
  }
  function deadURL(site) {
    var canonical = pages[unavailable.toLowerCase()];
    return canonical ? canonical + '?site=' + encodeURIComponent(site.title || site.host) + '&address=' + encodeURIComponent('http://' + site.host) : null;
  }
  function resolve(value) {
    var url;
    try { url = new URL(String(value), global.location.href); }
    catch (ignored) { return null; }
    var alias = aliases[url.hostname.toLowerCase()];
    var site = alias === undefined ? null : sites[alias];
    if (site) {
      if (site.dead) return deadURL(site);
      var sitePath = site.path;
      if (url.pathname !== '/' && url.pathname !== '/index.html') sitePath = site.path.slice(0, site.path.lastIndexOf('/') + 1) + url.pathname.slice(1);
      var known = pages[sitePath.toLowerCase()];
      return known ? known + url.search + url.hash : null;
    }
    if (url.origin !== origin) return null;
    var local = pathOf(url.href);
    var canonical = local && pages[local.path.toLowerCase()];
    return canonical ? canonical + local.suffix : null;
  }
  function navigate(value) {
    var target = resolve(value);
    if (!target) return false;
    for (var i = 0; i < sites.length; i++) {
      var page = sites[i].path || unavailable;
      var base = page.slice(0, page.lastIndexOf('/') + 1).toLowerCase();
      if (!sites[i].dead && base && target.toLowerCase().indexOf(base) === 0) markVisited(sites[i]);
    }
    global.LinkOut();
    global.location.assign(target);
    return false;
  }
  global.LinkClick = navigate;
  global.SiteClick = navigate;
  // The game handles these cursor hooks natively. The host stylesheet assigns
  // the cursor to their actual targets without mutating inherited root styles.
  global.LinkHover = function () {};
  global.LinkOut = function () {};

  function notifyHook(name) {
    document.dispatchEvent(new CustomEvent('wttg2:hook', {detail:{name:name}}));
  }
  // Game-state providers may subscribe; the port invents no keys or hashes.
  global.PlainKeyShow = function () { notifyHook('PlainKeyShow'); };
  global.FileKeyShow = function () { notifyHook('FileKeyShow'); };
  global.HotSpotHit = function () { notifyHook('HotSpotHit'); };
  var gameHooks = ['TestMem', 'TestNode', 'TestStack', 'TestZone', 'KeyPress', 'HolyClick', 'EmptyClick', 'EndVideo', 'puzzleClickedGood', 'puzzleClickedWrong'];
  for (var hookIndex = 0; hookIndex < gameHooks.length; hookIndex++) (function (name) {
    global[name] = function () { notifyHook(name); };
  }(gameHooks[hookIndex]));
  global.puzzleSolved = function () {
    notifyHook('puzzleSolved');
    var target = resolve(config.puzzleWikiPath || '/wiki3/index.html');
    if (!target) return;
    if (typeof global.presentWiki === 'function') global.presentWiki(origin + target);
    var label = document.getElementById('wiki3');
    if (label) {
      label.setAttribute('onMouseOver', 'LinkHover()');
      label.setAttribute('onMouseOut', 'LinkOut()');
      label.setAttribute('onClick', 'LinkClick("' + target + '")');
    }
  };

  function requestStats(method, url, data, callback) {
    var response;
    try {
      var address = new URL(String(url), global.location.href);
      if (address.hostname !== 'wttg2.reflectstudios.com' || address.pathname !== '/stats.php') return null;
      response = method === 'POST' ? {message:'This local archive does not submit confessions.'} : {data:'The original confession service is unavailable in this local archive.'};
    } catch (ignored) { return null; }
    global.setTimeout(function () { if (typeof callback === 'function') callback(JSON.stringify(response)); }, 0);
    return {abort:function () {}};
  }
  function installJQuery() {
    var jquery = global.jQuery;
    if (!jquery || jquery.__wttg2ServicesInstalled) return;
    var get = jquery.get, post = jquery.post;
    jquery.get = function (url, callback) {
      var request = requestStats('GET', url, null, callback);
      return request || (get ? get.apply(jquery, arguments) : null);
    };
    jquery.post = function (url, data, callback) {
      var request = requestStats('POST', url, data, callback);
      return request || (post ? post.apply(jquery, arguments) : null);
    };
    jquery.__wttg2ServicesInstalled = true;
  }

  function escapeText(value) {
    var text = String(value || '');
    if (!/[&<>"|]/.test(text)) return text;
    return text.replace(/[&<>"|]/g, function (character) {
      return {'&':'&amp;', '<':'&lt;', '>':'&gt;', '"':'&quot;', '|':'&#124;'}[character];
    });
  }
  function buildWiki() {
    if (wikiBuilt || !document.getElementById('wikiLinks') || typeof global.BuildWiki !== 'function') return;
    var data = [];
    var wikiSites = sites;
    var wikiRecords = config.wikis || [];
    for (var recordIndex = 0; recordIndex < wikiRecords.length; recordIndex++) {
      if (String(wikiRecords[recordIndex].path).toLowerCase() !== global.location.pathname.toLowerCase()) continue;
      wikiSites = [];
      var members = wikiRecords[recordIndex].siteNames || [];
      for (var memberIndex = 0; memberIndex < members.length; memberIndex++) if (namedSites[members[memberIndex]] !== undefined) wikiSites.push(sites[namedSites[members[memberIndex]]]);
      break;
    }
    for (var i = 0; i < wikiSites.length; i++) {
      var site = wikiSites[i];
      var host = String(site.host || '').replace(/\.ann$/i, '');
      if (!host || !(site.dead ? pages[unavailable.toLowerCase()] : pages[String(site.path).toLowerCase()])) continue;
      data.push(host + '|' + escapeText(site.title) + '|' + escapeText(site.description) + '|' + (visited(site) ? '1' : '0'));
    }
    global.BuildWiki(data);
    wikiBuilt = true;
  }
  global.WTTG2Host = {resolve:resolve, buildWiki:buildWiki, installJQuery:installJQuery, requestStats:requestStats};
  global.addEventListener('load', buildWiki);
  if (document.readyState === 'complete') buildWiki();
}(window));
