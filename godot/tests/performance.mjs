import fs from 'node:fs/promises';
import {send,load,command,state,ev,delay,errors,messages,ws,cdp,page} from './cdp.mjs';
try{
 await send('Runtime.enable');await send('Page.enable');await send('Page.bringToFront');await send('Emulation.setFocusEmulationEnabled',{enabled:true});
 await send('Emulation.setDeviceMetricsOverride',{width:1440,height:900,deviceScaleFactor:1,mobile:false});await load('?test=1&auto=1&seed=41972');
 console.log('canvas',await ev('({width:document.querySelector("canvas").width,height:document.querySelector("canvas").height,dpr:devicePixelRatio})'));
 await command('benchmark',{count:Number(process.argv[2]||process.env.GODOT_BENCH_COUNT||100),seconds:5});
 for(let i=0;i<300;i++){const r=await ev('window.sovereignBenchmark?JSON.parse(window.sovereignBenchmark):null');if(r){console.log(r);break;}await delay(200);}
 console.log('errors',errors,messages.slice(-3));
}finally{ws.close();await fetch(`${cdp}/json/close/${page.id}`);}
