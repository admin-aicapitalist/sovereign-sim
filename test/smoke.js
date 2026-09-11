'use strict';
const fs=require('node:fs'),vm=require('node:vm'),path=require('node:path'),assert=require('node:assert/strict');
const root=path.join(__dirname,'..');
let draws=0;
const context=new Proxy({createLinearGradient:()=>({addColorStop(){}}),createRadialGradient:()=>({addColorStop(){}}),drawImage(){draws++;}},{get(o,k){return k in o?o[k]:()=>{};},set(o,k,v){o[k]=v;return true;}});
const sandbox={console,Math,Map,Set,Number,Array,Object,String,Infinity,document:{createElement:()=>({width:0,height:0,getContext:()=>context})}};sandbox.window=sandbox;vm.createContext(sandbox);
for(const file of ['util','data','sprites','mapgen','world','entities','alchemy','loot','ai','sanitation','game'])vm.runInContext(fs.readFileSync(path.join(root,'js',file+'.js'),'utf8'),sandbox,{filename:file+'.js'});
const G=sandbox.G;G.headless=true;const mapSeed=process.argv[2]??41972;
function run(seconds,action){for(let t=0;t<seconds&&!G.result;t+=.1){if(action&&Math.floor(t*10)%10===0)action();G.update(.1);}finite();}
function finite(){assert(Number.isFinite(G.gold)&&G.gold>=0,'treasury remains finite and non-negative');for(const e of [...G.units,...G.buildings])for(const key of ['x','y','hp'])assert(Number.isFinite(e[key]),`${e.type}.${key} is finite`);}
function place(type){const p=G.findBuildingSite(type);assert(p,type+' has a legal site');const b=G.build(type,p.x,p.y);assert(b,`${type} construction succeeds`);return b;}

G.makeSprites();for(const key of Object.keys(G.BUILDINGS))assert(G.sprites[key]);for(const key of Object.keys(G.UNITS)){assert.equal(G.sprites['unit_'+key].length,4);assert(G.sprites['attack_'+key]);}for(const sprite of Object.values(G.sprites))for(const s of Array.isArray(sprite)?sprite:[sprite])assert(s.canvas.width>0&&s.canvas.height>0);console.log('✓ Every procedural building, unit animation, and scenery sprite generates.');

G.reset(mapSeed);const startGold=G.gold;assert.equal(G.build('warriors',G.palace.tx,G.palace.ty),false);assert.equal(G.gold,startGold);assert.equal(G.recruit('wizard'),false);assert.equal(G.cast('lightning',20,20),false);for(const b of G.buildings.filter(b=>b.hostile))assert(G.findPath(G.LEVEL.rally.x,G.LEVEL.rally.y,b.x,b.y).length>0,'all lairs are reachable');run(180);assert(!G.palace.dead,'unattended kingdom survives the opening');assert(G.stats.taxes>0,'tax collection brings income');console.log('✓ Invalid actions preserve gold, all lairs are reachable, and an unattended kingdom survives 3 minutes.');

G.reset(mapSeed);const warriorGuild=place('warriors'),market=place('marketplace');run(45);assert.equal(warriorGuild.progress,1);assert.equal(market.progress,1);for(let i=0;i<4;i++)assert(G.recruit('warrior',warriorGuild));assert.equal(G.recruit('warrior',warriorGuild),false,'guild capacity is enforced');const rangerGuild=place('rangers');run(40);assert.equal(rangerGuild.progress,1);assert(G.recruit('ranger',rangerGuild));console.log('✓ Peasants complete construction; recruitment charges gold and enforces guild capacity.');

let wizardGuild=null,temple=null,tower=null;
assert(G.researchPotion('healing',market));
run(1800,()=>{
  if(!G.alchemy.project&&G.gold>500){const recipe=['strength','stoneskin'].find(key=>!G.alchemy.unlocked[key]);if(recipe)G.researchPotion(recipe,market);}
  const alive=G.buildings.filter(b=>b.hostile&&!b.dead);
  if(!G.flags.some(f=>!f.dead&&f.type==='attack')&&alive.length&&G.gold>=150){const target=alive.sort((a,b)=>G.dist(a,G.palace)-G.dist(b,G.palace))[0];G.placeFlag('attack',target.x,target.y,target,150);}
  if(!wizardGuild&&G.gold>720)wizardGuild=place('wizards');
  if(!temple&&wizardGuild&&G.gold>550)temple=place('temple');
  if(!tower&&G.time>400&&G.gold>350)tower=place('tower');
  for(const guild of [warriorGuild,rangerGuild,wizardGuild])if(guild&&guild.progress===1&&!guild.dead){const heroes=G.units.filter(u=>!u.dead&&u.hero&&u.home===guild);if(heroes.length<guild.data.capacity&&G.gold>G.UNITS[guild.data.recruits].cost+150)G.recruit(guild.data.recruits,guild);}
  if(G.spellAvailable('heal')&&G.cooldowns.heal===0&&G.gold>150){const wounded=G.units.find(u=>u.hero&&!u.dead&&u.hp<u.maxHp*.45);if(wounded)G.cast('heal',wounded.x,wounded.y);}
  if(G.spellAvailable('lightning')&&G.cooldowns.lightning===0&&G.gold>300){const f=G.flags.find(f=>!f.dead&&f.target&&!f.target.dead);if(f)G.cast('lightning',f.x,f.y);}
});
assert.equal(G.result,'victory',`scripted playthrough must win (time=${Math.floor(G.time)}, lairs=${G.stats.lairs}, heroes=${G.units.filter(u=>u.hero&&!u.dead).length}, palace=${Math.floor(G.palace.hp)}, gold=${Math.floor(G.gold)})`);assert.equal(G.stats.lairs,G.LEVEL.lairs.length);assert(G.stats.potionsBought>0&&G.stats.potionsUsed>0,'campaign heroes buy and drink researched potions');assert(G.stats.bounties>=1);assert(G.stats.taxes>100);console.log(`✓ A scripted kingdom wins in ${Math.floor(G.time)} seconds with ${G.stats.recruited} recruits and ${Math.floor(G.stats.taxes)} gold in taxes.`);

G.reset(mapSeed);const flag=G.placeFlag('explore',G.LEVEL.rally.x,G.LEVEL.rally.y,null,100);const paid=G.gold;assert(G.raiseFlag(flag));assert.equal(G.gold,paid-50);G.cancelFlag(flag);assert.equal(G.gold,1500);assert(G.cast('farsight',35,32));assert.equal(G.cast('farsight',35,32),false,'spell cooldown enforced');assert(G.isExplored(35,32));G.paused=true;const time=G.time;G.update(1);assert.equal(G.time,time);G.paused=false;G.damage(G.palace,99999,null);G.update(.1);assert.equal(G.result,'defeat');console.log('✓ Bounty refunds, spell cooldowns, fog reveal, pause, and Palace defeat work.');
console.log('\nAll smoke checks passed.');
