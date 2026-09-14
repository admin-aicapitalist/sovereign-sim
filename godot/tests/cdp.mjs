import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const reports = fileURLToPath(new URL('../reports/', import.meta.url));
const origin = process.env.GODOT_TEST_URL || 'http://127.0.0.1:8131/';
const cdp = process.env.GODOT_CDP_URL || 'http://127.0.0.1:9231';
const page = await (await fetch(`${cdp}/json/new?about:blank`, { method: 'PUT' })).json();
const ws = new WebSocket(page.webSocketDebuggerUrl);
await new Promise(resolve => { ws.onopen = resolve; });
let id = 0;
const pending = new Map(), errors = [], messages = [];
ws.onmessage = event => {
  const m = JSON.parse(event.data);
  if (m.id) {
    const p = pending.get(m.id); pending.delete(m.id);
    if (m.error) p.reject(Error(JSON.stringify(m.error))); else p.resolve(m.result);
  } else if (m.method === 'Runtime.exceptionThrown') errors.push(m.params.exceptionDetails);
  else if (m.method === 'Runtime.consoleAPICalled') {
    const text = m.params.args.map(a => a.value ?? a.description).join(' ');
    messages.push(text);
    if (m.params.type === 'error') errors.push(text);
  }
};
const send = (method, params = {}) => new Promise((resolve, reject) => {
  const n = ++id; pending.set(n, { resolve, reject });
  ws.send(JSON.stringify({ id: n, method, params }));
});
const ev = async expression => {
  const r = await send('Runtime.evaluate', { expression, returnByValue: true, awaitPromise: true });
  if (r.exceptionDetails) throw Error(JSON.stringify(r.exceptionDetails));
  return r.result.value;
};
const delay = ms => new Promise(resolve => setTimeout(resolve, ms));
const state = () => ev('JSON.parse(window.sovereignState)');
const command = async (action, options = {}) => {
  await ev(`window.sovereignCommand(${JSON.stringify(JSON.stringify({ action, ...options }))})`);
  await delay(300);
};
const click = async ([x, y]) => {
  for (const type of ['mouseMoved', 'mousePressed', 'mouseReleased']) {
    await send('Input.dispatchMouseEvent', { type, x, y, button: 'left', clickCount: 1 });
  }
  await delay(300);
};
const shot = async name => fs.writeFile(path.join(reports, `${name}.png`),
  Buffer.from((await send('Page.captureScreenshot', { format: 'png' })).data, 'base64'));
const load = async (query = '?test=1&seed=41972') => {
  await send('Network.enable');
  await send('Network.setCacheDisabled', { cacheDisabled: true });
  const start = performance.now();
  await send('Page.navigate', { url: new URL(query, origin).href });
  for (let i = 0; i < 300; i++) {
    if (await ev('typeof window.sovereignCommand === "function" && !!window.sovereignState')) { await delay(600); return performance.now() - start; }
    await delay(200);
  }
  throw Error(`Godot did not start: ${JSON.stringify({ errors, messages })}`);
};

export { reports, origin, cdp, page, ws, errors, messages, send, ev, delay, state, command, click, shot, load };
