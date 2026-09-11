import fs from 'node:fs/promises';
import os from 'node:os';
import path from 'node:path';
import assert from 'node:assert/strict';
const url=process.env.SOVEREIGN_TEST_URL||'http://127.0.0.1:8123/';
const tabs=await(await fetch('http://127.0.0.1:9227/json/list')).json();
const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise(r=>ws.onopen=r);
let id=0;const pending=new Map(),errors=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);};
const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
const ev=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const ready=async()=>{for(let i=0;i<200;i++){if(await ev('typeof G!=="undefined"&&typeof G.start==="function"')){await ev('Promise.all([G.spriteAssetsReady,document.fonts.ready]).then(()=>true)');return;}await delay(100);}throw Error('World did not load');};
const clickXY=async(x,y)=>{await send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y});await send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});await send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});await delay(100);};
const shot=async name=>fs.writeFile(path.join(os.tmpdir(),'sovereign-map-'+name+'.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));
await send('Page.enable');await send('Runtime.enable');
for(const [width,height,dpr] of [[1440,1000,1],[390,844,2]]){
  await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:width<581});
  await send('Page.navigate',{url:url+'?auto=1'});await ready();await ev('G.paused=true;G.selected=null;G.ui.update(true)');
  assert.equal(await ev('G.MAP'),88);assert.equal(await ev('document.querySelector("#lair-count").textContent'),'0 / 8');
  assert.equal(await ev('document.querySelectorAll(".objective").length'),8);
  const points=[[.5,.5],[87.5,.5],[87.5,87.5],[.5,87.5],[70,73]];
  for(const [x,y]of points){
    const p=await ev(`(()=>{const m=document.querySelector('#minimap'),r=m.getBoundingClientRect(),{scale,ox,oy}=G.minimapTransform();return{x:r.x+((${x}-${y})*scale+ox)*r.width/m.width,y:r.y+((${x}+${y})*scale*.66+oy)*r.height/m.height};})()`);
    await clickXY(p.x,p.y);
    const center=await ev('G.uniso(G.camera.x,G.camera.y)');assert(Math.abs(center.x-x)<.1&&Math.abs(center.y-y)<.1,JSON.stringify({x,y,center}));
  }
  assert.equal(await ev(`(()=>{for(const [x,y]of[[-100000,-100000],[100000,100000],[-100000,100000],[100000,-100000]]){G.camera.x=x;G.camera.y=y;G.updateCamera(0);const p=G.uniso(G.camera.x,G.camera.y);if(p.x<0||p.y<0||p.x>=G.MAP||p.y>=G.MAP)return false;}return true;})()`),true,'panning stays within the expanded map');
  const stats=await ev(`(()=>{G.centerCamera();G.changeZoom(.0001);const minimum=G.camera.zoom;G.render(0);const cache=G.environment.stats();G.changeZoom(100);const maximum=G.camera.zoom;G.camera.zoom=1.12;G.centerCamera();return {minimum,maximum,cache};})()`);
  assert.equal(stats.minimum,.35);assert.equal(stats.maximum,2.1);assert(stats.cache.bytes<=stats.cache.maxBytes);
  console.log('✓ Minimap reaches all four corners and far settlements; camera bounds and expanded zoom range at '+width+'px.',stats.cache);
  await ev('G.ui.showHelp()');assert(await ev('document.querySelector("#modal-content").textContent.includes("Destroy all 8 lairs")'));await ev('G.ui.closeModal();G.stats.lairs=8;G.ui.showEnd("victory")');assert(await ev('document.querySelector(".end-stats").textContent.includes("8 / 8")'));
}
await send('Emulation.setDeviceMetricsOverride',{width:2240,height:1440,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:url+'?auto=1&zoom=.35'});await ready();
await ev('(()=>{G.paused=true;G.selected=null;G.vision.push({x:44,y:44,r:150,until:100});G.updateVision();G.time=1;const p=G.iso(44,44);G.camera.x=p.x;G.camera.y=p.y;G.ui.update(true);G.render(0);})()');await shot('overview');
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
await ev('(()=>{G.camera.zoom=1.12;const p=G.iso(60,59);G.camera.x=p.x;G.camera.y=p.y;G.render(0);})()');await shot('lake');
const render=await ev('(()=>{const timings=[];for(let i=0;i<8;i++){const start=performance.now();G.render(0);timings.push(performance.now()-start);}return {meanMs:timings.reduce((a,b)=>a+b)/timings.length,cache:G.environment.stats()};})()');
assert(render.cache.bytes<=render.cache.maxBytes);console.log('Cached landscape render:',render);
assert.equal(errors.length,0,JSON.stringify(errors));
await send('Page.navigate',{url});ws.close();
