'use strict';
window.G = window.G || {};
(function () {
  G.TW = 64; G.TH = 32;
  G.clamp = (v, a, b) => Math.max(a, Math.min(b, v));
  G.lerp = (a, b, t) => a + (b - a) * t;
  G.dist = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);
  G.iso = (x, y) => ({ x: (x - y) * G.TW / 2, y: (x + y) * G.TH / 2 });
  G.uniso = (x, y) => ({ x: x / G.TW + y / G.TH, y: y / G.TH - x / G.TW });
  G.rng = function (seed) { return function () { seed |= 0; seed = seed + 0x6D2B79F5 | 0; let t = Math.imul(seed ^ seed >>> 15, 1 | seed); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; };
  G.random = G.rng(41972);
  G.pick = a => a[Math.floor(G.random() * a.length)];
  G.escape = s => String(s).replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
  G.Heap = class {
    constructor() { this.items = []; }
    push(n) { const a = this.items; a.push(n); let i = a.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (a[p].f <= n.f) break; a[i] = a[p]; i = p; } a[i] = n; }
    pop() { const a = this.items, root = a[0], last = a.pop(); if (a.length) { let i = 0; while (true) { let c = i * 2 + 1; if (c >= a.length) break; if (c + 1 < a.length && a[c + 1].f < a[c].f) c++; if (a[c].f >= last.f) break; a[i] = a[c]; i = c; } a[i] = last; } return root; }
  };
  G.findPath = function (sx, sy, tx, ty) {
    sx = Math.floor(sx); sy = Math.floor(sy); tx = Math.floor(tx); ty = Math.floor(ty);
    if (!G.inBounds(tx, ty)) return [];
    if (!G.walkable(tx, ty)) { let best = null; for (let r = 1; r <= 4 && !best; r++) for (let y = ty - r; y <= ty + r; y++) for (let x = tx - r; x <= tx + r; x++) if (G.walkable(x, y) && (!best || Math.hypot(x - sx, y - sy) < best.d)) best = { x, y, d: Math.hypot(x - sx, y - sy) }; if (!best) return []; tx = best.x; ty = best.y; }
    const open = new G.Heap(), seen = new Map(), key = (x,y) => y * G.MAP + x;
    const first = { x:sx, y:sy, g:0, f:0, parent:null }; open.push(first); seen.set(key(sx,sy),first);
    let visits = 0;
    while (open.items.length && visits++ < 2600) {
      const n = open.pop(); if (n.closed) continue; n.closed = true;
      if (n.x === tx && n.y === ty) { const path = []; let p = n; while (p.parent) { path.unshift({ x:p.x+.5, y:p.y+.5 }); p = p.parent; } return path; }
      for (let dy=-1;dy<=1;dy++) for(let dx=-1;dx<=1;dx++) {
        if (!dx && !dy) continue; const x=n.x+dx,y=n.y+dy;
        if (!G.walkable(x,y) || (dx && dy && (!G.walkable(n.x+dx,n.y) || !G.walkable(n.x,n.y+dy)))) continue;
        const g = n.g + (dx && dy ? 1.414 : 1), k=key(x,y), old=seen.get(k);
        if (old && old.g <= g) continue;
        const next = { x,y,g,f:g+Math.hypot(tx-x,ty-y),parent:n }; seen.set(k,next); open.push(next);
      }
    }
    return [];
  };
})();
