import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,origin,cdp,page,ws,errors,messages,send,ev,delay,state,command,click,shot,load} from './cdp.mjs';
const prefix='sovereign-settlement-test-v1-';
const checks=[];
const pass=name=>{checks.push(name);console.log('PASS:',name);};
async function key(name){
 for(let i=0;i<24;i++){
  const s=await state(),w=s.widgets[name];assert(w,`Control ${name} exists`);assert(!w.disabled,`${name} enabled`);
  const [x,y]=w.point;
  const bounds=w.clip_rect||s.modal_rect;
  if(!s.modal || (y>bounds[1]+20 && y<bounds[1]+bounds[3]-20)) {await click([x,y]);return;}
  const [rx,ry,rw,rh]=bounds;
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:rx+rw/2,y:ry+rh/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:rx+rw/2,y:ry+rh/2,deltaX:0,deltaY:y<ry+28?-230:230});await delay(180);
 }
 throw Error(`Could not scroll to ${name}`);
}
const saved=async slot=>ev(`JSON.parse(JSON.parse(localStorage.getItem(${JSON.stringify(prefix+slot)})).payload)`);
async function moving(label){
 const before=await state();
 assert(before.started&&!before.paused&&before.modal==='',`${label}: simulation is running`);
 await delay(1800);
 const after=await state();
 assert(after.time>before.time+0.5,`${label}: time advances without test stepping`);
 assert(before.units.some(u=>!u.hostile&&!u.dead&&after.units.some(v=>v.id===u.id&&Math.hypot(v.pos[0]-u.pos[0],v.pos[1]-u.pos[1])>0.05)),`${label}: settlement units move`);
}
async function frozen(label){
 const before=await state();assert(before.paused,`${label}: simulation is paused`);
 await delay(700);assert.equal((await state()).time,before.time,`${label}: time stays paused`);
}
try{
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await load();
 await ev(`Object.keys(localStorage).filter(k=>k.startsWith(${JSON.stringify(prefix)})).forEach(k=>localStorage.removeItem(k))`);await load();
 let s=await state();assert.equal(s.modal,'setup');assert.equal(s.run.config.scenario,'ember_crown');assert(s.widgets.charter_guild_compact.disabled);
 await shot('settlement-setup');await key('condition_rich_ruins');assert.equal((await state()).run.config.condition,'rich_ruins');await key('condition_untroubled');
 await key('start');s=await state();const first=s.run.config.id;
 assert.equal((await saved('active')).run.config.id,first);await moving('Found settlement');
 await key('heroes');s=await state();assert.equal(s.modal,'heroes');assert.match(s.modal_text,/No heroes recruited yet/);assert(s.widgets.hero_build_guild);await key('heroes_close');
 await key('pause');await frozen('Pause button');
 for(const type of ['keyDown','keyUp'])await send('Input.dispatchKeyEvent',{type,key:' ',code:'Space',windowsVirtualKeyCode:32,nativeVirtualKeyCode:32});
 await delay(300);await moving('Space resumes');
 await key('new');await frozen('Reign menu');await key('resume');await moving('Return to kingdom');
 await key('pause');pass('Founding starts live movement; Pause, Space, and Reign menu preserve time controls');
 await key('command_warriors');await click((await state()).build_sites.warriors.point);await command('step',{seconds:40});s=await state();
 const guild=s.buildings.find(b=>b.type==='warriors');assert(guild&&guild.progress===1);await key('action');s=await state();assert.equal(s.stats.recruits,1);
 const hero=s.units.find(u=>u.hero&&!u.dead);
 await key('heroes');s=await state();assert.match(s.modal_text,new RegExp(hero.name));await shot('settlement-heroes');
 await key('hero_'+hero.id);s=await state();assert.equal(s.modal,'hero_journal');assert.match(s.modal_text,/NEXT LEVEL · 2/);assert.match(s.modal_text,/45 XP remaining/);assert.match(s.modal_text,/Joined the settlement/);await shot('settlement-hero-journal');
 await key('hero_guild');s=await state();assert.equal(s.selection,guild.id);assert(s.paused);
 await key('heroes');await key('hero_'+hero.id);const beforeService=(await state()).gold;await key('hero_service_marketplace');s=await state();assert.equal(s.mode_kind,'build');assert.equal(s.mode,'marketplace');assert.equal(s.gold,beforeService);
 await key('heroes');await key('hero_'+hero.id);await key('hero_guild');s=await state();assert.equal(s.mode_kind,'');assert.equal(s.selection,guild.id);
 await key('heroes');await key('hero_'+hero.id);await key('hero_bounty_explore');s=await state();assert.equal(s.mode_kind,'bounty');assert.equal(s.mode,'explore');
 await command('mode',{kind:'',type:''});await command('damage',{id:hero.id,amount:hero.max_hp*0.8});await command('step',{seconds:2});
 await key('heroes');await key('hero_'+hero.id);s=await state();assert.match(s.modal_text,/recover to about 86% health/);assert.match(s.modal_text,/Began resting|Withdrew to recover/);
 await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(500);s=await state();
 assert(s.modal_rect[0]>=0&&s.modal_rect[0]+s.modal_rect[2]<=390);assert(s.widgets.hero_find.rect[1]+s.widgets.hero_find.rect[3]<=844);await shot('settlement-hero-mobile');
 await key('hero_roster');await shot('settlement-heroes-mobile');await key('hero_'+hero.id);await key('hero_find');s=await state();assert.equal(s.selection,hero.id);assert(s.widgets.hero_journal);await frozen('Hero journal preserves deliberate pause');
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await delay(500);await command('step',{seconds:30});
 pass('Heroes roster, journal, XP guidance, recovery history and service/bounty navigation work on desktop and phone');
 if(s.widgets.dismiss_hint)await key('dismiss_hint');
 await key('save');const early=await ev(`localStorage.getItem(${JSON.stringify(prefix+'active')})`);
 await key('new');await key('save_leave');assert.equal((await state()).modal,'title');await key('load_welcome');s=await state();
 assert.equal(s.run.config.id,first);assert.equal(s.stats.recruits,1);await moving('Resume saved settlement');
 await key('heroes');await key('hero_'+hero.id);s=await state();assert.match(s.modal_text,/Recovered enough to venture out again/);await key('hero_find');await moving('Hero journal returns to live play');
 await key('pause');pass('Ordinary construction, recruitment, hints, saved hero history and live resume');
 // Test-only damage controls arrange outcomes; all persistence and result controls are production paths.
 for(const b of s.buildings.filter(b=>b.hostile&&b.id!==s.mission.encounter_id).slice(0,2))await command('damage',{id:b.id,amount:999999});
 s=await state();await command('damage',{id:s.mission.encounter_id,amount:999999});await command('step',{seconds:0.1});s=await state();
 assert(s.mission.revealed&&s.mission.encounter_cleared&&s.mission.arrival_remaining>89);
 await key('save');await load();await key('load_welcome');await key('pause');s=await state();assert(s.mission.arrival_remaining>89&&s.mission.arrival_remaining<=90);
 await command('step',{seconds:91});s=await state();assert(s.mission.boss_id>0);
 // Fail the profile write after the completion receipt is durable, then reload to recover it.
 await ev(`window.originalSettlementSet=Storage.prototype.setItem; Storage.prototype.setItem=function(k,v){if(k===${JSON.stringify(prefix+'profile')})throw new DOMException('Injected full storage','QuotaExceededError');return window.originalSettlementSet.call(this,k,v);}`);
 await command('damage',{id:s.mission.boss_id,amount:999999});await command('step',{seconds:0.1});s=await state();
 assert.equal(s.result,'victory');assert.equal(s.modal,'end');assert(!s.completion_saved);assert(s.widgets.retry_result);assert(!s.widgets.fresh);
 assert.equal((await saved('receipt')).id,first);await shot('settlement-storage-retry');
 await load();await key('load_welcome');s=await state();assert(s.completion_saved);assert.equal(s.result,'victory');assert(s.buildings.some(b=>b.hostile&&!b.dead));
 const renown=s.settlement_profile.renown;assert(renown>=15&&renown<=17);await shot('settlement-result');pass('Out-of-order encounter saves, boss victory, and interruption recovery award Renown once');
 await key('unlock_compact');s=await state();assert.equal(s.settlement_profile.renown,renown-10);assert(s.settlement_profile.unlocks.guild_compact);
 await ev(`localStorage.setItem(${JSON.stringify(prefix+'active')},${JSON.stringify(early)})`);await load();await key('load_welcome');s=await state();
 assert.equal(s.result,'victory');assert.equal(s.settlement_profile.renown,renown-10);assert.equal(Object.keys(s.settlement_profile.completed).length,1);
 pass('Persistent unlock purchase and older-save restoration cannot duplicate or replace the result');
 await key('replay');s=await state();assert.equal(s.modal,'setup');assert.equal(s.seed,41972);assert.notEqual(s.run.config.id,first);assert.equal(s.stats.recruits,0);
 await key('charter_guild_compact');await key('start');await moving('Replay');await key('pause');s=await state();assert.equal(s.run.config.charter,'guild_compact');
 await key('command_warriors');const grant=s.gold;await click((await state()).build_sites.warriors.point);s=await state();assert.equal(s.gold,grant-298);pass('Replay creates a fresh cast and applies the unlocked charter');
 await key('new');await key('abandon');s=await state();assert.equal(s.result,'abandoned');assert.equal(s.settlement_profile.renown,renown-10);
 await key('fresh');await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(500);
 s=await state();assert(s.modal_rect[0]>=0&&s.modal_rect[0]+s.modal_rect[2]<=390);await shot('settlement-mobile-setup');
 await key('condition_rich_ruins');await key('start');await moving('Phone founding');await key('pause');s=await state();await command('damage',{id:s.buildings[0].id,amount:999999});await command('step',{seconds:0.1});s=await state();
 assert.equal(s.result,'defeat');assert(s.completion_saved);assert.equal(s.settlement_profile.renown,renown-10);await shot('settlement-mobile-defeat');await key('fresh');
 pass('390px setup, fresh-run reset, abandonment and Palace defeat complete the loop');
 assert.deepEqual(errors,[]);
 await fs.writeFile(path.join(reports,'settlement-browser.json'),JSON.stringify({recorded_at:new Date().toISOString(),origin,checks,errors},null,2)+'\n');
}catch(error){await shot('settlement-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-12),state:await state().then(s=>({modal:s.modal,run:s.run?.config,result:s.result,storage:s.storage_message,widgets:Object.keys(s.widgets)})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
