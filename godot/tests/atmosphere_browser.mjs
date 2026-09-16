import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,origin,cdp,page,ws,errors,send,load,state,click,command,shot,delay} from './cdp.mjs';

const assets=JSON.parse(await fs.readFile(new URL('../data/assets.json',import.meta.url)));
const art=JSON.parse(await fs.readFile(new URL('../data/atmosphere.json',import.meta.url)));
const checks=[];
const pass=text=>{checks.push(text);console.log(text);};
const capture=clip=>send('Page.captureScreenshot',{format:'png',captureBeyondViewport:false,clip});
// CDP temporarily adjusts the viewport for clips. Capture sequentially so its
// restoration cannot race another screenshot and move the browser surface.
async function captureAll(clips) {
  const frames=[];
  for(const c of clips) frames.push(await capture(c.clip));
  return frames;
}
function point(s,b,at) {
  const base=s.entities_on_screen.find(e=>e.id===b.id).point;
  const factor=b.type==='palace'?1.03:.89,a=assets[b.type];
  return [base[0]+(at[0]-a.anchor[0])*factor*s.zoom,
          base[1]+35*s.zoom+(at[1]-a.anchor[1])*factor*s.zoom];
}
try {
  await send('Runtime.enable');await send('Page.enable');await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled',{enabled:true});
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});
  await load('?test=1&auto=1&seed=41972');
  await command('laboratory');
  for(let i=0;i<2;i++) await click((await state()).widgets.zoom_in.point);
  for(const type of ['house','rangers','thieves','warriors','palace','tower']) {
    let s=await state(),b=s.buildings.find(b=>b.type===type&&!b.dead);
    assert(b && b.progress===1,type+' operates in the real game');
    await command('camera',{x:b.x,y:b.y});s=await state();
    const sources=[...(assets[type].effects||[]).filter(e=>e.type==='smoke').map(e=>({kind:'smoke',at:e.at})),
                   ...(art[type]?.flags||[]).map(f=>({kind:'flag',at:f.at}))];
    const clips=sources.map(source=>{
      const p=point(s,b,source.at),z=s.zoom;
      return {kind:source.kind,clip:{x:Math.floor(p[0]-15*z),y:Math.floor(p[1]-(source.kind==='smoke'?58:5)*z),
        width:Math.ceil((source.kind==='smoke'?65:42)*z),height:Math.ceil((source.kind==='smoke'?64:24)*z),scale:1}};
    });
    const before=await captureAll(clips);
    const time=s.time;
    await delay(350);
    const frozen=await captureAll(clips);
    assert.equal((await state()).time,time);
    frozen.forEach((frame,i)=>assert.equal(frame.data,before[i].data,type+' '+clips[i].kind+' freezes exactly'));
    await command('step',{seconds:.45});
    const after=await captureAll(clips);
    after.forEach((frame,i)=>assert.notEqual(frame.data,before[i].data,type+' '+clips[i].kind+' visibly animates'));
    await shot('atmosphere-'+type);
    pass(type+': '+sources.map(s=>s.kind).join(', ')+' moves and pauses correctly');
  }
  // Exercise the ordinary bounty UI, including reward text and selection.
  await command('center');
  await command('mode',{kind:'bounty',type:'explore'});
  for(const p of [[980,500],[1050,450],[920,450]]) {
    await click(p);
    if((await state()).flags.length) break;
  }
  let s=await state();assert(s.flags.some(f=>f.type==='explore'));
  const flag=s.flags.find(f=>f.type==='explore');
  await command('camera',{x:flag.x,y:flag.y});await command('select',{id:0});
  s=await state();const p=s.entities_on_screen.find(e=>e.id===flag.id).point;
  const clip={x:Math.floor(p[0]-4*s.zoom),y:Math.floor(p[1]-77*s.zoom),width:Math.ceil(50*s.zoom),height:Math.ceil(45*s.zoom),scale:1};
  const before=await capture(clip);await command('step',{seconds:.25});
  assert.notEqual((await capture(clip)).data,before.data);
  await shot('atmosphere-bounty');
  pass('Posted bounty cloth ripples and keeps its reward readable');
  const savedTime=(await state()).time;await command('save');await command('load');
  assert.equal((await state()).time,savedTime);assert((await state()).flags.some(f=>f.id===flag.id));
  pass('Atmosphere clock and bounty survive save/load');
  await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});
  s=await state();const house=s.buildings.find(b=>b.type==='house');
  await command('camera',{x:house.x,y:house.y});await shot('atmosphere-mobile');
  assert.deepEqual((await state()).viewport,[390,844]);assert.deepEqual(errors,[]);
  pass('Desktop and phone rendering finish without browser or Godot errors');
  await fs.writeFile(path.join(reports,'atmosphere-browser.json'),JSON.stringify({origin,checks,errors},null,2)+'\n');
} catch(error) {await shot('atmosphere-failure').catch(()=>{});console.error(errors);throw error;}
finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
