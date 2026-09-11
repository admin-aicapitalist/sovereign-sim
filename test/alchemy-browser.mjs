import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';

const url=process.env.SOVEREIGN_TEST_URL||'http://127.0.0.1:8123/';
const tabs=await(await fetch('http://127.0.0.1:9227/json/list')).json();
const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);
await new Promise(r=>ws.onopen=r);
let id=0;const pending=new Map(),errors=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);};
const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
const ev=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const clickXY=async(x,y)=>{await send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});await send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});};
const click=async selector=>{
  await ev(`document.querySelector(${JSON.stringify(selector)}).scrollIntoView({block:'center',inline:'center'})`);
  const p=await ev(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);await clickXY(p.x,p.y);
};
const shot=async name=>fs.writeFile(path.join(os.tmpdir(),'sovereign-'+name+'.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));

try{
  await send('Runtime.enable');await send('Page.enable');
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
  errors.length=0; // Runtime.enable replays errors from the previous page.
  await send('Page.navigate',{url:new URL('?seed=41972&auto=1',url).href});
  for(let i=0;i<150;i++){if(await ev('!!window.G?.ui&&typeof G.start==="function"'))break;await delay(100);}
  await ev('G.spriteAssetsReady');await ev('G.paused=true;G.ui.update(true)');
  assert.equal(await ev('G.sprites.thieves.assetLoaded&&G.sprites.idle_thief.assetLoaded'),true,'guild and thief artwork load');
  await click('.command-card[aria-label^="Thieves"]');assert.equal(await ev('G.mode.key'),'thieves');
  const p=await ev('G.worldToScreen(16.25,18.25)');await clickXY(p.x,p.y);
  assert.equal(await ev('G.buildings.some(b=>b.type==="thieves"&&b.progress<1)'),true,'construct command places new guild');
  await ev('G.build("marketplace",19,24);G.headless=true;G.paused=false;for(let i=0;i<600;i++)G.update(.1);G.paused=true;G.headless=false;G.selected=G.buildings.find(b=>b.type==="thieves");G.ui.update(true)');
  assert.equal(await ev('G.selected.progress'),1,'peasants complete guild');
  const before=await ev('G.gold');await click('#inspect-recruit');
  assert.equal(await ev('G.units.filter(u=>u.type==="thief"&&u.hero).length'),1);
  assert.equal(await ev('G.gold'),before-110);
  await ev('G.selected=G.buildings.find(b=>b.type==="marketplace");G.ui.update(true)');
  await click('#inspect-research');
  assert.equal(await ev('document.querySelectorAll(".recipe").length'),3);
  assert.equal(await ev('document.querySelector("[data-potion=strength]").disabled'),true);
  assert.equal(await ev('document.querySelector("[data-potion=healing]").disabled'),false);
  await shot('alchemy-research-desktop');
  await click('[data-potion=healing]');
  assert.equal(await ev('G.alchemy.project.key'),'healing');
  assert.equal(await ev('G.modalOpen'),false,'funding research returns to game');
  assert.equal(await ev('G.paused'),true,'research preserves a previously paused game');
  assert.equal(await ev('!!document.querySelector(".research-status progress")'),true);
  await ev('G.headless=true;G.paused=false;for(let i=0;i<260;i++)G.update(.1);G.paused=true;G.headless=false;G.ui.update(true)');
  assert.equal(await ev('G.alchemy.unlocked.healing'),true);
  await click('#inspect-research');assert.equal(await ev('document.querySelector("[data-potion=healing]").disabled'),true);
  assert.equal(await ev('document.querySelector("[data-potion=strength]").disabled'),false);
  await click('[data-potion=strength]');
  await ev('G.headless=true;G.paused=false;for(let i=0;i<410;i++)G.update(.1);G.paused=true;G.headless=false;G.ui.update(true)');
  assert.equal(await ev('G.alchemy.unlocked.strength'),true);
  // Give a test bounty purse and place the hero at the counter; the real AI chooses the purchase.
  await ev('(()=>{const m=G.selected,h=G.units.find(u=>u.type==="thief"&&!u.dead);h.x=m.x+2;h.y=m.y;h.gold=66;h.potions={healing:0,strength:0,stoneskin:0};h.hp=h.maxHp;h.target=null;h.goal=null;G.thinkUnit(h);G.selected=h;G.ui.update(true)})()');
  assert.deepEqual(await ev('[G.selected.potions.healing,G.selected.potions.strength,G.selected.gold]'),[2,1,0]);
  assert.equal(await ev('document.querySelectorAll(".supply-item").length'),3);
  await shot('thief-inventory-desktop');
  console.log('✓ Desktop: guild construction/recruitment, research prerequisites, paid progress, unlocking, autonomous shopping and inventory.');

  await send('Emulation.setDeviceMetricsOverride',{width:393,height:852,deviceScaleFactor:2,mobile:true});
  await delay(250);await ev('G.ui.update(true)');
  assert.equal(await ev('(()=>{const p=document.querySelector(".hero-supplies");return p.offsetWidth>0&&p.getBoundingClientRect().right<=innerWidth})()'),true,'inventory remains visible on a phone');
  await shot('thief-inventory-mobile');
  await ev('G.selected=G.buildings.find(b=>b.type==="marketplace");G.ui.update(true)');
  await click('#inspect-research');
  assert.equal(await ev('(()=>{const m=document.querySelector(".modal").getBoundingClientRect();return m.left>=0&&m.right<=innerWidth&&m.bottom<=innerHeight})()'),true);
  await shot('alchemy-research-mobile');
  await click('[data-potion=stoneskin]');
  assert.equal(await ev('G.alchemy.project.key'),'stoneskin','phone research button is reachable');
  await ev('G.ui.update(true)');assert.equal(await ev('!!document.querySelector(".research-status progress")'),true);
  assert.deepEqual(errors,[]);
  console.log('✓ Mobile: inventory, scrolling research cards and working research controls; no browser exceptions.');
}finally{
  await send('Emulation.clearDeviceMetricsOverride');ws.close();
}
