import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,origin,cdp,page,ws,errors,messages,send,load,state,click,command,shot,delay} from './cdp.mjs';
const assets=JSON.parse(await fs.readFile(new URL('../data/assets.json',import.meta.url)));
const cast=JSON.parse(await fs.readFile(new URL('../data/leisure_cast.json',import.meta.url)));
const checks=[];
const pass=name=>{checks.push(name);console.log('PASS:',name);};
const capture=async clip=>(await send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,clip})).data;
const clip=(x,y,width,height)=>({x:Math.floor(x),y:Math.floor(y),width:Math.ceil(width),height:Math.ceil(height),scale:1});
function buildingPoint(s,b,point){
 const base=s.entities_on_screen.find(e=>e.id===b.id).point,a=assets[b.type],f=.89*s.zoom;
 return [base[0]+(point[0]-a.anchor[0])*f,base[1]+35*s.zoom+(point[1]-a.anchor[1])*f];
}
async function key(name){
 for(let i=0;i<24;i++){
  const s=await state(),w=s.widgets[name];assert(w,`${name} exists`);assert(!w.disabled,`${name} enabled`);
  const [x,y]=w.point,b=w.clip_rect||s.modal_rect;
  if(!b?.length||(y>b[1]+8&&y<b[1]+b[3]-8)){await click([x,y]);return;}
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:b[0]+b[2]/2,y:b[1]+b[3]/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:b[0]+b[2]/2,y:b[1]+b[3]/2,deltaX:0,deltaY:y<b[1]? -240:240});await delay(180);
 }
 throw Error(`Could not reach ${name}`);
}
try{
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
 await load();await command('leisure_fixture');
 let s=await state();assert.equal(s.units.filter(u=>u.hero&&!u.dead&&u.inside>0).length,7);
 assert.equal(s.performers.length,4);assert.equal(s.rendered_units,s.units.filter(u=>!u.dead&&u.inside===0&&s.entities_on_screen.find(e=>e.id===u.id)).length);
 for(const type of ['inn','brothel','warriors','rangers','wizards','thieves','temple']){
  s=await state();const b=s.buildings.find(b=>b.type===type&&!b.dead),a=assets[type];
  await command('camera',{x:b.x,y:b.y});await command('select',{id:0});s=await state();
  const z=s.zoom,clips=[];
  for(const p of s.performers.filter(p=>p.building===b.id)){
   const a=cast[p.actor],f=.89*z;
   clips.push({name:p.actor,clip:clip(p.point[0]-a.anchor[0]*f,p.point[1]-a.anchor[1]*f,a.size[0]*f,a.size[1]*f)});
  }
  const mast=buildingPoint(s,b,[a.anchor[0]+14,a.bounds[1]-6]);
  clips.push({name:'occupied pennant',clip:clip(mast[0]-2*z,mast[1]-18*z,30*z,19*z)});
  const lamp=buildingPoint(s,b,a.lanterns?.[0].at||[a.anchor[0]-7,a.anchor[1]-23]);
  clips.push({name:'occupied light',clip:clip(lamp[0]-7*z,lamp[1]-7*z,14*z,14*z)});
  const before=[];for(const c of clips)before.push(await capture(c.clip));
  const frozenTime=s.time,rng=s.rng;await delay(400);
  for(let i=0;i<clips.length;i++)assert.equal(await capture(clips[i].clip),before[i],type+' '+clips[i].name+' freezes');
  assert.equal((await state()).time,frozenTime);assert.equal((await state()).rng,rng);
  await command('step',{seconds:.55});
  for(let i=0;i<clips.length;i++)assert.notEqual(await capture(clips[i].clip),before[i],type+' '+clips[i].name+' visibly animates');
  await command('select',{id:b.id});s=await state();assert.match(s.inspector_text,/Inside: 1\b/);
  const id=s.occupancy[String(b.id)][0];assert(s.inspector_text.includes(s.units.find(u=>u.id===id).name));assert(s.widgets['occupant_'+id]);
  if(['inn','brothel','temple','warriors'].includes(type))await shot('leisure-'+type);
  pass(type+': occupants, animated lights/flags'+(clips.length>2?', scenery loops':'')+' and exact pause');
 }
 s=await state();const inn=s.buildings.find(b=>b.type==='inn'),patron=s.units.find(u=>u.inside===inn.id);
 await command('select',{id:inn.id});await key('occupant_'+patron.id);assert.equal((await state()).modal,'hero_journal');
 await key('hero_find');assert.equal((await state()).selection,inn.id);
 await key('heroes');s=await state();assert(s.modal_text.includes('Inside '+inn.site_name));await shot('leisure-overview');await key('heroes_close');
 await command('save');const saved=await state();await command('load');s=await state();assert.deepEqual(s.occupancy,saved.occupancy);
 assert.deepEqual(s.units.filter(u=>u.hero).map(u=>[u.id,u.inside,u.journey.aspect,u.gold]),saved.units.filter(u=>u.hero).map(u=>[u.id,u.inside,u.journey.aspect,u.gold]));
 pass('Occupant journal, focus on shelter, all-hero locations and saved occupancy work through real UI');
 await command('camera',{x:inn.x,y:inn.y});await command('select',{id:inn.id});
 await command('position',{id:patron.id,x:inn.x,y:inn.ty+inn.size+1});s=await state();
 assert(!s.occupancy[String(inn.id)]);assert(!s.widgets['occupant_'+patron.id]);assert.match(s.inspector_text,/Inside: 0\b/);
 const brothel=s.buildings.find(b=>b.type==='brothel'),resident=s.units.find(u=>u.inside===brothel.id);
 await command('damage',{id:brothel.id,amount:999999});s=await state();assert.equal(s.units.find(u=>u.id===resident.id).inside,0);assert(!s.performers.some(p=>p.building===brothel.id));
 pass('Departure removes stale occupant actions; collapse releases heroes and removes scenery actors');
 await command('leisure_fixture');await key('speed_2');await delay(800);await command('pause',{value:true});s=await state();
 assert.equal(s.speed,2);assert(s.presentation_time>0.5);
 for(const p of s.performers){const a=cast[p.actor],phase=assets[s.buildings.find(b=>b.id===p.building).type].visitors.find(v=>v.actor===p.actor).phase+p.building*.017;assert.equal(p.frame,Math.floor(s.presentation_time*a.fps+phase*a.frames.length)%a.frames.length);}
 pass('Venue loops follow the shared game clock at 2× speed');
 await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(500);
 s=await state();const phoneVenue=s.buildings.find(b=>b.type==='brothel');await command('camera',{x:phoneVenue.x,y:phoneVenue.y});await command('select',{id:phoneVenue.id});await shot('leisure-mobile');
 await key('heroes');assert((await state()).modal_text.includes('Inside '+phoneVenue.site_name));await shot('leisure-mobile-overview');
 assert.deepEqual(errors,[]);pass('390px phone shows venue art, residents and all-hero indoor locations without runtime errors');
 await fs.writeFile(path.join(reports,'leisure-browser.json'),JSON.stringify({origin,checks,errors},null,2)+'\n');
}catch(error){await shot('leisure-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-8)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
