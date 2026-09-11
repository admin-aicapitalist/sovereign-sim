import fs from 'node:fs/promises';
import assert from 'node:assert/strict';
import os from 'node:os';
import path from 'node:path';
const gameUrl=process.env.SOVEREIGN_TEST_URL||new URL('../index.html',import.meta.url).href;
const tabs=await(await fetch('http://127.0.0.1:9227/json/list')).json();
const ws=new WebSocket(tabs.find(t=>t.type==='page').webSocketDebuggerUrl);await new Promise(r=>ws.onopen=r);
let id=0;const pending=new Map(),errors=[];
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}else if(m.method==='Runtime.exceptionThrown')errors.push(m.params.exceptionDetails);};
const send=(method,params={})=>new Promise((resolve,reject)=>{const n=++id;pending.set(n,{resolve,reject});ws.send(JSON.stringify({id:n,method,params}));});
const ev=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true,awaitPromise:true});if(r.exceptionDetails)throw new Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
const delay=ms=>new Promise(r=>setTimeout(r,ms));
const ready=async()=>{for(let i=0;i<150;i++){if(await ev('typeof G!=="undefined" && typeof G.start==="function"'))return;await delay(100);}throw new Error('Game did not finish loading');};
const clickXY=async(x,y)=>{await send('Input.dispatchMouseEvent',{type:'mouseMoved',x,y});await send('Input.dispatchMouseEvent',{type:'mousePressed',x,y,button:'left',clickCount:1});await send('Input.dispatchMouseEvent',{type:'mouseReleased',x,y,button:'left',clickCount:1});await delay(100);};
const click=async selector=>{const p=await ev(`(()=>{const r=document.querySelector(${JSON.stringify(selector)}).getBoundingClientRect();return{x:r.x+r.width/2,y:r.y+r.height/2}})()`);await clickXY(p.x,p.y);};
const key=async(key,code)=>{await send('Input.dispatchKeyEvent',{type:'keyDown',key,code});await send('Input.dispatchKeyEvent',{type:'keyUp',key,code});await delay(100);};
const shot=async name=>fs.writeFile(path.join(os.tmpdir(),'sovereign-'+name+'.png'),Buffer.from((await send('Page.captureScreenshot',{format:'png'})).data,'base64'));
await send('Runtime.enable');await send('Page.enable');
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});
await send('Page.navigate',{url:gameUrl});await ready();
await ev('G.spriteAssetsReady');
await ev('document.fonts.ready.then(()=>true)');
assert.equal(await ev('[...document.fonts].length===3 && [...document.fonts].every(f=>f.status==="loaded")'),true,'bundled heading, body and italic fonts load');
assert.equal(await ev('G.sprites.palace.assetLoaded'),true,'exported Palace loads before play');
assert.deepEqual(await ev('[G.sprites.palace.canvas.width,G.sprites.palace.canvas.height]'),await ev('G.spriteAssets.palace.sourceSize'),'Palace keeps the source texture resolution');
assert.equal(await ev('G.sprites.palace.pixelArt'),false,'Palace uses smooth scaling');
assert.equal(await ev('Object.keys(G.BUILDINGS).every(key=>{const s=G.sprites[key],a=G.spriteAssets[key];return s.assetLoaded&&!s.pixelArt&&s.canvas.width===a.sourceSize[0]&&s.canvas.height===a.sourceSize[1]})'),true,'all eleven buildings retain their full-resolution textures');
console.log('INITIAL',await ev('({sprites:Object.keys(G.sprites).length,buildings:G.buildings.length,units:G.units.length,welcome:G.welcoming,canvas:[document.querySelector("canvas").width,document.querySelector("canvas").height]})'));
await shot('welcome');
await click('#start');await delay(800);assert.equal(await ev('G.welcoming'),false);await key(' ','Space');assert.equal(await ev('G.paused'),true);await shot('game');
const buildingChecks=await ev(`(()=>{
  const saved={buildings:G.buildings,units:G.units,flags:G.flags,zoom:G.camera.zoom,mode:G.mode,pointer:G.pointer.world,selected:G.selected,hovered:G.hovered};
  const ctx=document.getElementById('world').getContext('2d'),drawImage=ctx.drawImage;
  const results=[];
  try{
    G.units=[];G.flags=[];G.selected=null;G.hovered=null;
    for(const type of Object.keys(G.BUILDINGS)){
      const layout=G.buildingSpriteLayout(type),s=layout.sprite,data=G.BUILDINGS[type];
      const b={...G.palace,type,data,hostile:false,x:20.5,y:20.5,progress:1};G.buildings=[b];
      const y=Math.floor(s.h*.6),row=s.hitRows?.[y];
      const u=row?(row[0]+row[1])/2:(s.bounds[0]+s.bounds[2])/2;
      const v=row?y+.5:(s.bounds[1]+s.bounds[3])/2;
      const hits=[.55,1.12,2.1].every(z=>{G.camera.zoom=z;const p=G.worldToScreen(b.x,b.y);return G.hitTest(p.x+(layout.x+u*layout.scale)*z,p.y+(layout.y+v*layout.scale)*z)===b;});
      const clearCorners=!s.hitRows||!G.spriteContainsPoint(s,0,0);
      let last;ctx.drawImage=function(image,...args){if(image===s.canvas)last=args;return drawImage.call(this,image,...args);};
      G.pointer.world={x:12.2,y:12.2};G.mode={type:'build',key:type};G.render(0);const ghost=JSON.stringify(last);
      b.x=12+data.size/2;b.y=12+data.size/2;G.mode=null;last=null;G.render(0);const placed=JSON.stringify(last);
      const portrait=document.createElement('canvas');G.ui.thumbnail(portrait,type);
      let portraitVisible=true;
      if(location.protocol!=='file:'){const pixels=portrait.getContext('2d').getImageData(0,0,180,100).data;portraitVisible=pixels.some((value,i)=>i%4===3&&value>0);}
      results.push({type,hits,clearCorners,aligned:ghost===placed&&placed!=='null',portraitVisible});
      ctx.drawImage=drawImage;
    }
  }finally{ctx.drawImage=drawImage;G.buildings=saved.buildings;G.units=saved.units;G.flags=saved.flags;G.camera.zoom=saved.zoom;G.mode=saved.mode;G.pointer.world=saved.pointer;G.selected=saved.selected;G.hovered=saved.hovered;G.render(0);}
  return results;
})()`);
for(const check of buildingChecks)assert(check.hits&&check.clearCorners&&check.aligned&&check.portraitVisible,JSON.stringify(check));
console.log('✓ All buildings: selection at three zoom levels, transparent corners, matching construction previews, and portraits.');
const unitChecks=await ev(`(()=>{
  const saved={units:G.units,buildings:G.buildings,flags:G.flags,zoom:G.camera.zoom,time:G.time,selected:G.selected,hovered:G.hovered};
  const ctx=document.getElementById('world').getContext('2d'),drawImage=ctx.drawImage,results=[];
  try{
    G.buildings=[];G.flags=[];G.selected=null;G.hovered=null;
    for(const type of Object.keys(G.UNITS)){
      const asset=G.unitAssets[type],idle=G.sprites['idle_'+type];
      const u={...saved.units[0],type,data:G.UNITS[type],hero:false,hostile:false,x:20.5,y:20.5,path:[],attacking:0,anim:0,state:'Idle',facing:1};G.units=[u];
      const frames=[idle,...G.sprites['unit_'+type],...G.sprites['attack_'+type]];
      const native=frames.every(s=>s.assetLoaded&&s.canvas===idle.canvas&&s.canvas.width===asset.sourceSize[0]&&s.canvas.height===asset.sourceSize[1]&&s.frame[2]/s.w===10&&s.frame[3]/s.h===10);
      const stable=frames.every(s=>JSON.stringify(s.anchor)===JSON.stringify(idle.anchor));
      const idleOK=G.unitSpriteLayout(u).sprite.pose==='idle';u.path=[{x:21,y:21}];
      const walkOK=[0,1,2,3].every(i=>{u.anim=i;return G.unitSpriteLayout(u).sprite.pose==='walk-'+i;});u.path=[];
      const attackOK=[.34,.2,.05].every((t,i)=>{u.attacking=t;return G.unitSpriteLayout(u).sprite.pose==='attack-'+i;});u.attacking=0;
      const hits=[.55,1.12,2.1].every(z=>{G.camera.zoom=z;const p=G.worldToScreen(u.x,u.y),s=G.unitSpriteLayout(u);return [-1,1].every(f=>{u.facing=f;return G.hitTest(p.x+s.selection[0]*f*z,p.y+s.selection[1]*z)===u;});});
      const croppedAndMirrored=[-1,1].every(f=>{u.facing=f;u.attacking=.2;let draw;
        ctx.drawImage=function(image,...args){if(image===idle.canvas)draw={args,flip:Math.sign(this.getTransform().a),smooth:this.imageSmoothingEnabled};return drawImage.call(this,image,...args);};
        G.render(0);const layout=G.unitSpriteLayout(u);ctx.drawImage=drawImage;
        return draw?.args.length===8&&JSON.stringify(draw.args.slice(0,4))===JSON.stringify(layout.sprite.frame)&&draw.flip===f&&draw.smooth;
      });u.attacking=0;
      const portrait=document.createElement('canvas');G.ui.thumbnail(portrait,type,true);
      let portraitVisible=true;if(location.protocol!=='file:')portraitVisible=portrait.getContext('2d').getImageData(0,0,180,100).data.some((v,i)=>i%4===3&&v>0);
      let workOK=true;if(type==='peasant'){u.id=0;workOK=['Building Cottage','Repairing Royal Palace'].every(state=>{u.state=state;return [0,1,2].every(i=>{G.time=i/7+.001;return G.unitSpriteLayout(u).sprite.pose==='attack-'+i;});});}
      results.push({type,native,stable,idleOK,walkOK,attackOK,hits,croppedAndMirrored,portraitVisible,workOK});
    }
  }finally{ctx.drawImage=drawImage;Object.assign(G,{units:saved.units,buildings:saved.buildings,flags:saved.flags,time:saved.time,selected:saved.selected,hovered:saved.hovered});G.camera.zoom=saved.zoom;G.render(0);}
  return results;
})()`);
for(const {type,...checks} of unitChecks)assert(Object.values(checks).every(Boolean),JSON.stringify({type,...checks}));
console.log('✓ All ten characters: native atlases, stable anchors, idle/walk/attack and work frames, mirrored drawing, selection at three zooms, portraits.');
const palaceRoof=await ev('(()=>{const p=G.worldToScreen(G.palace.x,G.palace.y);return{x:p.x,y:p.y-80*G.camera.zoom}})()');
await clickXY(palaceRoof.x,palaceRoof.y);assert.equal(await ev('G.selected===G.palace'),true,'Palace roof selects the building');
assert.equal(await ev('document.querySelector(".inspect-title").textContent'),await ev('G.palace.data.name'));
await shot('palace');
assert.equal(await ev(`(()=>{
  const units=G.units,flags=G.flags,zoom=G.camera.zoom;
  try{G.units=[];G.flags=[];
    return [.55,1.12,2.1].every(z=>{G.camera.zoom=z;const p=G.worldToScreen(G.palace.x,G.palace.y);
      return [[90,-40],[0,35],[0,-140]].every(([x,y])=>G.hitTest(p.x+x*z,p.y+y*z)===G.palace);
    });
  }finally{G.units=units;G.flags=flags;G.camera.zoom=zoom;}
})()`),true,'new Palace tower, steps, and roof remain selectable across zoom levels');
console.log('✓ Imported Palace, inspector portrait, and selection at minimum/default/maximum zoom.');
await key('Escape','Escape');
await click('.command-card');assert.equal(await ev('G.mode.key'),'warriors');const site=await ev('G.worldToScreen(16.25,18.25)');await clickXY(site.x,site.y);assert.equal(await ev('G.buildings.filter(b=>b.type==="warriors").length'),1);assert.equal(await ev('G.mode'),null);assert.equal(await ev('Math.floor(G.gold)'),1150);
await ev('G.paused=false;for(let t=0;t<30;t+=.1)G.update(.1);G.paused=true;G.ui.update(true)');assert.equal(await ev('G.buildings.find(b=>b.type==="warriors").progress'),1);
await click('#inspect-recruit');assert.equal(await ev('G.units.filter(u=>u.hero).length'),1);
await click('[data-tab="bounty"]');await click('.command-card:nth-child(2)');const spot=await ev('G.worldToScreen(25.5,23.5)');await clickXY(spot.x,spot.y);assert.equal(await ev('G.flags.filter(f=>!f.dead).length'),1);await click('#raise-bounty');assert.equal(await ev('G.flags[0].reward'),150);await click('#cancel-bounty');assert.equal(await ev('G.flags[0].dead'),true);
await click('[data-tab="spells"]');await click('.command-card:nth-child(3)');await clickXY(spot.x,spot.y);assert(await ev('G.cooldowns.farsight>0'));assert.equal(await ev('G.mode'),null);
await click('[data-speed="3"]');assert.equal(await ev('G.speed'),3);assert.equal(await ev('G.paused'),false);await key(' ','Space');assert.equal(await ev('G.paused'),true);
const zoom=await ev('G.camera.zoom');await click('#zoom-in');assert(await ev(`G.camera.zoom>${zoom}`));await key('f','KeyF');await click('#help');assert.equal(await ev('G.modalOpen'),true);await click('#close-help');assert.equal(await ev('G.modalOpen'),false);
console.log('✓ Real mouse and keyboard: start, pause, build, recruit, bounty placement/raise/refund, magic, speed, zoom, help.');
await send('Page.navigate',{url:gameUrl+'?auto=1&demo=2'});await ready();await ev('G.paused=true;G.ui.update(true)');await shot('town');
await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:1,mobile:true});await send('Page.reload');await ready();await ev('G.paused=true;G.ui.update(true)');await key('f','KeyF');await shot('mobile');assert.equal(await ev('document.documentElement.scrollWidth<=window.innerWidth'),true,'no horizontal viewport overflow');console.log('MOBILE',await ev('({width:innerWidth,height:innerHeight,deck:document.querySelector(".bottom-deck").getBoundingClientRect().toJSON(),inspector:document.querySelector("#inspector").getBoundingClientRect().toJSON()})'));
await click('[data-tab="bounty"]');assert.equal(await ev('document.querySelectorAll(".command-card").length'),2);await click('[data-tab="build"]');await shot('mobile');
await send('Network.enable');await send('Network.setCacheDisabled',{cacheDisabled:true});
await send('Network.setBlockedURLs',{urls:['*assets/art/palace/palace-hires.png*','*assets/art/buildings/house.png*','*assets/art/buildings/wizards.png*','*assets/art/units/peasant.png*','*assets/art/units/troll.png*']});
await send('Page.navigate',{url:gameUrl+'?auto=1'});await ready();await ev('G.spriteAssetsReady');
assert.equal(await ev('!!G.sprites.palace.assetLoaded'),false,'missing Palace image retains procedural fallback');
assert.equal(await ev('!G.sprites.house.assetLoaded && !G.sprites.wizards.assetLoaded && G.sprites.warriors.assetLoaded'),true,'individual building failures retain independent fallbacks');
assert.equal(await ev('!G.sprites.unit_peasant[0].assetLoaded && !G.sprites.attack_peasant.assetLoaded && !G.sprites.idle_peasant && !G.sprites.unit_troll[0].assetLoaded && G.sprites.idle_guard.assetLoaded'),true,'missing unit atlases preserve complete procedural animations independently');
assert.equal(await ev('(()=>{const u=G.units.find(u=>u.type==="peasant");u.state="Building Cottage";u.path=[];return !G.unitSpriteLayout(u).sprite.assetLoaded})()'),true,'work animation also supports the procedural fallback');
assert.equal(await ev('!!G.palace && typeof G.start === "function"'),true,'game still starts with a missing image');
await send('Network.setBlockedURLs',{urls:[]});await send('Network.setCacheDisabled',{cacheDisabled:false});
await send('Page.navigate',{url:gameUrl+'?auto=1'});await ready();await ev('G.spriteAssetsReady');
assert.equal(await ev('G.sprites.palace.assetLoaded'),true,'Palace loads again when the image becomes available');
assert.equal(await ev('G.sprites.house.assetLoaded && G.sprites.wizards.assetLoaded'),true,'other building images recover on reload');
assert.equal(await ev('G.sprites.idle_peasant.assetLoaded && G.sprites.idle_troll.assetLoaded'),true,'character atlases recover on reload');
console.log('✓ Independent missing-image fallbacks start the game and a normal reload restores the buildings.');
// The authoring gallery is available locally; it is excluded from deployment.
if(new URL(gameUrl).protocol==='file:'||['localhost','127.0.0.1'].includes(new URL(gameUrl).hostname)){
  await send('Page.navigate',{url:new URL('test/spritesheet.html?only=bld',gameUrl).href});await delay(1500);
  assert.equal(await ev('Object.keys(G.BUILDINGS).every(key=>G.sprites[key].assetLoaded && G.sprites[key].canvas.isConnected)'),true,'gallery displays every imported building');
  assert.equal(await ev('document.querySelectorAll(".sprite").length'),await ev('Object.keys(G.BUILDINGS).length'));
  console.log('✓ Sprite gallery loads every building using the game manifests.');
  await send('Page.navigate',{url:new URL('test/spritesheet.html?only=units',gameUrl).href});
  for(let i=0;i<100;i++){if(await ev('document.querySelectorAll(".sprite").length===80'))break;await delay(100);}
  assert.equal(await ev('document.querySelectorAll(".sprite").length'),80,'gallery shows every character pose, without moving shared atlas canvases between cards');
  assert.equal(await ev('[...document.querySelectorAll(".sprite canvas")].every(c=>c.width>0&&c.height>0&&c.width<1000&&c.height<1000)'),true,'gallery crops individual frames');
  console.log('✓ Character gallery displays all 80 high-resolution poses.');
}
assert.equal(errors.length,0,JSON.stringify(errors));console.log('✓ Desktop and mobile render with no JavaScript errors at '+gameUrl);
await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await ws.close();
