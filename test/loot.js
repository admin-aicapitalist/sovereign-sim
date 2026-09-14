'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const sandbox={console};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;
function setup(seed=41972){G.reset(seed);G.units=[];G.buildings=G.buildings.filter(b=>!b.hostile);for(const t of G.tiles)if(t.x>=30&&t.x<=50&&t.y>=30&&t.y<=50){t.blocked=false;t.kind='grass';t.explored=t.visible=true;}}
function drop(type,x=40.5,y=40.5,killer=null){const e=G.addUnit(type,x,y);G.kill(e,killer);return G.loot.at(-1);}
function signature(seed){setup(seed);return ['rat','goblin','skeleton','troll'].map((type,i)=>{const p=drop(type,35.5+i*3,35.5);return JSON.stringify([p.gold,p.potions]);}).join('|');}
assert.equal(signature(12),signature(12));assert.notEqual(signature(12),signature(13));
setup(12);G.addUnit('goblin',40.5,40.5);const random=G.random();setup(12);drop('goblin');assert.equal(G.random(),random,'loot rolls use a separate RNG stream');
for(let seed=0;seed<32;seed++){
  setup(seed);
  for(const type of ['rat','goblin','skeleton','troll']){const p=drop(type,35.5+['rat','goblin','skeleton','troll'].indexOf(type)*3,35.5),t=G.LOOT.monsters[type];assert(p.gold>=t.gold[0]&&p.gold<=t.gold[1]);if(type==='troll')assert.equal(p.potions.healing,2);}
}
console.log('✓ Seeded drop ranges, guaranteed troll supplies and independent loot RNG.');

setup();const hero=G.addUnit('warrior',38.5,40.5),enemy=G.addUnit('goblin',40.5,40.5),royalGold=G.gold;
G.kill(enemy,hero);const pile=G.loot[0],amount=pile.gold;
assert.equal(hero.gold,0,'no invisible last-hit payout');assert(hero.xp>0,'combat experience remains');assert.equal(G.gold,royalGold);
G.kill(enemy,hero);assert.equal(G.loot.length,1,'repeated death never duplicates loot');
assert.equal(G.collectLoot(hero,pile),false,'must reach the drop');hero.x=pile.x;hero.y=pile.y;
assert.equal(G.collectLoot(G.addUnit('guard',pile.x,pile.y),pile),false,'staff cannot take hero treasure');
assert(G.collectLoot(hero,pile));assert.equal(hero.gold,amount);assert.equal(G.stats.lootGold,amount);assert.equal(G.collectLoot(hero,pile),false);
setup();const guarded=drop('rat',40.5,40.5,G.addUnit('guard',39.5,40.5));assert(guarded.gold>0,'guard kills leave recoverable gold');
const firstAmount=guarded.gold;drop('rat');assert.equal(G.loot.length,1,'repeated kills on the same tile merge pouches');assert(guarded.gold>firstAmount);
setup();const spellTarget=G.addUnit('skeleton',40.5,40.5);G.damage(spellTarget,9999,null);assert(G.loot[0].gold>0,'sovereign spell kills leave loot');
console.log('✓ Physical pickup, hero-only ownership, no duplicate rewards, guard/spell drops and pouch merging.');

setup();G.lootRandom=()=>0;const lair=G.addBuilding('graveyard',40,40),before=G.gold;G.kill(lair,null);const chest=G.loot[0];
assert(chest.chest&&G.walkable(chest.x,chest.y),'destroyed foundations release an accessible chest');assert.equal(G.gold,before+lair.data.reward,'royal clearance reward remains separate');
assert.equal(chest.potions.healing,1);assert.equal(chest.potions.stoneskin,1);assert.equal(G.stats.lairs,1);
const full=G.addUnit('ranger',chest.x,chest.y);for(const [key,p]of Object.entries(G.POTIONS))full.potions[key]=p.capacity;
assert(G.collectLoot(full,chest));assert.equal(chest.dead,false,'full inventory leaves potions on the ground');assert.equal(chest.gold,0);
assert.equal(G.collectLoot(full,chest),false,'cannot take supplies beyond capacity');
const next=G.addUnit('thief',chest.x,chest.y);assert(G.collectLoot(next,chest));assert(chest.dead);assert.equal(next.potions.stoneskin,1);assert.equal(next.gold,0);
assert.equal(Object.keys(G.alchemy.unlocked).length,0,'found potions do not unlock shop recipes');next.hp=1;G.updateSupplies(next,.1);assert(next.hp>1,'found supplies work before research');
assert.equal(G.stats.lootCaches,1);assert.equal(G.stats.lootPotions,2);
console.log('✓ Lair chests, separate crown reward, shared overflow supplies and usable finds without free research.');

setup();let loot=drop('rat',44.5,40.5),looter=G.addUnit('warrior',40.5,40.5);
G.thinkUnit(looter);assert.equal(looter.lootTarget,loot);assert(looter.path.length);
for(let i=0;i<50&&!loot.dead;i++){G.moveUnit(looter,.1);G.thinkUnit(looter);}assert(loot.dead&&looter.gold>0,'hero walks to and collects treasure autonomously');
setup();loot=drop('rat',44.5,40.5);looter=G.addUnit('warrior',40.5,40.5);G.tile(loot.x,loot.y).visible=false;assert.equal(G.seekLoot(looter),false,'hidden drops are not revealed by AI');
G.tile(loot.x,loot.y).visible=true;assert(G.seekLoot(looter));const threat=G.addUnit('goblin',46.5,40.5);assert.equal(G.seekLoot(looter),false);assert.equal(looter.path.length,0,'abandons a treasure route that becomes unsafe');threat.dead=true;
looter.hp=10;G.thinkUnit(looter);assert(['Resting','Fleeing'].includes(looter.state),'survival comes before loot');
setup();loot=drop('rat',44.5,40.5);looter=G.addUnit('warrior',40.5,40.5);
for(let y=39;y<=41;y++)for(let x=43;x<=45;x++)if(x!==44||y!==40)G.tile(x,y).blocked=true;
assert.equal(G.seekLoot(looter),false,'cannot target an unreachable cache');
setup();loot=drop('rat');assert.equal(G.canPlace('house',40,40),false,'construction cannot bury unclaimed treasure');looter=G.addUnit('warrior',loot.x,loot.y);G.collectLoot(looter,loot);assert(G.canPlace('house',40,40));
drop('rat',44.5,40.5);const count=G.loot.length;G.paused=true;G.update(100);assert.equal(G.loot.length,count);G.reset(41972);assert.equal(G.loot.length,0);assert.equal(G.stats.lootGold,0);
console.log('✓ Safe autonomous recovery, fog and pathfinding, survival priority, construction protection and clean new kingdoms.');
