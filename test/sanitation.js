'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const sandbox={console};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;
function houses(count){while(G.sanitationStatus().cottages<count){const p=G.findBuildingSite('house');assert(p,'town has a cottage plot');G.addBuilding('house',p.x,p.y);}}
G.reset(41972);houses(6);G.updateSanitation(180);assert.equal(G.sanitationStatus().active,0);assert.equal(G.sanitation.timer,0);
const p=G.findBuildingSite('house'),unfinished=G.addBuilding('house',p.x,p.y,false);G.updateSanitation(100);assert.equal(G.sanitationStatus().target,0,'unfinished cottages do not trigger overcrowding');
unfinished.progress=1;G.updateSanitation(59);assert.equal(G.sanitationStatus().target,1);assert.equal(G.sanitationStatus().active,0,'players get a grace period');
G.paused=true;G.update(5);assert.equal(G.sanitation.timer,59,'pause freezes infestation pressure');G.paused=false;G.updateSanitation(1);
let sewer=G.buildings.find(b=>b.infestation&&!b.dead);assert(sewer,'seventh cottage opens a sewer');assert.equal(G.units.filter(u=>u.infestation).length,2);assert.equal(G.buildings.filter(b=>b.hostile&&!b.infestation).length,8);
const hero=G.addUnit('warrior',sewer.x,sewer.y),gold=G.gold,experience=hero.xp;
G.kill(sewer,hero);for(const u of G.units.filter(u=>u.infestation))G.kill(u,hero);
assert.equal(G.gold,gold);assert.equal(hero.gold,0);assert.equal(hero.xp,experience);assert.equal(G.loot.length,0,'urban infestations cannot farm treasure');assert.equal(G.stats.lairs,0);assert.equal(G.stats.infestationsCleared,1);
G.updateSanitation(59);assert.equal(G.sanitationStatus().active,0);G.updateSanitation(1);assert.equal(G.sanitationStatus().active,1,'overcrowding creates another infestation after cleanup');
sewer=G.buildings.find(b=>b.infestation&&!b.dead);G.kill(sewer,null);const treasury=G.gold;assert.equal(G.demolishCottage(G.palace),false);unfinished.taxPool=100;assert(G.demolishCottage(unfinished));assert.equal(G.demolishCottage(unfinished),false);assert.equal(G.gold,treasury,'demolition never refunds gold or stored taxes');G.updateSanitation(300);assert.equal(G.sanitationStatus().active,0,'reducing cottages stops recurrence');
console.log('✓ Safe threshold, completed housing, grace period, pause, recurring infestations and no gold/XP farming.');

for(const seed of [0,1,4,41972,4294967295]){
  G.reset(seed);houses(10);assert.equal(G.sanitationStatus().target,1);houses(11);assert.equal(G.sanitationStatus().target,2);
  const foundations=G.buildings.map(b=>[b,b.tx,b.ty,b.hp]);G.updateSanitation(60);G.updateSanitation(60);
  const infested=G.buildings.filter(b=>b.infestation&&!b.dead);assert.equal(infested.length,2,'density supports two sewers on seed '+seed);
  for(const b of infested){
    for(let y=b.ty;y<b.ty+2;y++)for(let x=b.tx;x<b.tx+2;x++)assert.equal(G.tile(x,y).kind,'grass','sewers preserve roads and water');
    for(const [original,x,y,hp]of foundations){assert.equal(original.tx,x);assert.equal(original.ty,y);assert.equal(original.hp,hp);assert(Math.abs(b.x-original.x)>=(b.data.size+original.data.size)/2||Math.abs(b.y-original.y)>=(b.data.size+original.data.size)/2,'sewer never overwrites a building');}
    assert(G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,b.x,b.y).length,'heroes can reach new sewers');
  }
  G.updateSanitation(180);assert.equal(G.sanitationStatus().active,2,'active infestation count respects housing threshold');
}
G.reset(41972);houses(7);G.updateSanitation(60);sewer=G.buildings.find(b=>b.infestation);
for(const u of G.units)u.dead=true;
// Keep the sim's other actors still while testing the real sewer spawning loop.
for(let i=0;i<6;i++)for(let t=0;t<18.1;t+=.1){for(const u of G.units){u.think=1e6;u.path=[];u.target=null;}G.update(.1);}
const rats=G.units.filter(u=>!u.dead&&u.home===sewer);assert.equal(rats.length,6);assert(rats.every(u=>u.infestation&&u.raider),'all later broods inherit the no-reward infestation flag');
for(const b of G.buildings.filter(b=>b.hostile&&!b.infestation))G.kill(b,null);G.update(.1);assert.equal(G.result,'victory');assert.equal(G.stats.lairs,8,'urban sewers never inflate campaign objectives');
G.reset(41972);assert.equal(G.sanitation.timer,0);assert.equal(G.stats.infestationsCleared,0);
console.log('✓ Scaling, safe placement across regions, reachable sewers, bounded rat broods and unchanged eight-lair victory.');

G.reset(41972);houses(7);for(const t of G.tiles)if(t.kind==='grass')t.kind='path';
G.updateSanitation(60);assert(G.units.some(u=>u.infestation),'occupying available sewer plots does not prevent rat outbreaks');
console.log('✓ Rat outbreaks still occur if there is no safe plot for a sewer.');
