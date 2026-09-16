import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,send,load,state,click,command,shot,delay} from './cdp.mjs';

const checks=[];
try {
  await send('Runtime.enable'); await send('Page.enable');
  await send('Page.bringToFront'); await send('Emulation.setFocusEmulationEnabled',{enabled:true});
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});
  await load('?test=1&auto=1&seed=41972');
  await command('character_gallery');
  let s=await state();
  assert.equal(s.character_visuals.length,12);
  assert.equal(new Set(s.character_visuals.map(u=>u.key)).size,12);
  assert.equal(s.rendered_units,12);
  await shot('characters-in-game');
  const actors=s.units.map(u=>u.id);
  for(const direction of [0,1,2,3,4,5,6,7]) {
    await command('character_pose',{pose:'walk',frame:direction,direction});
    s=await state();
    for(const u of s.character_visuals) {
      assert.equal(u.direction,direction);
      assert.equal(u.pose,`walk-${direction}`);
    }
    if(direction===4) await shot('characters-rear-views');
  }
  checks.push('All 12 types render eight directions and eight walk poses in the game');
  await command('character_pose',{pose:'windup',frame:2,direction:0});
  assert((await state()).character_visuals.every(u=>u.pose==='attack-2'));
  await shot('characters-windup');
  await command('character_pose',{pose:'attack',frame:0,direction:0});
  assert((await state()).character_visuals.every(u=>u.pose==='attack-3'));
  await shot('characters-impact');
  await command('character_pose',{pose:'work',time:2.1,direction:7});
  assert((await state()).character_visuals.every(u=>u.pose.startsWith('attack-')));
  checks.push('Wind-up, release and worker tool use sample the intended animation states');
  await command('character_pose',{pose:'idle',time:0,direction:0});
  for(const id of actors) {
    s=await state();
    const point=s.entities_on_screen.find(e=>e.id===id).point;
    await click(point);
    assert.equal((await state()).selection,id,`Picking remains aligned with character ${id}`);
    await click((await state()).widgets.close_selection.point);
  }
  checks.push('All 12 cropped character sprites remain selectable at their world positions');
  await command('select',{id:actors[0]}); await shot('characters-inspector');
  await command('save'); await command('load');
  assert.equal((await state()).units.length,12);
  checks.push('Save/load retains the character roster');
  await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});
  await command('laboratory',{mission:'ember_crown'}); await command('step',{seconds:6}); await command('center');
  await shot('characters-mobile');
  s=await state(); assert.deepEqual(s.viewport,[390,844]); assert(s.rendered_units>0);
  assert.deepEqual(errors,[]);
  checks.push('The updated units render on the 390px DPR2 phone viewport without engine errors');
  await fs.writeFile(path.join(reports,'characters-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
  console.log(checks.join('\n'));
} catch(error) { await shot('characters-failure'); console.error(errors); throw error; }
finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
