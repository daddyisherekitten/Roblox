/* The methods used by the game's basic.js, for the Roblox HTML runtime.
   The desktop preview retains its original jQuery library. */
(function (global) {
  function Query(input) {
    if (!(this instanceof Query)) return new Query(input);
    var values;
    if (typeof input === 'string') values = document.querySelectorAll(input);
    else if (input instanceof Query) return input;
    else values = input == null ? [] : [input];
    this.length = values.length;
    for (var i = 0; i < values.length; i++) this[i] = values[i];
  }
  Query.fn = Query.prototype;
  Query.fn.eq = function (index) {
    if (index < 0) index += this.length;
    return Query(this[index]);
  };
  Query.fn.text = function (value) {
    if (value === undefined) return this.length ? this[0].textContent : '';
    for (var i = 0; i < this.length; i++) this[i].textContent = String(value);
    return this;
  };
  Query.fn.append = function (html) {
    for (var i = 0; i < this.length; i++) {
      var fragment = document.createElement('div');
      fragment.innerHTML = String(html);
      while (fragment.firstChild) this[i].appendChild(fragment.firstChild);
    }
    return this;
  };
  Query.fn.attr = function (name, value) {
    if (value === undefined && typeof name === 'string') return this.length ? this[0].getAttribute(name) : undefined;
    for (var i = 0; i < this.length; i++) {
      if (typeof name === 'object') {
        for (var key in name) this[i].setAttribute(key, name[key]);
      } else this[i].setAttribute(name, value);
    }
    return this;
  };
  Query.fn.css = function (name, value) {
    for (var i = 0; i < this.length; i++) this[i].style.setProperty(name, value);
    return this;
  };
  Query.fn.html = function (value) {
    if (value === undefined) return this.length ? this[0].innerHTML : '';
    for (var i = 0; i < this.length; i++) this[i].innerHTML = String(value);
    return this;
  };
  Query.fn.val = function (value) {
    if (value === undefined) return this.length ? this[0].value : undefined;
    for (var i = 0; i < this.length; i++) this[i].value = String(value);
    return this;
  };
  Query.fn.ready = function (callback) {
    if (document.readyState === 'loading') document.addEventListener('DOMContentLoaded', callback);
    else callback();
    return this;
  };
  Query.fn.on = function (events, callback) {
    var names = String(events).split(/\s+/);
    for (var i = 0; i < this.length; i++) for (var j = 0; j < names.length; j++) if (names[j]) this[i].addEventListener(names[j], callback);
    return this;
  };
  Query.fn.click = function (callback) {
    if (callback !== undefined) return this.on('click', callback);
    for (var i = 0; i < this.length; i++) this[i].click();
    return this;
  };
  Query.fn.removeAttr = function (names) {
    var keys = String(names).split(/\s+/);
    for (var i = 0; i < this.length; i++) for (var j = 0; j < keys.length; j++) if (keys[j]) this[i].removeAttribute(keys[j]);
    return this;
  };
  function changeClass(query, names, add) {
    var changes = String(names).split(/\s+/);
    for (var i = 0; i < query.length; i++) {
      var current = String(query[i].getAttribute('class') || '').split(/\s+/).filter(function (value) { return value !== ''; });
      for (var j = 0; j < changes.length; j++) {
        var index = current.indexOf(changes[j]);
        if (add && index < 0 && changes[j]) current.push(changes[j]);
        else if (!add && index >= 0) current.splice(index, 1);
      }
      query[i].setAttribute('class', current.join(' '));
    }
    return query;
  }
  Query.fn.addClass = function (names) { return changeClass(this, names, true); };
  Query.fn.removeClass = function (names) { return changeClass(this, names, false); };
  Query.fn.data = function (name) {
    if (!this.length) return undefined;
    var value = this[0].getAttribute('data-' + name);
    if (value === null) return undefined;
    var number = Number(value);
    return String(number) === value ? number : value;
  };
  // The archive uses these effects for short service messages. Visibility is
  // immediate in the Roblox adapter; the browser retains original jQuery fades.
  Query.fn.hide = function () { return this.css('display', 'none'); };
  Query.fn.show = function () { return this.css('display', ''); };
  Query.fn.fadeIn = function () { return this.show(); };
  Query.fn.fadeOut = function () { return this.hide(); };
  Query.fn.delay = function () { return this; };
  Query.inArray = function (value, array) { return array.indexOf(value); };
  Query.get = function (url, callback) { return global.WTTG2Host.requestStats('GET', url, null, callback); };
  Query.post = function (url, data, callback) { return global.WTTG2Host.requestStats('POST', url, data, callback); };
  Query.fn.width = function () { return !this.length ? undefined : this[0] === global ? global.innerWidth : this[0].getBoundingClientRect().width; };
  Query.fn.height = function () { return !this.length ? undefined : this[0] === global ? global.innerHeight : this[0].getBoundingClientRect().height; };
  global.jQuery = global.$ = Query;
}(window));
