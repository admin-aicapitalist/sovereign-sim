'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict'),crypto=require('node:crypto');
let entropy=100;
const sandbox={console,crypto:{getRandomValues(array){array[0]=entropy++;return array;}}};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;
const signature=()=>crypto.createHash('sha256').update(JSON.stringify([G.LEVEL,G.tiles.map(t=>[t.kind,t.blocked,t.noise]),G.trees,G.decor])).digest('hex');
const waterSignature=()=>G.tiles.filter(t=>t.kind==='water'||t.kind==='bridge').map(t=>t.y*G.MAP+t.x).join(',');
G.reset();const firstSeed=G.seed,first=signature(),water=waterSignature();G.reset();
assert.notEqual(G.seed,firstSeed,'new games draw a fresh seed');assert.notEqual(signature(),first,'new seeds change the landscape');assert.notEqual(waterSignature(),water,'waterways vary too');
G.reset(firstSeed);assert.equal(signature(),first,'the displayed seed reproduces the map');
for(let i=0;i<100;i++)G.random();G.reset(String(firstSeed));assert.equal(signature(),first,'simulation RNG and numeric URL strings do not alter reproduction');
G.reset(0);const zero=signature();assert.equal(G.seed,0);G.reset('0');assert.equal(signature(),zero,'zero is a valid seed');
G.reset('Alderwick');const namedSeed=G.seed,named=signature();G.reset(namedSeed);assert.equal(signature(),named,'named seeds can be replayed using their displayed number');
G.seedOverride=namedSeed;G.reset();assert.equal(signature(),named,'pinned URL seeds also apply to the next kingdom');
G.seedOverride=null;G.reset();assert.notEqual(G.seed,namedSeed,'unpinned kingdoms randomize');
assert.equal(G.normalizeSeed(''),null);assert.equal(G.normalizeSeed('  '),null);assert.equal(G.normalizeSeed('4294967295'),4294967295);
assert.equal(G.normalizeSeed(' 42 '),42);assert(Number.isInteger(G.normalizeSeed('<script>')));
entropy=G.seed;assert.notEqual(G.newSeed(),G.seed,'even repeated entropy changes the next kingdom');
console.log('✓ Fresh defaults, deterministic replay, independent RNG streams, zero/named seeds and pinned/unpinned new games.');

function reachableTiles(){
  const seen=new Set(),queue=[Math.floor(G.LEVEL.rally.y)*G.MAP+Math.floor(G.LEVEL.rally.x)];seen.add(queue[0]);
  for(let i=0;i<queue.length;i++){
    const key=queue[i],x=key%G.MAP,y=Math.floor(key/G.MAP);
    for(const [xx,yy]of[[x+1,y],[x-1,y],[x,y+1],[x,y-1]]){
      const next=yy*G.MAP+xx;if(G.walkable(xx,yy)&&!seen.has(next)){seen.add(next);queue.push(next);}
    }
  }
  return seen;
}
const starts=new Set(),regions=new Set(),roads=new Set(),lairLayouts=new Set();
const seeds=[0,1,41972,4294967295,...Array.from({length:96},(_,i)=>Math.imul(i+1,2654435761)>>>0)];
for(const seed of seeds){
  G.reset(seed);starts.add(JSON.stringify(G.LEVEL.start));regions.add(G.LEVEL.name);roads.add(JSON.stringify(G.LEVEL.roads));lairLayouts.add(JSON.stringify(G.LEVEL.lairs));const reachable=reachableTiles(),at=(x,y)=>reachable.has(Math.floor(y)*G.MAP+Math.floor(x));
  for(const building of G.buildings){
    for(let y=building.ty;y<building.ty+building.data.size;y++)for(let x=building.tx;x<building.tx+building.data.size;x++)assert(!['water','bridge'].includes(G.tile(x,y).kind),`seed ${seed}: dry ${building.type} foundation`);
    if(building.hostile)assert(G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,building.x,building.y).length,`seed ${seed}: reachable ${building.siteName}`);
  }
  for(const [x,y]of G.LEVEL.clearings)assert(at(x,y),`seed ${seed}: reachable clearing/road ${x},${y}`);
  for(const bridge of G.LEVEL.bridges)assert(at(bridge.x,bridge.y),`seed ${seed}: accessible bridge`);
  const trollSpawn=G.nearPoint(G.LEVEL.trollEntry.x,G.LEVEL.trollEntry.y,3);assert(at(trollSpawn.x,trollSpawn.y),`seed ${seed}: accessible troll arrival`);
  for(const u of G.units)assert(at(u.x,u.y),`seed ${seed}: reachable starting ${u.type} at ${u.x},${u.y}`);
  for(const type of ['warriors','marketplace','rangers','wizards','temple'])assert(G.findBuildingSite(type),`seed ${seed}: room to build ${type}`);
  assert.equal(G.LEVEL.clearings.length,4);assert.equal(G.LEVEL.lairs.length,8);
  for(let i=0;i<G.LEVEL.lairs.length;i++)for(let j=0;j<i;j++)assert(G.dist(G.LEVEL.lairs[i],G.LEVEL.lairs[j])>7,'lairs do not overlap');

}
assert(starts.size>70,'palace location varies substantially');assert.equal(regions.size,3,'all three geographic regions occur');assert.equal(roads.size,100);assert.equal(lairLayouts.size,100);
console.log('✓ 100 structurally different maps: varied kingdoms, lairs, roads and landforms; dry foundations and connected routes.');
console.log('✓ 100 seeds keep foundations dry, every lair and settlement reachable, generated bridge crossings, accessible units and space to build.');
