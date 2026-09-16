import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,origin,cdp,page,ws,errors,messages,send,ev,delay,state,command,click,shot,load} from './cdp.mjs';
const checks=[];
const pass=name=>{checks.push(name);console.log('PASS:',name);};
const key=async name=>{const s=await state();assert(s.widgets[name],`Control ${name} exists`);assert(!s.widgets[name].disabled,`${name} enabled`);await click(s.widgets[name].point);};
const scrollTo=async(name,area="modal")=>{
 for(let i=0;i<18;i++){
  const s=await state(),[x,y]=s.widgets[name].point,[rx,ry,rw,rh]=area==="modal"?s.modal_rect:[12,170,345,s.viewport[1]-410];
  if(x>rx&&x<rx+rw&&y>ry+35&&y<ry+rh-30)return;
  // Godot routes wheel input through the hovered Control; move into the panel first.
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:rx+rw/2,y:ry+rh/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:rx+rw/2,y:ry+rh/2,deltaX:0,deltaY:y>ry+rh-30?260:-260});await delay(350);
 }
 throw Error(`Could not scroll to ${name}`);
};
const select=async id=>command('select',{id});
const position=async(id,p)=>command('position',{id,x:p[0],y:p[1]});
try{
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});await load();
 assert.equal((await state()).mission.id,'ember_crown');await shot('milestone-welcome');
 await key('mission_classic');assert.equal((await state()).mission.id,'classic');await key('mission_ember_crown');await key('start');
 assert.equal((await state()).mission.id,'ember_crown');pass('Choose Ember Crown or classic campaign through welcome controls');
 await command('laboratory',{mission:'ember_crown'});let s=await state();const guild=s.buildings.find(b=>b.type==='warriors'),hero=s.units.find(u=>u.type==='warrior'&&u.hero);
 await select(guild.id);const gold=(await state()).gold;await key('upgrade');s=await state();assert.equal(s.gold,gold-275);assert(s.widgets.upgrade.disabled);await shot('milestone-training');
 await command('step',{seconds:31});s=await state();assert.equal(s.buildings.find(b=>b.id===guild.id).tier,2);assert.match(s.inspector_text,/Guild support/);
 await key('action');s=await state();assert.equal(s.units.filter(u=>u.hero&&u.home===guild.id).length,2);pass('Paid guild upgrade completes and supports recruitment');
 const lairs=s.buildings.filter(b=>b.hostile&&b.id!==s.mission.encounter_id).slice(0,2);
 for(const b of lairs)await command('damage',{id:b.id,amount:999999});await command('step',{seconds:0.1});s=await state();assert(s.mission.revealed);await key('encounter');assert.equal((await state()).selection,s.mission.encounter_id);
 await command('damage',{id:s.mission.encounter_id,amount:999999});await command('step',{seconds:0.1});s=await state();assert(s.mission.encounter_cleared&&s.mission.boss_id===0);
 const pile=s.loot.find(p=>p.items.includes('runeblade'));await position(hero.id,[pile.x,pile.y]);await command('step',{seconds:2});await select(hero.id);s=await state();assert.equal(s.units.find(u=>u.id===hero.id).equipment.weapon,'runeblade');assert.match(s.inspector_text,/Monastery Runeblade/);await shot('milestone-equipment');
 pass('Objective navigation, monastery rewards and automatic relic equipment');
 await command('step',{seconds:29});s=await state();const boss=s.units.find(u=>u.id===s.mission.boss_id);assert(boss&&!boss.dead);
 await position(hero.id,[boss.pos[0]+0.8,boss.pos[1]]);await command('camera',{x:boss.pos[0],y:boss.pos[1]});await command('step',{seconds:4.1});s=await state();assert(s.mission.slam_remaining>0,'Visible boss warning');await select(boss.id);await shot('milestone-warlord');
 const frozen=s.time;await delay(400);assert.equal((await state()).time,frozen);await key('save');const saved=await ev('JSON.parse(localStorage.getItem("sovereign-godot-save-v2"))');assert.equal(saved.version,3);
 await load();await key('load_welcome');s=await state();assert.equal(s.mission.slam_remaining,saved.mission.slam_remaining);assert.equal(s.mission.boss_id,saved.mission.boss_id);assert.equal(s.units.find(u=>u.id===hero.id).equipment.weapon,'runeblade');
 await command('camera',{x:s.mission.slam_x,y:s.mission.slam_y});await command('step',{seconds:s.mission.slam_remaining+0.1});s=await state();assert(s.stats.boss_slams>saved.stats.boss_slams);assert(s.cue_count>0,'AnimationPlayer impact cues are active');await shot('milestone-impact');pass('Boss telegraph, pause, complete save/reload and animated impact');
 await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(600);await select(hero.id);s=await state();assert.match(s.inspector_text,/Runeblade/);assert.deepEqual(s.viewport,[390,844]);await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:175,y:400,deltaX:0,deltaY:250});await delay(350);await shot('milestone-mobile-equipment');
 await select(guild.id);s=await state();assert(s.widgets.action.point[0]>0&&s.widgets.action.point[0]<390);await scrollTo('action','inspector');const recruits=s.stats.recruits;await key('action');assert.equal((await state()).stats.recruits,recruits+1);await key('help');await shot('milestone-mobile-help');await scrollTo('close_modal');await key('close_modal');assert.equal((await state()).modal,'');pass('390px mobile equipment, guild actions and mission help');
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});await delay(600);
 const victory=await fs.readFile(new URL('../reports/milestone-victory-save.json',import.meta.url),'utf8');await ev(`localStorage.setItem('sovereign-godot-save-v2',${JSON.stringify(victory)})`);await key('load');s=await state();assert.equal(s.result,'victory');assert(s.mission.boss_defeated);await shot('milestone-victory');await key('replay');s=await state();assert.equal(s.mission.id,'ember_crown');assert(!s.mission.boss_defeated);pass('Completed native mission renders victory and replays the same mission');
 assert.deepEqual(errors,[]);
 await fs.writeFile(path.join(reports,'milestone-browser.json'),JSON.stringify({recorded_at:new Date().toISOString(),origin,checks,errors},null,2)+'\n');
}catch(error){await shot('milestone-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-12),state:await state().then(s=>({mission:s.mission,time:s.time,modal:s.modal,selection:s.selection,cue_count:s.cue_count,message:s.message})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
