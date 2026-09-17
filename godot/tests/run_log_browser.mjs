import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import {reports,cdp,page,ws,errors,messages,send,load,state,click,command,ev,shot,delay} from './cdp.mjs';
const checks=[];const pass=name=>{checks.push(name);console.log('PASS:',name);};
const downloadDir=await fs.mkdtemp('/tmp/sovereign-run-log-downloads-');
async function key(name){
 for(let i=0;i<35;i++){
  const s=await state(),w=s.widgets[name];assert(w,`${name} exists`);assert(!w.disabled,`${name} enabled`);
  const [x,y]=w.point,b=w.clip_rect||s.modal_rect;
  if(!s.modal||(y>b[1]+8&&y<b[1]+b[3]-8)){await click([x,y]);return;}
  await send('Input.dispatchMouseEvent',{type:'mouseMoved',x:b[0]+b[2]/2,y:b[1]+b[3]/2});
  await send('Input.dispatchMouseEvent',{type:'mouseWheel',x:b[0]+b[2]/2,y:b[1]+b[3]/2,deltaX:0,deltaY:y<b[1]?-280:280});await delay(450);
 }
 throw Error(`Could not reach ${name}`);
}
async function settled(){
 for(let i=0;i<50;i++){const s=await ev('window.sovereignRunLogs.status()');if(!s.pending&&!s.error)return s;await delay(200);}
 throw Error('Log did not persist: '+JSON.stringify(await ev('window.sovereignRunLogs.status()')));
}
async function download(id){
 await key('export_log_'+id);
 const name=path.join(downloadDir,'sovereign-run-'+id+'.json');
 for(let i=0;i<50;i++){try{return JSON.parse(await fs.readFile(name,'utf8'));}catch{}await delay(200);}
 throw Error('Export file missing');
}
try{
 await send('Runtime.enable');await send('Page.enable');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Browser.setDownloadBehavior',{behavior:'allow',downloadPath:downloadDir});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:1000,deviceScaleFactor:1,mobile:false});await load();
 await command('journey_fixture');await command('step',{seconds:3});await settled();let s=await state();const id=s.run.config.id;
 await key('save');await key('run_logs');assert.equal((await state()).modal,'run_logs');
 let output=await download(id);assert(output.events.some(e=>e.event==='actor.decision'));assert(output.events.some(e=>e.event==='player.action'&&e.data.key==='save'));
 assert(output.events[0].data.checkpoint.run.config.id===id);const initial=output.events.length;
 pass('Actual UI exports a JSON file containing checkpoints, choices and player actions');
 await load();await key('saved_run_logs');await delay(1200);assert((await state()).widgets['export_log_'+id]);await key('close_run_logs');await delay(650);await key('load_welcome');await delay(650);assert((await state()).started,JSON.stringify({message:(await state()).storage_message,text:(await state()).modal_text}));await key('pause');await settled();
 await key('run_logs');await fs.unlink(path.join(downloadDir,'sovereign-run-'+id+'.json'));output=await download(id);
 assert(output.events.length>initial);assert(output.events.some(e=>e.event==='run.resumed'));
 assert(new Set(output.events.map(e=>e.segment+':'+e.seq)).size===output.events.length);
 pass('Browser reload retains history and resuming appends a new segment without duplicates');
 // Fail writes only in the isolated test database; existing chunks remain readable for export.
 await ev(`window.realRunLogTransaction=IDBDatabase.prototype.transaction; IDBDatabase.prototype.transaction=function(stores,mode,...args){if(this.name==='sovereign-run-logs-test-v1'&&mode==='readwrite')throw Error('Injected log storage failure');return window.realRunLogTransaction.call(this,stores,mode,...args);}`);
 await key('close_run_logs');await command('step',{seconds:2});await delay(1300);await key('run_logs');await delay(1100);
 s=await state();assert(s.modal_text.includes('Injected log storage failure'));assert((await ev('window.sovereignRunLogs.status()')).pending>0);
 await fs.unlink(path.join(downloadDir,'sovereign-run-'+id+'.json'));const failedOutput=await download(id);
 assert(failedOutput.events.length>output.events.length);assert(failedOutput.events.some(e=>e.event==='test.command'&&e.data.seconds===2));
 await ev('IDBDatabase.prototype.transaction=window.realRunLogTransaction');await key('retry_run_logs');await settled();
 pass('Storage failures are visible; export includes unsaved events and retry drains them');
 await send('Emulation.setDeviceMetricsOverride',{width:390,height:844,deviceScaleFactor:2,mobile:true});await delay(700);s=await state();
 assert(s.modal_rect[0]>=0&&s.modal_rect[0]+s.modal_rect[2]<=390);
 for(const name of ['retry_run_logs','close_run_logs']){const r=s.widgets[name].rect;assert(r[0]>=0&&r[0]+r[2]<=390&&r[1]>=0&&r[1]+r[3]<=844);}
 await shot('run-log-mobile');await key('close_run_logs');await key('new');await key('abandon');await delay(500);await key('saved_run_logs');await settled();
 await fs.unlink(path.join(downloadDir,'sovereign-run-'+id+'.json'));output=await download(id);assert.equal(output.run.outcome,'abandoned');assert.equal(output.events.filter(e=>e.event==='run.ended').length,1);
 await key('close_run_logs');await key('fresh');await key('start');await delay(800);await key('run_logs');await settled();s=await state();
 assert.notEqual(s.run.config.id,id);assert(s.widgets['export_log_'+id]);assert(s.widgets['export_log_'+s.run.config.id]);
 pass('Phone controls fit; completed and new runs both remain available for export');
 assert.deepEqual(errors,[]);await fs.writeFile(path.join(reports,'run-log-browser.json'),JSON.stringify({checks,errors},null,2)+'\n');
}catch(error){await shot('run-log-failure').catch(()=>{});console.error(JSON.stringify({errors,messages:messages.slice(-12),state:await state().then(s=>({modal:s.modal,text:s.modal_text,storage:s.storage_message,run_log:s.run_log})).catch(()=>null)},null,2));throw error;}
finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
