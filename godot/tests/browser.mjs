import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import { reports, origin, cdp, page, ws, errors, messages, send, ev, delay, state, command, click, shot, loadStandalone as load } from './cdp.mjs';
const checks=[];
const pass=name=>{checks.push(name);console.log('PASS:',name);};
const key=async name=>{const s=await state(); assert(s.widgets[name],`Missing control ${name}`); assert(!s.widgets[name].disabled,`Disabled control ${name}`); await click(s.widgets[name].point);};
const scrollTo=async (name,area='modal')=>{
 for(let i=0;i<18;i++) {
  const s=await state(),w=s.widgets[name];assert(w,`Missing ${name}`);
  const r=area==='modal'?s.modal_rect:area==='deck'?[10,s.viewport[1]-207,s.viewport[0]-20,197]:[s.viewport[0]<900?12:s.viewport[0]-288,170,s.viewport[0]<900?345:276,s.viewport[1]-410];
  const [x,y]=w.point;
  if(x>r[0]+20&&x<r[0]+r[2]-20&&y>r[1]+35&&y<r[1]+r[3]-30)return;
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:r[0]+r[2]/2,y:r[1]+r[3]/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:r[0]+r[2]/2,y:r[1]+r[3]/2,deltaX:0,deltaY:area==='deck'?(x>r[0]+r[2]-20?260:-260):y>r[1]+r[3]-30?260:-260});await delay(350);
 }
 throw Error(`Could not scroll to ${name}`);
};
const entityPoint=async id=>(await state()).entities_on_screen.find(e=>e.id===id).point;
const resize=async(width,height,dpr=1,mobile=false)=>{await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile});await delay(600);};
const escape=async()=>{await send('Input.dispatchKeyEvent',{type:'keyDown',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await send('Input.dispatchKeyEvent',{type:'keyUp',key:'Escape',code:'Escape',windowsVirtualKeyCode:27});await delay(300);};
const touch=async points=>{await send('Input.dispatchTouchEvent',{type:'touchStart',touchPoints:[{x:points[0][0],y:points[0][1],id:1}]});for(const [x,y] of points.slice(1)){await delay(50);await send('Input.dispatchTouchEvent',{type:'touchMove',touchPoints:[{x,y,id:1}]});}await send('Input.dispatchTouchEvent',{type:'touchEnd',touchPoints:[]});await delay(400);};
try {
 await send('Runtime.enable');await send('Page.enable');await send('Page.bringToFront');
 await send('Emulation.setFocusEmulationEnabled',{enabled:true});await resize(1440,900);
 const firstLoadMs=await load();
 await shot('full-welcome');
 let s=await state();assert.equal(s.modal,'welcome');assert.equal(s.started,false);
 await key('start');s=await state();assert(s.started&&!s.paused&&s.sound);await key('sound');assert.equal((await state()).sound,false);
 await command('reset');s=await state();assert.equal(s.buildings.filter(b=>b.hostile).length,8);assert.equal(s.seed,41972);
 const frozen=s.time;await delay(450);assert.equal((await state()).time,frozen);await key('pause');assert(!(await state()).paused);await key('pause');assert((await state()).paused);await key('speed_3');assert.equal((await state()).speed,3);await key('speed_1');await key('pause');
 await key('command_warriors');s=await state();assert.equal(s.mode,'warriors');
 await command('camera',{x:s.build_sites.warriors.tile[0],y:s.build_sites.warriors.tile[1]});s=await state();const gold=s.gold;
 await click(s.build_sites.warriors.point);s=await state();let guild=s.buildings.find(b=>b.type==='warriors');assert(guild,'Mouse placement');assert.equal(s.gold,gold-350);
 await command('step',{seconds:60});s=await state();assert.equal(s.buildings.find(b=>b.id===guild.id).progress,1);
 await command('select',{id:guild.id});for(let i=0;i<4;i++)await key('action');s=await state();assert.equal(s.units.filter(u=>u.hero).length,4);
 await key('action');assert.equal((await state()).units.filter(u=>u.hero).length,4);
 await key('close_selection');await key('tab_recruit');assert((await state()).widgets.command_wizard.disabled);
 await shot('full-kingdom');pass('Welcome, audio toggle, pause, mouse construction, workers, recruitment and capacity');

 const lair=s.buildings.find(b=>b.hostile);
 await command('reveal',{x:lair.x,y:lair.y,radius:5});await command('camera',{x:lair.x,y:lair.y});await key('tab_bounty');await key('command_attack');await click(await entityPoint(lair.id));
 s=await state();assert.equal(s.flags.length,1);assert.equal(s.flags[0].target,lair.id);const bountyGold=s.gold;
 await key('action');s=await state();assert.equal(s.flags[0].reward,150);assert.equal(s.gold,bountyGold-50);
 await key('withdraw');s=await state();assert.equal(s.flags.length,0);assert.equal(s.gold,bountyGold+100);
 await key('command_explore');await click([720,460]);s=await state();assert.equal(s.flags[0].type,'explore');await key('withdraw');
 pass('Attack and exploration bounties, raise and refund through visible controls');

 await command('laboratory');s=await state();assert.equal(s.units.filter(u=>u.hero).length,4);
 const market=s.buildings.find(b=>b.type==='marketplace'),temple=s.buildings.find(b=>b.type==='temple');
 await command('select',{id:market.id});await key('research');s=await state();assert.equal(s.modal,'research');assert(s.widgets.learn_strength.disabled);assert(!s.widgets.learn_healing.disabled);
 await shot('full-potion-research');await key('learn_healing');s=await state();assert.equal(s.alchemy.project.key,'healing');assert(s.paused);
 await command('step',{seconds:26});assert((await state()).alchemy.unlocked.healing);
 await command('select',{id:temple.id});await key('research');s=await state();assert(s.widgets.learn_meteor.disabled);assert(s.widgets.learn_farsight.disabled);await shot('full-spellbook');
 await key('learn_heal');await command('step',{seconds:31});assert((await state()).magic.unlocked.heal);
 await key('research');await scrollTo('learn_lightning');await key('learn_lightning');await command('step',{seconds:41});assert((await state()).magic.unlocked.lightning);
 s=await state();const hero=s.units.find(u=>u.hero&&u.type==='warrior');
 await command('damage',{id:hero.id,amount:150});s=await state();const hp=s.units.find(u=>u.id===hero.id).hp;
 await key('close_selection');await command('camera',{x:hero.pos[0],y:hero.pos[1]});await key('tab_spells');await key('command_heal');await click(await entityPoint(hero.id));
 s=await state();assert(s.units.find(u=>u.id===hero.id).hp>hp,'Royal healing via mouse');assert(s.cooldowns.heal>0);assert.equal(s.stats.royal_spells,1);
 await command('step',{seconds:0.15});await shot('full-healing');
 await key('command_farsight');await command('camera',{x:65,y:60});const explored=(await state()).explored;await click([720,430]);s=await state();assert(s.explored>explored);assert(s.cooldowns.farsight>0);
 pass('All hero guilds, potion prerequisites, Temple research, royal healing and farsight');

 await key('save');const saved=await ev('JSON.parse(localStorage.getItem("sovereign-godot-save-v2"))');
 await load();await key('load_welcome');s=await state();assert.equal(s.gold,saved.gold);assert(Math.abs(s.time-saved.time)<0.001);assert.equal(s.rng,saved.rng);assert.deepEqual(s.alchemy,saved.alchemy);assert.deepEqual(s.magic,saved.magic);for(const k in s.cooldowns)assert(Math.abs(s.cooldowns[k]-saved.cooldowns[k])<1e-8);assert.equal(s.seed,saved.fixture.seed);assert(s.paused);
 await ev('localStorage.setItem("sovereign-godot-save-v2","{broken")');await key('load');s=await state();assert.match(s.message,/No compatible/);assert(Math.abs(s.time-saved.time)<1e-8);await key('save');
 pass('Reload persistence for the full kingdom, RNG, inventories, research, cooldowns and malformed-save rejection');
 const victory=await fs.readFile(new URL('../reports/full-victory-save.json',import.meta.url),'utf8');
 await ev(`localStorage.setItem('sovereign-godot-save-v2',${JSON.stringify(victory)})`);await key('load');s=await state();assert.equal(s.result,'victory');assert.equal(s.stats.lairs,8);assert.equal(s.modal,'end');await shot('full-victory');
 await key('replay');s=await state();assert.equal(s.seed,41972);assert.equal(s.result,'');assert.equal(s.stats.lairs,0);
 await command('damage',{id:s.buildings.find(b=>b.type==='palace').id,amount:999999});await command('step',{seconds:0.1});assert.equal((await state()).result,'defeat');assert.equal((await state()).modal,'end');await shot('full-defeat');await key('replay');
 pass('Native campaign victory save renders the ending; Palace defeat and replay controls work');


 await resize(390,844,2,true);await send('Emulation.setTouchEmulationEnabled',{enabled:true,maxTouchPoints:5});await command('reset');s=await state();assert.deepEqual(s.viewport,[390,844]);
 for(const name of ['pause','save','load','help','new','map','zoom_in','tab_build','tab_spells']){const [x,y,w,h]=s.widgets[name].rect;assert(x>=0&&x+w<=391&&y>=0&&y+h<=845,`${name} fits mobile viewport`);}
 await shot('full-mobile');const before=s.camera;await touch([[150,475],[170,480],[200,490],[230,500]]);s=await state();assert(Math.hypot(s.camera[0]-before[0],s.camera[1]-before[1])>40,'Touch pans');
 const z=s.zoom;await touch([s.widgets.zoom_in.point]);assert((await state()).zoom>z);
 await touch([(await state()).widgets.center.point]);s=await state();const palace=s.buildings.find(b=>b.type==='palace');await touch([await entityPoint(palace.id)]);s=await state();assert.equal(s.selection,palace.id);assert.match(s.inspector_text,/Palace/);await shot('full-mobile-inspector');
 await key('close_selection');s=await state();const [mx,my,mw,mh]=s.minimap_rect;const oldCamera=s.camera;await touch([[mx+mw*0.65,my+mh*0.7]]);s=await state();assert(Math.hypot(s.camera[0]-oldCamera[0],s.camera[1]-oldCamera[1])>20,'Minimap moves the camera');await key('center');await key('tab_build');const cardX=(await state()).widgets.command_thieves.point[0];await touch([[320,735],[280,735],[240,735],[200,735],[160,735],[120,735],[80,735]]);await delay(500);assert((await state()).widgets.command_thieves.point[0]<cardX-100,'Touch swipes command cards');assert.equal((await state()).mode,'','Swiping does not activate a card');await scrollTo('command_thieves','deck');await key('command_thieves');assert.equal((await state()).mode,'thieves');await escape();
 await key('help');await shot('full-mobile-help');await scrollTo('close_modal');await key('close_modal');assert.equal((await state()).modal,'');
 await command('laboratory');s=await state();await command('select',{id:s.buildings.find(b=>b.type==='temple').id});await scrollTo('research','inspector');await key('research');await scrollTo('learn_meteor');assert((await state()).widgets.learn_meteor.disabled);await shot('full-mobile-research');await scrollTo('close_modal');await key('close_modal');
 pass('390px DPR2 layout, touch pan/tap, zoom, selection, horizontal cards and scrollable help/research');
 await send('Emulation.setTouchEmulationEnabled',{enabled:false});await resize(1440,900);
 await command('reset',{seed:1});await key('help');await key('replay');assert.equal((await state()).seed,1);await key('new');const oldSeed=(await state()).seed;await key('random_map');assert.notEqual((await state()).seed,oldSeed);
 await key('seed_input');for(const letter of 'Alderwick'){await send('Input.dispatchKeyEvent',{type:'keyDown',key:letter,code:'Key'+letter.toUpperCase(),text:letter,windowsVirtualKeyCode:letter.toUpperCase().charCodeAt(0)});await send('Input.dispatchKeyEvent',{type:'keyUp',key:letter,code:'Key'+letter.toUpperCase(),windowsVirtualKeyCode:letter.toUpperCase().charCodeAt(0)});}await delay(300);assert.equal((await state()).widgets.seed_input.text,'Alderwick');await key('start');assert.equal((await state()).seed,JSON.parse(await fs.readFile(new URL('./reference_maps.json',import.meta.url),'utf8')).at(-1).seed);
 pass('Replay, fresh maps and named seeds');

 const metadata=await ev(`(()=>{const gl=document.createElement('canvas').getContext('webgl2'),ext=gl?.getExtension('WEBGL_debug_renderer_info');return {userAgent:navigator.userAgent,hardwareConcurrency:navigator.hardwareConcurrency,renderer:ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl?.getParameter(gl.RENDERER),viewport:[innerWidth,innerHeight],devicePixelRatio,crossOriginIsolated};})()`);
 const benchmarks=[];
 if(!process.env.GODOT_SKIP_BENCH)for(const count of [100,300,1000]){
  await command('benchmark',{count,seconds:Number(process.env.GODOT_BENCH_SECONDS||15)});let result;
  for(let i=0;i<600;i++){result=await ev('window.sovereignBenchmark?JSON.parse(window.sovereignBenchmark):null');if(result)break;await delay(200);}
  assert(result,`Benchmark ${count} completes`);assert(result.stats.hits>0&&result.stats.moves>0&&result.stats.paths>0);benchmarks.push(result);console.log(JSON.stringify(result));if(count===1000)await shot('full-crowd-1000');
 }
 await send('Page.navigate',{url:origin});
 const playerReady=()=>ev(`location.href===${JSON.stringify(new URL(origin).href)} && document.querySelector("canvas")!==null && document.querySelector("#status")===null && typeof window.sovereignCommand==="undefined"`);
 for(let i=0;i<300;i++){if(await playerReady())break;await delay(200);}
 assert.equal(await playerReady(),true);pass('Player URL starts without automation controls');
 assert.deepEqual(errors,[],'No browser or engine errors');
 await fs.writeFile(path.join(reports,'full-browser.json'),JSON.stringify({recorded_at:new Date().toISOString(),origin,metadata,first_load_ms:firstLoadMs,load_note:'Measured from this test machine with browser cache disabled.',checks,benchmarks,errors},null,2)+'\n');
} catch(error){await shot('full-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-30),state:await state().then(s=>({selection:s.selection,mode:s.mode,modal:s.modal,message:s.message,widgets:s.widgets})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
