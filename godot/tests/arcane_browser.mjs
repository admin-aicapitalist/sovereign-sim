import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,send,load,state,click,command,shot,delay,ev} from './cdp.mjs';

const checks=[];
const pass=s=>{checks.push(s);console.log(s);};
try {
  await send('Runtime.enable'); await send('Page.enable'); await send('Page.bringToFront');
  await send('Emulation.setFocusEmulationEnabled',{enabled:true});
  await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});
  await load('?test=1&auto=1&seed=41972');
  let s=await state();
  if(!s.sound) await click(s.widgets.sound.point);
  for(const [spell,age] of [['heal',.35],['ward',.35],['haste',.3],['lightning',.1],['frost',.3],['farsight',.45],['meteor',.35]]) {
    await command('arcane_gallery',{spell});
    s=await state();
    assert.equal(s.stats.wizard_spells,1,spell+' is a real wizard cast');
    assert(s.effects.some(e=>e.type==='spell_'+spell));
    const before=s.units.filter(u=>u.hostile).map(u=>u.hp);
    await command('step',{seconds:age}); s=await state();
    assert(s.arcane_count>0);
    assert.equal(s.wizard_visuals[0].visual.key,'unit_wizard_cast');
    await shot('arcane-'+spell);
    const frozen=spell==='meteor' ? await send('Page.captureScreenshot',{format:'png',clip:{x:300,y:135,width:900,height:520,scale:1}}) : null;
    const time=s.time, clock=s.presentation_time;
    await delay(450); s=await state(); assert.equal(s.time,time); assert.equal(s.presentation_time,clock);
    if(spell==='meteor') {
      const still=await send('Page.captureScreenshot',{format:'png',clip:{x:300,y:135,width:900,height:520,scale:1}});
      assert.equal(still.data,frozen.data,'Particles, geometry and fire-shader pixels stay identical while paused');
      assert(s.units.filter(u=>u.hostile).every((u,i)=>u.hp>=before[i]),'Warning does not damage early; troll regeneration may continue');
      assert(!s.effects.some(e=>e.type==='meteor_impact'));
      await command('save'); await command('load');
      assert.equal((await state()).magic.impacts.length,1);
      assert.deepEqual((await state()).wizard_visuals[0].visual,s.wizard_visuals[0].visual,'Casting sockets and direction survive save/load');
      await command('camera',{x:s.camera[0]/64+s.camera[1]/32,y:s.camera[1]/32-s.camera[0]/64});
      await command('step',{seconds:.35}); s=await state();
      assert(s.effects.some(e=>e.type==='meteor_impact'));
      assert(!s.effects.some(e=>e.type==='spell_meteor'));
      assert(s.units.filter(u=>u.hostile).every((u,i)=>u.hp<before[i]));
      assert(Math.hypot(...s.camera_impulse)>0 && Math.hypot(...s.camera_impulse)<=4.01);
      await shot('arcane-meteor-impact');
      await command('step',{seconds:.45}); await shot('arcane-meteor-afterglow');
      pass('Meteor warning survives save/load, impacts on the damage tick, and produces a bounded camera impulse');
    }
    pass(spell+' renders with dedicated casting poses and freezes when paused');
  }
  await command('arcane_gallery',{spell:'ward'}); await command('arcane_action',{kind:'shield'});
  await command('step',{seconds:.05}); s=await state();
  assert(s.effects.some(e=>e.type==='hit'&&e.warded)); await shot('arcane-shield-impact');
  await command('arcane_action',{kind:'melee'}); await command('step',{seconds:.05});
  assert((await state()).effects.some(e=>e.type==='swing')); await shot('arcane-melee');
  for(const kind of ['fireball','arrow']) {
    await command('arcane_gallery'); await command('arcane_action',{kind});
    await command('step',{seconds:.15}); s=await state(); assert(s.projectiles.length>0);
    await shot('arcane-'+kind);
    await command('step',{seconds:1}); s=await state(); assert.equal(s.projectiles.length,0);
  }
  pass('Reactive wards, melee arcs, fireball trails and arrows follow actual combat events');
  await command('arcane_gallery'); await command('arcane_action',{kind:'windup'});
  const pose=(await state()).wizard_visuals[0].visual.frame;
  await command('step',{seconds:.4}); assert((await state()).wizard_visuals[0].visual.frame>pose);
  await shot('arcane-wizard-charge');
  await command('step',{seconds:.45}); assert((await state()).projectiles.length>0);
  pass('Wizard staff charging advances into the real projectile release');
  await command('arcane_gallery'); await command('arcane_action',{kind:'crowd'});
  s=await state(); assert(s.effects.length>104); assert(s.arcane_count<=104);
  pass('Visible effects respect the 24-spell / 80-impact rendering budget');
  await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});
  await command('arcane_gallery',{spell:'frost'}); await command('step',{seconds:.25});
  s=await state(); const foe=s.units.find(u=>u.type==='goblin'); await command('camera',{x:foe.pos[0],y:foe.pos[1]});
  await shot('arcane-mobile'); assert.deepEqual((await state()).viewport,[390,844]);
  assert.deepEqual(errors,[]); pass('Phone DPR2 rendering and all spell/combat paths finish without browser or Godot errors');
  await fs.writeFile(path.join(reports,'arcane-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
} catch(error) {await shot('arcane-failure').catch(()=>{});console.error(errors);throw error;}
finally {ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
