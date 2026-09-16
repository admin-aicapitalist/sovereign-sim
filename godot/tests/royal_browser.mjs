import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,send,load,state,click,command,shot,delay} from './cdp.mjs';
const checks=[];
const key=async name=>click((await state()).widgets[name].point);
function inside(widget,width,height,name){
  assert(widget,`${name} exists`);
  const [x,y,w,h]=widget.rect;
  assert(x>=0&&y>=0&&x+w<=width+1&&y+h<=height+1,`${name} fits ${width}×${height}: ${widget.rect}`);
}
try {
  await send('Runtime.enable'); await send('Page.enable');
  for(const [width,height,dpr] of [[1440,900,1],[390,844,2],[768,1024,1]]) {
    await send('Emulation.setDeviceMetricsOverride',{width,height,deviceScaleFactor:dpr,mobile:width<900});
    await load();
    let s=await state(); assert.deepEqual(s.viewport,[width,height]);
    for(const name of ['mission_ember_crown','mission_classic','seed_input','start','load_welcome','random_map']) inside(s.widgets[name],width,height,name);
    assert(!s.widgets.pause,'Game HUD is hidden behind the title screen');
    await key('mission_classic'); assert.equal((await state()).mission.id,'classic');
    await key('mission_ember_crown'); assert.equal((await state()).mission.id,'ember_crown');
    await shot(width===1440?'royal-welcome':width===390?'royal-mobile-welcome':'royal-tablet-welcome');
    await key('start'); await command('laboratory'); await command('step',{seconds:6}); await command('center');
    s=await state(); assert.deepEqual(s.viewport,[width,height]); assert(s.started);
    for(const name of ['pause','help','map','tab_build','tab_spells']) inside(s.widgets[name],width,height,name);
    if(width===1440) for(const type of ['warriors','rangers','wizards','marketplace','temple','tower','house','thieves']) inside(s.widgets['command_'+type],width,height,type);
    await shot(width===1440?'royal-kingdom':width===390?'royal-mobile':'royal-tablet');
    await key('tab_spells'); assert(s.started); await shot(width===1440?'royal-spell-cards':'royal-spells-'+width);
    checks.push(`Title, campaign selection, HUD and cards at ${width}×${height}, DPR ${dpr}`);
  }
  // A resize without reloading caught an expanding mobile layout viewport in the shell.
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false}); await delay(700);
  await key('new'); await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true}); await delay(700);
  let s=await state(); assert.deepEqual(s.viewport,[390,844]); inside(s.widgets.start,390,844,'Resized start');
  checks.push('Live desktop-to-phone resize preserves the CSS viewport and menu controls');
  assert.deepEqual(errors,[]);
  await fs.writeFile(path.join(reports,'royal-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
  console.log(checks.join('\n'));
} catch(error) { await shot('royal-failure'); console.error(errors); throw error; }
finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
