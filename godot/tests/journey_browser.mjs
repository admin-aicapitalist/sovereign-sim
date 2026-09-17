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
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:b[0]+b[2]/2,y:b[1]+b[3]/2,deltaX:0,deltaY:y<b[1]? -280:280});await delay(160);
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
 for(const text of ['Refusal','Tests & Allies','Shadow','Mastery','One support condition','Complete a new Temple','WHERE / CURRENT CALL','WHAT HELPS NEXT'])assert(s.modal_text.includes(text),text);
 assert(s.modal_rect[2]>1100);await shot('journey-overview');pass('All heroes expose real journey stages, locations, blockers and actions in one overview');
 await key('journey_filter_help');s=await state();assert(s.widgets['hero_'+warrior.id]);assert(!s.widgets['hero_'+wizard.id]);
 const gold=s.gold;await key('journey_action_'+warrior.id);s=await state();assert.equal(s.gold,gold-50);assert.match(s.modal_text,/Support is ready/);assert.equal(s.units.find(u=>u.id===warrior.id).journey.stage,'refusal');
 await key('journey_filter_all');await key('journey_pause');s=await state();assert(!s.paused);const before=s.time;await delay(2200);s=await state();
 assert.equal(s.modal,'journeys');assert(s.time>before+0.5);assert(['threshold','tests','ordeal'].includes(s.units.find(u=>u.id===warrior.id).journey.stage));
 await key('journey_pause');const paused=(await state()).time;await delay(800);assert.equal((await state()).time,paused);
 pass('Inline support spending advances refusal while the overview stays live, with working pause control');
 await key('journey_filter_recovery');s=await state();assert(s.widgets['hero_'+wizard.id]);assert(!s.widgets['hero_'+warrior.id]);
 await key('journey_action_'+wizard.id);s=await state();assert.equal(s.modal,'');assert.equal(s.mode_kind,'build');assert.equal(s.mode,'temple');assert(s.paused);
 await key('heroes');await key('journey_filter_fallen');s=await state();assert(s.modal_text.includes(fallen.name));assert.match(s.modal_text,/Fell during Ordinary World/);
 await key('journey_filter_all');await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(600);s=await state();
 assert(s.modal_rect[0]>=0&&s.modal_rect[0]+s.modal_rect[2]<=390);for(const h of heroes)assert(s.widgets['journey_action_'+h.id]);
 for(const name of ['journey_filter_all','journey_filter_help','journey_pause','heroes_close']){const r=s.widgets[name].rect;assert(r[0]>=0&&r[0]+r[2]<=390&&r[1]>=0&&r[1]+r[3]<=844,`${name} fits phone`);}
 await shot('journey-mobile');await key('journey_filter_recovery');await shot('journey-mobile-recovery');
 pass('Filters, fallen heroes and support actions are accessible on a 390px phone without opening journals');
 await key('heroes_close');await key('save');const beforeSave=await state();await load();await key('load_welcome');await key('pause');await key('heroes');await key('journey_filter_all');s=await state();
 assert.equal(s.run.config.id,beforeSave.run.config.id);assert.equal(s.units.find(u=>u.id===wizard.id).journey.stage,'shadow');
 const restored=s.units.find(u=>u.id===warrior.id).journey.history;const expected=beforeSave.units.find(u=>u.id===warrior.id).journey.history;assert.deepEqual(restored.slice(0,expected.length),expected);
 await key('journey_filter_fallen');assert((await state()).modal_text.includes(fallen.name));
 pass('Saved journey stages, transition history and fallen-hero records return in the overview');
 assert.deepEqual(errors,[]);await fs.writeFile(path.join(reports,'journey-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
}catch(error){await shot('journey-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-8),state:await state().then(s=>({modal:s.modal,text:s.modal_text,widgets:s.widgets})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
