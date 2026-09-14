'use strict';
const fs=require('node:fs'),path=require('node:path'),vm=require('node:vm'),assert=require('node:assert/strict');
const sandbox={console};sandbox.window=sandbox;vm.createContext(sandbox);
for(const name of ['util','data','mapgen','world','entities','alchemy','magic','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(__dirname,'../js',name+'.js'),'utf8'),sandbox,{filename:name+'.js'});
const G=sandbox.G;G.headless=true;
function setup(){G.reset(41972);G.modalOpen=false;G.units=[];G.gold=3000;for(const t of G.tiles)if(t.x>=30&&t.x<=55&&t.y>=30&&t.y<=55){t.blocked=false;t.kind='grass';t.explored=t.visible=true;}return G.addBuilding('temple',32,32);}
function learn(...keys){for(const k of keys)G.magic.unlocked[k]=true;}
function wizard(){return G.addUnit('wizard',40.5,40.5);}
function monster(type='skeleton',x=44.5,y=40.5){return G.addUnit(type,x,y);}
let temple=setup(),gold=G.gold;
assert(G.spellAvailable('farsight'));assert(!G.spellAvailable('heal'));assert(!G.spellAvailable('lightning'));
for(const key of ['unknown','__proto__','constructor','farsight','meteor'])assert.equal(G.researchSpell(key,temple),false);
assert.equal(G.researchSpell('heal',G.palace),false);temple.progress=.5;assert.equal(G.researchSpell('heal',temple),false);temple.progress=1;
assert.equal(G.gold,gold);G.gold=124;assert.equal(G.researchSpell('heal',temple),false);G.gold=gold;
assert(G.researchSpell('heal',temple));assert.equal(G.gold,gold-125);assert.equal(G.researchSpell('lightning',temple),false);
G.paused=true;G.update(10);assert.equal(G.magic.project.remaining,20);G.paused=false;
G.updateMagic(7);assert.equal(G.magic.project.remaining,13);temple.dead=true;G.updateMagic(100);assert.equal(G.magic.project.remaining,13);
temple=G.addBuilding('temple',35,32,false);G.updateMagic(100);assert.equal(G.magic.project.remaining,13);temple.progress=1;G.updateMagic(13);
assert(G.spellAvailable('heal'));assert.equal(G.magic.project,null);gold=G.gold;assert(!G.researchSpell('heal',temple));assert.equal(G.gold,gold);
for(const key of ['lightning','frost','ward','haste','meteor']){assert(G.researchSpell(key,temple));G.updateMagic(G.SPELLS[key].time);assert(G.spellAvailable(key));}
temple.dead=true;assert(G.spellAvailable('meteor'),'knowledge survives the Temple');assert.equal(wizard().mana,100);
console.log('✓ Temple eligibility, research payments/prerequisites, one study, pause/rebuild and permanent shared knowledge.');

setup();learn('heal','lightning','ward','haste','frost','meteor');gold=G.gold;
for(const key of ['unknown','__proto__','constructor'])assert.equal(G.cast(key,40,40),false);
for(const [x,y]of [[NaN,40],[40,Infinity],[-1,40],[G.MAP,40]])assert.equal(G.cast('lightning',x,y),false);
const ground={x:40,y:40},roof={kind:'building',hostile:true,x:45,y:45};assert.equal(G.spellPoint('meteor',ground,roof),roof);assert.equal(G.spellPoint('heal',ground,roof),ground);assert.equal(G.spellPoint('farsight',ground,roof),ground);assert.equal(G.spellPoint('meteor',ground,{kind:'flag',target:roof}),roof);
assert.equal(G.cast('heal',40,40),false);assert.equal(G.cast('lightning',40,40),false);assert.equal(G.cast('ward',40,40),false);assert.equal(G.gold,gold);
let hero=G.addUnit('warrior',40.5,40.5),enemy=monster('troll',41.5),far=monster('troll',47.5);
G.tile(40.5,40.5).visible=false;assert.equal(G.cast('lightning',40.5,40.5),false);G.tile(40.5,40.5).visible=true;
G.gold=89;assert.equal(G.cast('lightning',40.5,40.5),false);G.gold=gold;
assert(G.cast('lightning',41.5,40.5));assert.equal(G.gold,gold-90);assert.equal(enemy.hp,enemy.maxHp-181);assert.equal(far.hp,far.maxHp);assert.equal(hero.hp,hero.maxHp);assert(!G.cast('lightning',41.5,40.5));
hero.hp=50;assert(G.cast('heal',40.5,40.5));assert.equal(hero.hp,180);assert.equal(enemy.hp,enemy.maxHp-181);
assert(G.cast('ward',40.5,40.5));hero.buffs.stoneskin=25;assert.equal(G.unitArmor(hero),16);const hp=hero.hp;G.damage(hero,48,enemy);assert.equal(hero.hp,hp-32);
assert(G.cast('haste',40.5,40.5));hero.path=[{x:42.5,y:40.5}];G.moveUnit(hero,1);assert.equal(hero.x,42.5,'haste reaches a destination ordinary walking could not');
hero.attackTimer=0;G.attack(hero,enemy,.1);assert(Math.abs(hero.attackTimer-hero.data.rate/1.3)<1e-9);
assert(G.cast('frost',enemy.x,enemy.y));assert.equal(enemy.magicBuffs.frost,6);assert.equal(far.magicBuffs.frost,0);assert.equal(G.magicMoveMultiplier(enemy),.45);assert.equal(G.magicAttackMultiplier(enemy),.65);
G.updateUnitMagic(hero,16);assert.equal(G.unitArmor(hero),8);assert.equal(G.magicMoveMultiplier(hero),1);G.updateUnitMagic(enemy,6);assert.equal(G.magicMoveMultiplier(enemy),1);
G.result='victory';gold=G.gold;assert(!G.cast('farsight',40,40));assert.equal(G.gold,gold);
console.log('✓ Royal targeting, fog, treasury/cooldowns, friendly safety, real healing/armor/movement/attack effects and expiry.');

setup();learn('meteor');let w=wizard();enemy=monster();let second=monster('goblin',44.7,41.2);hero=G.addUnit('warrior',44.5,40.7);gold=G.gold;
assert(G.castWizardSpell(w,'meteor',enemy.x,enemy.y));assert.equal(w.mana,40);assert.equal(G.gold,gold);assert.equal(enemy.hp,enemy.maxHp);
G.time=.64;G.updateMagic(.64);assert(!enemy.dead);G.paused=true;G.update(10);assert(!enemy.dead);G.paused=false;
G.time=.65;G.updateMagic(.01);assert(enemy.dead&&second.dead);assert.equal(hero.hp,hero.maxHp);assert(w.xp>0);assert(G.loot.length>0);assert.equal(w.gold,0);assert.equal(G.magic.impacts.length,0);
const slain=G.stats.slain;G.updateMagic(1);assert.equal(G.stats.slain,slain);
setup();learn('meteor');w=wizard();enemy=monster();assert(G.castWizardSpell(w,'meteor',enemy.x,enemy.y));enemy.x+=10;w.dead=true;G.time=1;G.updateMagic(1);assert.equal(enemy.hp,enemy.maxHp,'moving out before impact avoids Meteor');
console.log('✓ Delayed Meteor impact, pause, movement avoidance, no friendly fire and wizard kill/loot attribution.');

setup();learn('heal','lightning');w=wizard();hero=G.addUnit('warrior',41.5,40.5);hero.hp=40;enemy=monster('troll');gold=G.gold;
G.thinkWizard(w);assert.equal(w.lastSpell.key,'heal');assert.equal(hero.hp,170);assert.equal(w.mana,75);assert.equal(G.gold,gold);
G.thinkWizard(w);assert.equal(G.stats.wizardSpells,1,'global cast interval');G.updateUnitMagic(w,3);G.thinkWizard(w);assert.equal(w.lastSpell.key,'lightning');assert(enemy.hp<enemy.maxHp);
assert.equal(G.cooldowns.heal,0);assert.equal(G.cooldowns.lightning,0,'wizard spells never trigger royal cooldowns');
assert(G.cast('lightning',enemy.x,enemy.y),'the crown can cast while the wizard recharges');
const novice=wizard();assert(G.castWizardSpell(novice,'lightning',enemy.x,enemy.y),'new wizards inherit learned magic and separate cooldowns');
let mana=novice.mana;assert(!G.castWizardSpell(novice,'lightning',enemy.x,enemy.y));assert.equal(novice.mana,mana);
novice.castTimer=0;novice.spellCooldowns.lightning=0;novice.mana=29;assert(!G.castWizardSpell(novice,'lightning',enemy.x,enemy.y));novice.mana=100;
assert(!G.castWizardSpell(novice,'lightning',55,55));assert(!G.castWizardSpell(hero,'lightning',enemy.x,enemy.y));novice.dead=true;assert(!G.castWizardSpell(novice,'lightning',enemy.x,enemy.y));novice.dead=false;
G.paused=true;assert(!G.castWizardSpell(novice,'lightning',enemy.x,enemy.y));G.paused=false;
novice.mana=0;novice.target=enemy;G.updateUnitMagic(novice,5);assert.equal(novice.mana,10);novice.target=null;G.updateUnitMagic(novice,5);assert.equal(novice.mana,30);G.updateUnitMagic(novice,100);assert.equal(novice.mana,100);
console.log('✓ Autonomous triage, individual wizard mana/cooldowns, new recruits, local range, regeneration and caster eligibility.');

for(const key of ['frost','ward','haste','meteor','farsight']){
  setup();learn(key);w=wizard();hero=G.addUnit('warrior',41.5,40.5);
  if(key==='frost'){monster('troll');monster('troll',45,41);}
  if(key==='ward'){enemy=monster('troll',42.5);enemy.target=hero;}
  if(key==='haste'){enemy=monster('troll',42.5);hero.target=enemy;}
  if(key==='meteor'){for(let i=0;i<3;i++)monster('troll',44.5+i*.3,40.5);}
  if(key==='farsight')G.tile(45,40).explored=false;
  G.thinkWizard(w);assert.equal(w.lastSpell?.key,key,'AI uses '+key+' in a useful situation');
}
setup();learn('lightning');w=wizard();enemy=monster('goblin',43,40.5);enemy.infestation=true;G.thinkWizard(w);assert(enemy.dead);assert.equal(w.xp,0);assert.equal(G.loot.length,0);
setup();w=wizard();enemy=monster('troll');w.mana=0;G.attack(w,enemy,.1);assert.equal(G.projectiles.at(-1).type,'fireball','ordinary fireballs still work with no research or mana');
setup();learn('heal');w=wizard();hero=G.addUnit('warrior',41.5,40.5);hero.hp=40;G.updateEntities(.1);assert.equal(w.lastSpell.key,'heal','regular simulation runs spell decisions');
const stream=G.rng(G.seed);G.random=stream;const first=stream();G.random=G.rng(G.seed);G.headless=false;G.spellEffect('heal',40,40,w);assert.equal(G.random(),first,'visuals cannot consume simulation randomness');G.headless=true;
G.magic.impacts.push({at:100});G.reset(41972);assert.equal(Object.keys(G.magic.unlocked).length,0);assert.equal(G.magic.impacts.length,0);assert.equal(G.magic.project,null);assert.equal(G.stats.wizardSpells,0);assert(Object.values(G.cooldowns).every(n=>n===0));
console.log('✓ Every AI spell, no infestation farming, ordinary fireballs, simulation integration, independent visual RNG and clean reset.');
