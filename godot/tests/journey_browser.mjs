import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,messages,send,load,state,click,command,shot,delay} from './cdp.mjs';
const checks=[];
const pass=name=>{checks.push(name);console.log('PASS:',name);};
async function key(name){
 for(let i=0;i<30;i++){
  const s=await state(),w=s.widgets[name];assert(w,`${name} exists`);assert(!w.disabled,`${name} enabled`);
  const [x,y]=w.point,b=w.clip_rect||s.modal_rect;
  if(!s.modal||(y>b[1]+8&&y<b[1]+b[3]-8)){await click([x,y]);return;}
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:b[0]+b[2]/2,y:b[1]+b[3]/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:b[0]+b[2]/2,y:b[1]+b[3]/2,deltaX:0,deltaY:y<b[1]? -280:280});await delay(450); // The UI bridge refreshes every 250 ms; wait for new scrolled coordinates.
 }
 throw Error(`Could not reach ${name}`);
}
try{
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await load();await command('journey_fixture');
 let s=await state();const heroes=s.units.filter(u=>u.hero&&!u.dead),warrior=heroes.find(u=>u.type==='warrior'),wizard=heroes.find(u=>u.type==='wizard');
 const fallen=Object.values(s.run.heroes).find(h=>h.dead);assert.equal(heroes.length,4);
 await key('heroes');s=await state();assert.equal(s.modal,'journeys');
 for(const hero of heroes){assert(s.modal_text.includes(hero.name));assert(s.widgets['hero_'+hero.id]);assert(s.widgets['journey_action_'+hero.id]);}
 for(const text of ['Refusal','Tests & Allies','Shadow','Mastery','One support condition','Needs royal support','WHERE / CURRENT CALL','WHAT HELPS NEXT'])assert(s.modal_text.includes(text),text);
 assert(!s.modal_text.includes('Stage 1 / 8'));assert(s.modal_text.includes('Persona'));assert(s.modal_text.includes('Purse'));assert(s.modal_rect[2]>1100);await shot('journey-overview');pass('All heroes expose real journey stages, locations, blockers and actions in one overview');
 await key('journey_filter_help');s=await state();assert(s.widgets['hero_'+warrior.id]);assert(!s.widgets['hero_'+wizard.id]);
 const gold=s.gold;await key('journey_action_'+warrior.id);s=await state();assert.equal(s.gold,gold-50);assert.match(s.modal_text,/Support is ready/);assert.equal(s.units.find(u=>u.id===warrior.id).journey.stage,'refusal');
 await key('journey_filter_all');await key('journey_pause');s=await state();assert(!s.paused);const before=s.time;await delay(2200);s=await state();
 assert.equal(s.modal,'journeys');assert(s.time>before+0.5);assert(['threshold','tests','ordeal'].includes(s.units.find(u=>u.id===warrior.id).journey.stage));
 await key('journey_pause');const paused=(await state()).time;await delay(800);assert.equal((await state()).time,paused);
 assert(s.run.court?.stolen>0);
 pass('Inline support spending advances refusal while the overview stays live, with working pause control');
 await key('journey_filter_shadow');s=await state();assert(s.widgets['hero_'+wizard.id]);assert(!s.widgets['hero_'+warrior.id]);
 const supportGold=s.gold;await key('journey_action_'+wizard.id);s=await state();assert.equal(s.modal,'journeys');assert.equal(s.gold,supportGold-80);assert(s.modal_text.includes('Royal support funded'));assert.equal(s.units.find(u=>u.id===wizard.id).journey.aspect,'shadow');assert(s.paused);
 await key('journey_economy');s=await state();assert.equal(s.modal,'court');
 const thief=heroes.find(u=>u.type==='thief'), bank=s.run.court.banks[String(thief.home)];assert(bank>0,'A thief earned guild money from a real patron while time advanced');
 const seizureGold=s.gold;await key('court_seize_'+thief.home);s=await state();assert.equal(s.gold,seizureGold+bank);assert.equal(s.run.court.banks[String(thief.home)],0);assert(s.widgets['court_seize_'+thief.home].disabled);assert(s.modal_text.includes('120s'));await shot('journey-guild-banks');
 await key('court_journeys');await key('journey_filter_fallen');s=await state();assert(s.modal_text.includes(fallen.name));assert.match(s.modal_text,/Fell during Ordinary World/);
 await key('journey_filter_all');await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(600);s=await state();
 assert(s.modal_rect[0]>=0&&s.modal_rect[0]+s.modal_rect[2]<=390);for(const h of heroes)assert(s.widgets['journey_action_'+h.id]);
 for(const name of ['journey_filter_all','journey_filter_help','journey_pause','heroes_close']){const r=s.widgets[name].rect;assert(r[0]>=0&&r[0]+r[2]<=390&&r[1]>=0&&r[1]+r[3]<=844,`${name} fits phone`);}
 await shot('journey-mobile');await key('journey_filter_shadow');await shot('journey-mobile-recovery');
 pass('Filters, fallen heroes and support actions are accessible on a 390px phone without opening journals');
 await key('heroes_close');await key('save');const beforeSave=await state();await load();await key('load_welcome');await key('pause');await key('heroes');await key('journey_filter_all');s=await state();
 assert.equal(s.run.config.id,beforeSave.run.config.id);assert.equal(s.units.find(u=>u.id===wizard.id).journey.aspect,'shadow');
 const restored=s.units.find(u=>u.id===warrior.id).journey.history;const expected=beforeSave.units.find(u=>u.id===warrior.id).journey.history;assert.deepEqual(restored.slice(0,expected.length),expected);
 await key('journey_filter_fallen');assert((await state()).modal_text.includes(fallen.name));
 assert(s.units.find(u=>u.id===wizard.id).journey.recovery_site>0);assert(s.run.court.confiscate_ready>s.time);
 pass('Saved Shadow, funded recovery, guild banks, cooldown and fallen-hero history return in the overview');
 await key('heroes_close');await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await delay(500);
 for(const [type,cost] of [['inn',180],['brothel',240]]){
  await key('heroes');await key('journey_economy');await key('court_build_'+type);s=await state();assert.equal(s.modal,'');assert.equal(s.mode_kind,'build');assert.equal(s.mode,type);
  const count=s.buildings.filter(b=>b.type===type).length,beforeGold=s.gold;assert(s.build_sites[type].tile[0]>=0);
  await click(s.build_sites[type].point);s=await state();assert.equal(s.gold,beforeGold-cost);assert.equal(s.buildings.filter(b=>b.type===type).length,count+1);
  await command('step',{seconds:35});s=await state();assert(s.buildings.filter(b=>b.type===type).every(b=>b.progress===1));
 }
 await command('center');await shot('journey-leisure-buildings');pass('Both new venues can be ordered through the economy menu and completed by workers with paid construction');
 assert.deepEqual(errors,[]);await fs.writeFile(path.join(reports,'journey-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
}catch(error){await shot('journey-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-8),state:await state().then(s=>({modal:s.modal,text:s.modal_text,widgets:s.widgets})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
