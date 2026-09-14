'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const sandbox={console};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;G.reset(41972);
assert.equal(G.MAP,88);assert.equal(G.tiles.length,88*88);
assert.equal(G.buildings.filter(b=>b.hostile).length,8);
const signature=()=>JSON.stringify([G.tiles.map(t=>[t.kind,t.blocked]),G.trees,G.decor]);
const original=signature();G.reset(41972);assert.equal(signature(),original,'map generation is reproducible');
assert(G.LEVEL.lairs.filter(l=>l.frontier).some(l=>!G.isExplored(l.x,l.y)),'distant frontier starts under fog');
const validate=route=>{for(let i=0;i<route.length;i++){const p=route[i];assert(G.walkable(p.x,p.y),'route stays on open ground');if(i){const a=route[i-1],dx=p.x-a.x,dy=p.y-a.y;assert(Math.abs(dx)<=1&&Math.abs(dy)<=1,'adjacent route steps');if(dx&&dy)assert(G.walkable(a.x+dx,a.y)&&G.walkable(a.x,a.y+dy),'no diagonal corner cutting');}}};
for(const b of G.buildings){if(!b.hostile)continue;
  for(let y=b.ty;y<b.ty+b.data.size;y++)for(let x=b.tx;x<b.tx+b.data.size;x++)assert(!['water','bridge'].includes(G.tile(x,y).kind),'lair has dry foundations');
  const route=G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,b.x,b.y);assert(route.length,'reachable lair: '+b.siteName);validate(route);
}
for(const [x,y]of [...G.LEVEL.clearings,...G.LEVEL.roads.map(r=>r[r.length-1])]){
  const occupied=G.buildings.some(b=>x>=b.tx&&x<b.tx+b.data.size&&y>=b.ty&&y<b.ty+b.data.size);assert(G.walkable(x,y)||occupied,'road destination is open or leads into a building');
  const route=G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,x,y);assert(route.length,`frontier destination ${x},${y} is reachable`);validate(route);
  if(!occupied){assert.equal(Math.floor(route.at(-1).x),x);assert.equal(Math.floor(route.at(-1).y),y);}
}
for(const bridge of G.LEVEL.bridges){const route=G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,bridge.x,bridge.y);assert(route.length,'generated bridge is reachable');validate(route);}
const [cx,cy]=G.LEVEL.clearings.at(-1);G.reveal(cx,cy,8);assert(G.canPlace('house',cx,cy),'newly explored settlement supports construction');
const worker=G.addUnit('peasant',G.LEVEL.rally.x,G.LEVEL.rally.y,G.palace);G.moveTo(worker,cx+.5,cy+.5);
for(let i=0;i<2000&&worker.path.length;i++)G.moveUnit(worker,.2);
assert(G.dist(worker,{x:cx+.5,y:cy+.5})<.01,'workers travel to distant settlements');
console.log('✓ Deterministic 88×88 world, all eight lairs and settlement clearings reachable, generated river crossings, distant construction and worker travel.');

G.reset(41972);const remote=G.buildings.find(b=>b.dormant);remote.spawnTimer=.01;const count=G.units.length;G.update(.1);
assert(remote.dormant&&G.units.length===count,'undiscovered lairs do not send extra waves');
G.reveal(remote.x,remote.y,4);G.update(.1);assert(!remote.dormant&&remote.spawnTimer>1,'exploration awakens a frontier lair with time before its next wave');
const lairs=G.buildings.filter(b=>b.hostile);for(const b of lairs.slice(0,4))G.kill(b,null);G.update(.1);assert.equal(G.result,null,'four remaining frontier lairs prevent an early victory');
for(const b of lairs.slice(4))G.kill(b,null);G.update(.1);assert.equal(G.result,'victory');assert.equal(G.stats.lairs,8);
console.log('✓ Frontier activation and all-eight-lair victory condition.');

// A long alternating-wall detour exceeds the old 2,600-node search limit.
for(const t of G.tiles){t.kind='grass';t.blocked=false;}
for(let x=5,n=0;x<G.MAP-3;x+=6,n++)for(let y=0;y<G.MAP;y++)if(n%2?y>2:y<G.MAP-3)G.tile(x,y).blocked=true;
const detour=G.findPath(2.5,2.5,G.MAP-3.5,G.MAP-3.5);assert(detour.length>500,'long detours across a large map are found');validate(detour);
assert.equal(G.findPath(2,2,-1,10).length,0);assert.equal(G.findPath(2,2,G.MAP,10).length,0);
console.log('✓ Long-distance pathfinding respects walls, corners and world boundaries.');
