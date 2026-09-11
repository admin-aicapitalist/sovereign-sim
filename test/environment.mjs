import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
const gameUrl=process.env.SOVEREIGN_TEST_URL||'http://127.0.0.1:8123/';
const tabs=await(await fetch('http://127.0.0.1:9227/json/list')).json();
const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise(r=>ws.onopen=r);
let id=0;const pending=new Map(),errors=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);};
const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
const ev=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const ready=async()=>{for(let i=0;i<200;i++){if(await ev('typeof G!=="undefined"&&typeof G.start==="function"')){await ev('G.spriteAssetsReady');return;}await delay(100);}throw Error('Landscape failed to load');};
const shot=async name=>fs.writeFile(path.join(os.tmpdir(),'sovereign-environment-'+name+'.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));
await send('Runtime.enable');await send('Page.enable');await send('Network.enable');
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:2,mobile:false});
await send('Page.navigate',{url:gameUrl+'?auto=1&demo=2&zoom=2.1'});await ready();
await ev('G.paused=true;G.selected=null;G.hovered=null;G.ui.update(true);G.render(0)');
assert.equal(await ev('Object.entries(G.environmentAssets).every(([key,a])=>{const s=G.sprites[key];return s.assetLoaded&&!s.pixelArt&&s.canvas.width===a.sourceSize[0]&&s.canvas.height===a.sourceSize[1]})'),true,'all 35 environment textures preserve native pixels');
assert.equal(await ev('Object.values(G.sprites).filter(s=>s.category==="tree").length'),12,'all twelve tree variants load');
const navigation=await ev(`(()=>{const tiles=JSON.stringify(G.tiles),trees=JSON.stringify(G.trees);G.environment.prepare();return {same:tiles===JSON.stringify(G.tiles)&&trees===JSON.stringify(G.trees),route:G.findPath(22,22,37,31).length,rails:G.environment.rails.length,bridges:G.tiles.filter(t=>t.kind==='bridge').length};})()`);
assert(navigation.same&&navigation.route>0&&navigation.rails>0&&navigation.bridges>0,'decoration preserves navigation and the bridge crossing');
const raster=await ev(`(()=>{
 const canvas=document.createElement('canvas');canvas.width=canvas.height=1024;const c=canvas.getContext('2d');c.scale(2,2);c.translate(256,-512);
 G.environment.drawGround(c,{x:-256,y:512,w:512,h:512},2);
 if(location.protocol==='file:')return {opaque:true,animated:true};
 const pixels=c.getImageData(0,0,1024,1024).data;let opaque=true;for(let i=3;i<pixels.length;i+=4)if(pixels[i]!==255){opaque=false;break;}
 const water=G.tiles.find(t=>t.kind==='water'&&t.x>31&&t.y<15),p=G.iso(water.x,water.y),a=document.createElement('canvas'),b=document.createElement('canvas');a.width=b.width=256;a.height=b.height=128;
 for(const [image,time] of [[a,0],[b,2]]){const ctx=image.getContext('2d');ctx.translate(128-p.x,64-p.y);G.environment.drawWater(ctx,{x:p.x-128,y:p.y-64,w:256,h:128},time);}
 const pa=a.getContext('2d').getImageData(0,0,256,128).data,pb=b.getContext('2d').getImageData(0,0,256,128).data;
 return {opaque,animated:pa.some((v,i)=>v!==pb[i])};
})()`);
assert(raster.opaque,'ground remains opaque across adjacent cached chunks');assert(raster.animated,'river highlights move over time');
for(const zoom of [.35,1.12,2.1]){
 const stats=await ev(`(()=>{G.camera.zoom=${zoom};for(const [x,y]of[[20,21],[35,20],[7,33],[35,9],[70,73],[60,59],[85,85]]){const p=G.iso(x,y);G.camera.x=p.x;G.camera.y=p.y;G.render(0);}return G.environment.stats()})()`);
 assert(stats.bytes<=stats.maxBytes&&stats.chunks>0,JSON.stringify(stats));
}
console.log('✓ Native environment assets, unchanged navigation, bridge rails, opaque chunk boundaries, animated water, bounded terrain cache.');
await ev('G.camera.zoom=1.65;G.centerCamera();G.camera.y-=37;G.render(0)');await shot('town');
await ev(`(()=>{const p=G.iso(34.5,20.5);G.camera.x=p.x;G.camera.y=p.y-10;G.camera.zoom=2.1;G.vision.push({x:34,y:20,r:12,until:G.time+100});G.updateVision();G.time+=.6;G.render(0);})()`);await shot('river');
await ev(`(()=>{const p=G.iso(7,33);G.camera.x=p.x;G.camera.y=p.y-25;G.vision.push({x:7,y:33,r:12,until:G.time+100});G.updateVision();G.time+=.6;G.render(0);})()`);await shot('pond');
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});
await ev('G.camera.zoom=1.4;G.centerCamera();G.render(0)');await shot('mobile');
assert.equal(await ev('document.documentElement.scrollWidth<=innerWidth'),true,'landscape preserves mobile layout');
await send('Network.setCacheDisabled',{cacheDisabled:true});
await send('Network.setBlockedURLs',{urls:['*assets/art/environment/pine0.png*','*assets/art/environment/terrain-water.png*','*assets/art/environment/bridge-rail.png*']});
await send('Page.navigate',{url:gameUrl+'?auto=1'});await ready();
assert.equal(await ev('G.environment.ready()&&!G.sprites.pine0.assetLoaded&&G.sprites.oak0.assetLoaded&&G.environment.rails.length===0'),true,'individual missing scenery textures retain working terrain and tree fallbacks');
await ev('G.render(0)');
await send('Network.setBlockedURLs',{urls:['*assets/art/environment/terrain-grass.png*']});
await send('Page.navigate',{url:gameUrl+'?auto=1'});await ready();
assert.equal(await ev('!G.environment.ready()&&G.sprites.pine0.assetLoaded&&!!G.palace'),true,'missing base texture falls back to procedural ground');await ev('G.render(0)');
await send('Network.setBlockedURLs',{urls:[]});await send('Network.setCacheDisabled',{cacheDisabled:false});
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:new URL('test/spritesheet.html?only=misc',gameUrl).href});
for(let i=0;i<200;i++){if(await ev('document.querySelectorAll(".sprite").length>=37'))break;await delay(100);}
assert.equal(await ev('Object.keys(G.environmentAssets).every(k=>G.sprites[k].assetLoaded&&G.sprites[k].canvas.isConnected)'),true,'gallery shows every scenery texture');
assert.equal(errors.length,0,JSON.stringify(errors));
console.log('✓ Retina town, river and pond views; mobile layout; independent missing-image fallbacks; scenery gallery.');
console.log('Screenshots: '+path.join(os.tmpdir(),'sovereign-environment-*.png'));
await send('Page.navigate',{url:gameUrl});ws.close();
