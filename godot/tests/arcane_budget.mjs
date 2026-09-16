import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,send,load,state,command,ev,delay} from './cdp.mjs';
try {
  await send('Runtime.enable');await send('Page.enable');await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled',{enabled:true});
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});
  await load('?test=1&auto=1&seed=41972');
  await command('arcane_gallery');await command('arcane_action',{kind:'crowd'});
  await delay(3000);
  const sample=await ev(`new Promise(resolve=>{const frames=[];let previous=performance.now(),start=previous;function frame(now){frames.push(now-previous);previous=now;if(now-start<5000)requestAnimationFrame(frame);else{const sorted=[...frames].sort((a,b)=>a-b);resolve({frames:frames.length,average_fps:frames.length*1000/(now-start),frame_p95_ms:sorted[Math.floor(sorted.length*.95)]});}}requestAnimationFrame(frame);})`);
  const s=await state();
  console.log('Saturation measurement',sample,'visible effects',s.arcane_count,'errors',errors);
  assert.equal(s.arcane_count,104);assert(sample.average_fps>=30,'Synthetic effect saturation stays interactive');assert.deepEqual(errors,[]);
  const result={...sample,effects_in_simulation:s.effects.length,rendered_effects:s.arcane_count,viewport:s.viewport,note:'Synthetic saturation: 24 overlapping spells and 80 impacts, paused to sustain maximum density for the measurement; desktop Chrome, 3s warmup and 5s sample.',errors};
  await fs.writeFile(path.join(reports,'arcane-budget.json'),JSON.stringify(result,null,2)+'\n');console.log(result);
} finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
