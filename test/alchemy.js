'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const sandbox={console};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;
function setup(){G.reset(41972);G.units=[];return G.addBuilding('marketplace',G.LEVEL.start.x,G.LEVEL.start.y+5);}
let market=setup(),gold=G.gold;
assert.equal(G.researchPotion('unknown',market),false);assert.equal(G.researchPotion('__proto__',market),false);
assert.equal(G.researchPotion('healing',G.palace),false);
market.progress=.5;assert.equal(G.researchPotion('healing',market),false);market.progress=1;
assert.equal(G.researchPotion('strength',market),false,'advanced recipes require Healing');
assert.equal(G.gold,gold,'invalid research never spends gold');
G.gold=149;assert.equal(G.researchPotion('healing',market),false);G.gold=gold;
assert(G.researchPotion('healing',market));assert.equal(G.gold,gold-150);
assert.equal(G.researchPotion('healing',market),false,'no duplicate project');
G.paused=true;G.update(10);assert.equal(G.alchemy.project.remaining,25,'paused game freezes research');G.paused=false;
G.update(10);assert.equal(G.alchemy.project.remaining,15);assert(!G.alchemy.unlocked.healing);
market.dead=true;G.update(10);assert.equal(G.alchemy.project.remaining,15,'destroying the last market pauses research');
market=G.addBuilding('marketplace',G.LEVEL.start.x+5,G.LEVEL.start.y,false);G.update(5);assert.equal(G.alchemy.project.remaining,15,'unfinished markets cannot research');
market.progress=1;G.update(15);assert.equal(G.alchemy.project,null);assert(G.alchemy.unlocked.healing);
gold=G.gold;assert.equal(G.researchPotion('healing',market),false);assert.equal(G.gold,gold);
assert(G.researchPotion('strength',market));assert.equal(G.researchPotion('stoneskin',market),false,'one research project at a time');
G.updateAlchemy(40);assert(G.researchPotion('stoneskin',market));G.updateAlchemy(45);
console.log('✓ Research costs, prerequisites, one project, pause, marketplace destruction/rebuilding and permanent kingdom recipes.');

market=setup();const hero=G.addUnit('warrior',market.x+2,market.y,G.palace);hero.gold=100;hero.hp=150;
assert.equal(G.buyPotions(hero,market),0,'locked recipes cannot be bought');
for(const key of Object.keys(G.POTIONS))G.alchemy.unlocked[key]=true;
hero.x+=10;assert.equal(G.buyPotions(hero,market),0,'must visit the marketplace');hero.x-=10;
market.progress=.9;assert.equal(G.buyPotions(hero,market),0);market.progress=1;
gold=G.gold;assert.equal(G.buyPotions(hero,market),4);assert.equal(hero.gold,6);assert.equal(market.taxPool,94);
assert.equal(G.gold,gold,'shopping spends personal gold, not treasury');assert.equal(hero.hp,150,'buying potions grants no free healing');
assert.equal(G.buyPotions(hero,market),0,'inventory caps respected');assert.equal(hero.potions.healing,2);
hero.hp=90;G.updateSupplies(hero,.1);assert.equal(hero.hp,200);assert.equal(hero.potions.healing,1);assert.equal(hero.potions.strength,1,'no combat potion while idle');
G.updateSupplies(hero,1);assert.equal(hero.potions.healing,1,'no wasted healing above threshold');
const enemy=G.addUnit('skeleton',hero.x+.5,hero.y);hero.target=enemy;hero.state='Fighting';
G.updateSupplies(hero,.1);assert.equal(hero.potions.strength,0);assert.equal(hero.potions.stoneskin,0);
assert.equal(G.unitDamage(hero),31);assert.equal(G.unitArmor(hero),8);
const hp=hero.hp;G.damage(hero,18,enemy);assert.equal(hero.hp,hp-10,'Stoneskin reduces actual incoming damage');
hero.attackTimer=0;G.attack(hero,enemy,.1);assert.equal(enemy.hp,enemy.maxHp-25,'Strength increases actual melee damage, accounting for armor');
G.updateSupplies(hero,25);assert.equal(G.unitDamage(hero),23);assert.equal(G.unitArmor(hero),4,'buffs expire');
hero.dead=true;hero.potions.healing=1;hero.hp=1;assert.equal(G.buyPotions(hero,market),0);G.updateSupplies(hero,1);assert.equal(hero.hp,1,'dead heroes cannot heal');
const visitor=G.addUnit('ranger',market.x+2,market.y);visitor.gold=18;
enemy.dead=true;G.thinkUnit(visitor);assert.equal(visitor.potions.healing,1,'hero AI buys unlocked supplies on its own');assert.equal(visitor.gold,0);
const collector=G.addUnit('collector',market.x+2,market.y);G.thinkUnit(collector);assert.equal(collector.carried,112);collector.x=G.palace.x;collector.y=G.palace.y;G.thinkUnit(collector);assert.equal(G.gold,gold+112,'sales reach the treasury through a collector');
const first=G.addUnit('ranger',40,40),firstEnemy=G.addUnit('goblin',41,40);first.potions.strength=1;G.attack(first,firstEnemy,.1);assert.equal(G.projectiles.at(-1).damage,23,'potion buffs the first shot, even when AI just acquired its target');
console.log('✓ Autonomous purchases, limited inventories, gold conservation, healing, combat buffs, expiry and tax delivery.');

setup();const guild=G.addBuilding('thieves',G.LEVEL.start.x-4,G.LEVEL.start.y);gold=G.gold;const thief=G.recruit('thief',guild);
assert(thief&&thief.hero&&thief.name);assert.equal(thief.gold,24);assert.equal(G.gold,gold-110);
for(let i=0;i<3;i++)assert(G.recruit('thief',guild));gold=G.gold;
assert.equal(G.recruit('thief',guild),false);assert.equal(G.gold,gold);assert.equal(G.recruit('warrior',guild),false);
const guard=G.addUnit('guard',thief.x,thief.y),goblin=G.addUnit('goblin',thief.x+.5,thief.y);
goblin.target=thief;assert.equal(G.unitDamage(thief,goblin),15);
goblin.target=guard;assert.equal(G.unitDamage(thief,goblin),29);
G.attack(thief,goblin,.1);assert.equal(goblin.hp,109,'distracted strike applies to actual damage');
guard.dead=true;assert.equal(G.unitDamage(thief,goblin),15,'dead targets do not distract');
assert.equal(G.unitDamage(thief,G.buildings.find(b=>b.hostile)),15,'lairs do not receive distracted bonus');
console.log('✓ Thieves recruit with supply money, guild capacity and ally-dependent dagger bonus.');

// Compare identical combat against the previous balance: danger means both more hits
// required and more health lost, not just larger numbers in the inspector.
function duel(type,legacy){
  setup();const w=G.addUnit('warrior',22,23),m=G.addUnit(type,22.5,23);
  if(legacy){m.data={...m.data,...legacy};m.hp=m.maxHp=legacy.hp;}
  w.target=m;m.target=w;let seconds=0;
  while(!w.dead&&!m.dead&&seconds<60){w.attackTimer-=.05;m.attackTimer-=.05;G.attack(w,m,.05);if(!m.dead)G.attack(m,w,.05);seconds+=.05;}
  return {seconds,loss:w.maxHp-w.hp};
}
for(const [type,old] of Object.entries({rat:{hp:40,damage:5,armor:0},goblin:{hp:80,damage:10,armor:1},skeleton:{hp:90,damage:12,armor:2}})){
  const before=duel(type,old),after=duel(type);assert(after.seconds>before.seconds,type+' survives longer');assert(after.loss>before.loss,type+' inflicts more damage');
}
setup();const troll=G.addUnit('troll',40,40);troll.hp=1000;troll.lastHit=G.time;troll.think=100;
G.time=5;G.updateEntities(1);assert.equal(troll.hp,1000);G.time=7;G.updateEntities(1);assert.equal(troll.hp,1003);
troll.hp=troll.maxHp-1;G.updateEntities(1);assert.equal(troll.hp,troll.maxHp);
G.reset(41972);assert.equal(Object.keys(G.alchemy.unlocked).length,0);assert.equal(G.alchemy.project,null);assert.equal(G.stats.potionsBought,0);
console.log('✓ Stronger monsters prolong combat and hurt more; trolls regenerate after a respite; new kingdoms reset research.');
