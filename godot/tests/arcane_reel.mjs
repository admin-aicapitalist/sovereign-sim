// Capture simulation-sampled frames from the real renderer for an animation reel.
import fs from 'node:fs/promises';
import path from 'node:path';
import assert from 'node:assert/strict';
import {cdp,page,ws,errors,send,load,command,ev,delay} from './cdp.mjs';
const out='/tmp/sovereign-arcane-reel'; await fs.mkdir(out,{recursive:true});
const shots=[];
try {
  await send('Runtime.enable'); await send('Page.enable'); await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled',{enabled:true});
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});
  await load('?test=1&auto=1&seed=41972');
  for(const [spell,seconds] of [['heal',1.8],['lightning',1.2],['frost',2],['meteor',2.7],['ward',1.8],['farsight',2.4]]) {
    await command('arcane_gallery',{spell});
    for(let frame=0;frame<Math.round(seconds*20);frame++) {
      const file=`${spell}-${String(frame).padStart(3,'0')}.png`;
      const r=await send('Page.captureScreenshot',{format:'png',clip:{x:285,y:110,width:990,height:560,scale:1}});
      await fs.writeFile(path.join(out,file),Buffer.from(r.data,'base64'));
      shots.push({file,spell,frame});
      await ev(`window.sovereignCommand(${JSON.stringify(JSON.stringify({action:'step',seconds:.05}))})`);
      await delay(45);
    }
    console.log('Captured',spell);
  }
  assert.deepEqual(errors,[]); await fs.writeFile(path.join(out,'frames.json'),JSON.stringify(shots));
} finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
