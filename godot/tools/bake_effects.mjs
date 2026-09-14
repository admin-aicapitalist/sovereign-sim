// Bake the original Canvas spell artwork into transparent atlases for native Godot drawing.
import fs from 'node:fs/promises';
import {fileURLToPath} from 'node:url';
const root=fileURLToPath(new URL('../../',import.meta.url));
const source=process.argv.includes('--current-source')?root+'js/':fileURLToPath(new URL('./reference/',import.meta.url));
const endpoint=process.env.GODOT_CDP_URL||'http://127.0.0.1:9231';
const page=await(await fetch(endpoint+'/json/new?about:blank',{method:'PUT'})).json();
const ws=new WebSocket(page.webSocketDebuggerUrl); await new Promise(r=>ws.onopen=r);
let serial=0;const pending=new Map();
ws.onmessage=e=>{const m=JSON.parse(e.data);if(m.id){const p=pending.get(m.id);pending.delete(m.id);m.error?p.reject(m.error):p.resolve(m.result);}};
const send=(method,params={})=>new Promise((resolve,reject)=>{const id=++serial;pending.set(id,{resolve,reject});ws.send(JSON.stringify({id,method,params}));});
const ev=async expression=>{const r=await send('Runtime.evaluate',{expression,returnByValue:true});if(r.exceptionDetails)throw Error(JSON.stringify(r.exceptionDetails));return r.result.value;};
try{
  for(const name of ['util','data','sprites','magic-art'])await ev(await fs.readFile(source+name+'.js','utf8'));
  const keys=await ev('Object.keys(G.SPELLS)');
  await fs.mkdir(root+'godot/assets/effects',{recursive:true});
  for(const key of keys){
    const png=await ev(`(()=>{const c=document.createElement('canvas');c.width=1536;c.height=1920;const ctx=c.getContext('2d');
      for(let i=0;i<16;i++){ctx.save();ctx.beginPath();ctx.rect(i%4*384,Math.floor(i/4)*480,384,480);ctx.clip();
        ctx.translate(i%4*384+192,Math.floor(i/4)*480+360);ctx.scale(.75,.75);
        const d=G.SPELLS[${JSON.stringify(key)}];G.magicArt.effect(ctx,{spell:${JSON.stringify(key)},x:0,y:0,seed:.371,life:d.visualDuration},d.visualDuration*(i+.2)/16);ctx.restore();}
      return c.toDataURL('image/png').split(',')[1];})()`);
    await fs.writeFile(root+'godot/assets/effects/'+key+'.png',Buffer.from(png,'base64'));
  }
  for(const key of ['ward','haste','frost']){
    const png=await ev(`(()=>{const c=document.createElement('canvas');c.width=384;c.height=432;const ctx=c.getContext('2d');
      for(let i=0;i<12;i++){ctx.save();ctx.translate(i%4*96+48,Math.floor(i/4)*144+105);ctx.scale(1.5,1.5);G.time=i/6;
        G.magicArt.aura(ctx,{magicBuffs:{ward:0,haste:0,frost:0,[${JSON.stringify(key)}]:10}},{x:0,y:0});ctx.restore();}return c.toDataURL('image/png').split(',')[1];})()`);
    await fs.writeFile(root+'godot/assets/effects/aura_'+key+'.png',Buffer.from(png,'base64'));
  }
  await ev('G.makeSprites()');
  for(const key of ['loot_chest','loot_pouch']){
    const result=await ev(`(()=>{const s=G.sprites[${JSON.stringify(key)}];return s?{png:s.canvas.toDataURL('image/png').split(',')[1],w:s.w,h:s.h}:null})()`);
    if(result){await fs.writeFile(root+'godot/assets/effects/'+key+'.png',Buffer.from(result.png,'base64'));console.log(key,result.w,result.h);}
  }
  console.log('Baked seven spell animations and three status auras from the original artwork.');
}finally{ws.close();await fetch(endpoint+'/json/close/'+page.id);}
