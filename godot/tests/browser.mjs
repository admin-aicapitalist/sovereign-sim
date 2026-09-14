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
const load = async () => {
  const start = performance.now();
  await send('Page.navigate', { url: new URL('?test=1', origin).href });
  for (let i = 0; i < 300; i++) {
    if (await ev('typeof window.sovereignCommand === "function" && !!window.sovereignState')) return performance.now() - start;
    await delay(200);
  }
  throw Error(`Godot did not start: ${JSON.stringify({ errors, messages })}`);
};

try {
  await send('Runtime.enable'); await send('Page.enable');
  await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled', { enabled: true });
  await send('Emulation.setDeviceMetricsOverride', { width: 1440, height: 900, deviceScaleFactor: 1, mobile: false });
  const firstLoadMs = await load();
  await command('reset'); await command('pause');
  await shot('kingdom');
  let s = await state();
  assert.equal(s.buildings.filter(b => b.hostile).length, 1);
  const frozen = s.time;
  await delay(400); assert.equal((await state()).time, frozen, 'Pause freezes the clock');
  await click(s.widgets.pause_button); assert.equal((await state()).paused, false);
  await click((await state()).widgets.pause_button); assert.equal((await state()).paused, true);

  await command('mode', { type: 'warriors' });
  s = await state();
  await command('camera', { x: s.build_tile[0], y: s.build_tile[1] });
  const money = (await state()).gold;
  await click((await state()).build_site);
  s = await state();
  const guild = s.buildings.find(b => b.type === 'warriors');
  assert(guild, 'Mouse placement creates a guild');
  assert.equal(s.gold, money - 350);
  await command('step', { seconds: 60 });
  assert.equal((await state()).buildings.find(b => b.id === guild.id).progress, 1);
  await command('select', { id: guild.id });
  for (let i = 0; i < 4; i++) await click((await state()).widgets.action);
  s = await state(); assert.equal(s.units.filter(u => u.hero).length, 4);
  await click(s.widgets.action); assert.equal((await state()).units.filter(u => u.hero).length, 4);
  const lair = s.buildings.find(b => b.hostile);
  await command('select', { id: lair.id });
  await click((await state()).widgets.action);
  assert.deepEqual((await state()).flags, [[lair.id, 100]]);
  await command('step', { seconds: 20 });
  await command('save');
  const saved = await ev('JSON.parse(localStorage.getItem("sovereign-godot-save-v1"))');
  assert.equal(saved.units.filter(u => u.hero).length, 4);
  await load(); await command('load');
  s = await state();
  assert.equal(s.paused, true); assert.equal(s.gold, saved.gold);
  assert(Math.abs(s.time - saved.time) < 0.001);
  assert.equal(s.rng, saved.rng); assert.deepEqual(s.flags, saved.flags);
  await ev('localStorage.setItem("sovereign-godot-save-v1", "{broken")');
  await command('load');
  assert.match((await state()).message, /No compatible/);
  assert.equal((await state()).time, s.time, 'Bad save leaves current kingdom intact');
  await command('save');
  await command('step', { seconds: 600 });
  s = await state(); assert.equal(s.result, 'victory'); assert.equal(s.flags.length, 0);
  assert(s.stats.hits > 0 && s.stats.kills > 0 && s.stats.taxes > 0);
  await command('camera', { x: lair.x, y: lair.y }); await shot('victory');
  console.log('PASS: browser placement, construction, recruitment/capacity, bounty, pause, reload persistence and autonomous victory');

  // Verify the shipped URL does not expose the automation command bridge.
  await send('Page.navigate', { url: origin });
  await delay(3500);
  assert.equal(await ev('typeof window.sovereignCommand'), 'undefined');
  assert.equal(await ev('document.querySelector("#status") === null'), true, 'Normal player URL starts');
  await load();

  const metadata = await ev(`(() => {
    const c = document.createElement('canvas'), gl = c.getContext('webgl2');
    const ext = gl?.getExtension('WEBGL_debug_renderer_info');
    return { userAgent: navigator.userAgent, hardwareConcurrency: navigator.hardwareConcurrency,
      renderer: ext ? gl.getParameter(ext.UNMASKED_RENDERER_WEBGL) : gl?.getParameter(gl.RENDERER),
      viewport: [innerWidth, innerHeight], devicePixelRatio, crossOriginIsolated };
  })()`);
  const benchmarks = [];
  for (const count of [100, 300, 1000]) {
    const start = performance.now();
    await command('benchmark', { count, seconds: Number(process.env.GODOT_BENCH_SECONDS || 15) });
    let result;
    for (let i = 0; i < 600; i++) {
      result = await ev('window.sovereignBenchmark ? JSON.parse(window.sovereignBenchmark) : null');
      if (result) break;
      await delay(200);
    }
    assert(result, `Benchmark ${count} timed out`);
    assert(result.stats.hits > 0 && result.stats.moves > 0 && result.stats.paths > 0);
    result.wall_seconds_including_warmup = (performance.now() - start) / 1000;
    benchmarks.push(result); console.log(JSON.stringify(result));
    if (count === 1000) await shot('crowd-1000');
  }
  assert.deepEqual(errors, [], 'No browser or engine errors');
  const report = { recorded_at: new Date().toISOString(), metadata, first_load_local_ms: firstLoadMs,
    load_note: 'Local uncompressed HTTP on this machine; not an internet download estimate.',
    checks: 'PASS: placement, construction, recruitment/capacity, bounty, pause, reload persistence, autonomous victory',
    benchmarks, errors };
  await fs.writeFile(path.join(reports, 'browser.json'), JSON.stringify(report, null, 2) + '\n');
  await command('reset');
} catch (error) {
  await shot('failure').catch(() => {});
  console.error(JSON.stringify({ errors, messages: messages.slice(-30) }, null, 2));
  throw error;
} finally {
  ws.close();
  await fetch(`${cdp}/json/close/${page.id}`);
}
