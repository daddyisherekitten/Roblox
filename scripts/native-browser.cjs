// Isolated headless Chromium for native reference captures. Never attaches to
// the user's browser. Closing the CDP browser also closes its child processes.
const fs = require('node:fs'), path = require('node:path'), cp = require('node:child_process');
async function openBrowser(folder, options = {}) {
  const blinkFeatures = options.blinkFeatures || [];
  if (!Array.isArray(blinkFeatures) || blinkFeatures.some(value => !/^[A-Za-z][A-Za-z0-9]*$/.test(value))) {
    throw new TypeError('Invalid native capture Blink feature name');
  }
  const profile = path.join(folder, 'chrome-' + Date.now() + '-' + process.pid);
  fs.mkdirSync(profile, { recursive: true });
  const processHandle = cp.spawn(process.env.CHROME_BIN || 'C:/Program Files/Google/Chrome/Application/chrome.exe', [
    '--headless=new', '--disable-gpu', '--no-first-run', '--disable-background-networking',
    '--remote-debugging-port=0', '--user-data-dir=' + profile,
    ...(blinkFeatures.length ? ['--enable-blink-features=' + blinkFeatures.join(',')] : []), 'about:blank',
  ], { windowsHide: true, stdio: ['ignore', 'ignore', 'pipe'] });
  let launchError, stderr = '';
  processHandle.on('error', error => { launchError = error; });
  processHandle.stderr.on('data', chunk => { stderr = (stderr + chunk).slice(-8192); });
  let socket, nextId = 0;
  const pending = new Map(), events = new Map();
  const close = async () => {
    if (socket?.readyState === WebSocket.OPEN) {
      try { await send('Browser.close'); } catch { /* Chrome may close before replying. */ }
    }
    socket?.close();
    if (processHandle.exitCode === null) processHandle.kill();
  };
  function send(method, params = {}, sessionId) {
    return new Promise((resolve, reject) => {
      const id = ++nextId;
      const timer = setTimeout(() => { pending.delete(id); reject(new Error('CDP timeout: ' + method)); }, 10000);
      pending.set(id, { resolve, reject, timer });
      socket.send(JSON.stringify({ id, method, params, ...(sessionId ? { sessionId } : {}) }));
    });
  }
  function event(method) {
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => { events.delete(method); reject(new Error('CDP event timeout: ' + method)); }, 10000);
      events.set(method, { resolve, reject, timer });
    });
  }
  try {
    const activePort = path.join(profile, 'DevToolsActivePort');
    const deadline = Date.now() + 10000;
    let port;
    while (!port) {
      if (launchError) throw launchError;
      if (processHandle.exitCode !== null || Date.now() > deadline) throw new Error('Chrome failed to start: ' + stderr);
      try {
        const lines = fs.readFileSync(activePort, 'utf8').trim().split('\n');
        const value = Number(lines[0]);
        if (lines.length >= 2 && Number.isInteger(value) && value > 0 && value <= 65535) port = value;
      } catch (error) {
        if (!['ENOENT', 'EBUSY', 'EACCES'].includes(error.code)) throw error;
      }
      if (port) break;
      await new Promise(resolve => setTimeout(resolve, 50));
    }
    const pages = await (await fetch('http://localhost:' + port + '/json/list')).json();
    const page = pages.find(value => value.type === 'page');
    if (!page) throw new Error('Chrome has no reference page');
    socket = new WebSocket(page.webSocketDebuggerUrl);
    await new Promise((resolve, reject) => { socket.addEventListener('open', resolve, { once: true }); socket.addEventListener('error', reject, { once: true }); });
    socket.addEventListener('message', message => {
      const value = JSON.parse(message.data);
      const entry = value.id ? pending.get(value.id) : events.get(value.method);
      if (!entry) return;
      clearTimeout(entry.timer);
      if (value.id) pending.delete(value.id); else events.delete(value.method);
      if (value.error) entry.reject(new Error(value.error.message)); else entry.resolve(value.result || value.params);
    });
    socket.addEventListener('close', () => {
      for (const entries of [pending, events]) {
        for (const entry of entries.values()) { clearTimeout(entry.timer); entry.reject(new Error('Chrome closed')); }
        entries.clear();
      }
    });
    await send('Page.enable'); await send('Runtime.enable');
    await send('Emulation.setDeviceMetricsOverride', { width: 800, height: 600, deviceScaleFactor: 1, mobile: false });
    async function evaluate(expression) {
      const value = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
      if (value.exceptionDetails) throw new Error(value.exceptionDetails.exception?.description || value.exceptionDetails.text);
      return value.result.value;
    }
    return {
      send, evaluate, close,
      async load(html) {
        const loaded = event('Page.loadEventFired');
        await Promise.all([send('Page.navigate', { url: 'data:text/html;charset=utf-8,' + encodeURIComponent(html) }), loaded]);
      },
    };
  } catch (error) { await close(); throw error; }
}
module.exports = { openBrowser };
