(function(){
  let ac=null,bus=null,musicTimer=null,chord=0,last={};
  G.sound={enabled:false,
    init(){if(ac){if(ac.state==='suspended')ac.resume().catch(()=>{});return;}try{ac=new(window.AudioContext||window.webkitAudioContext)();bus=ac.createGain();bus.gain.value=.24;bus.connect(ac.destination);}catch(e){this.enabled=false;}},
    toggle(){this.enabled=!this.enabled;if(this.enabled){this.init();this.play('select');this.ambience();if(!musicTimer)musicTimer=setInterval(()=>this.ambience(),8000);}else if(ac)ac.suspend().catch(()=>{});},
    tone(freq,time,duration,type='sine',volume=.2,endFreq){if(!ac||!this.enabled)return;const osc=ac.createOscillator(),gain=ac.createGain();osc.type=type;osc.frequency.setValueAtTime(freq,time);if(endFreq)osc.frequency.exponentialRampToValueAtTime(endFreq,time+duration);gain.gain.setValueAtTime(.001,time);gain.gain.exponentialRampToValueAtTime(volume,time+.025);gain.gain.exponentialRampToValueAtTime(.001,time+duration);osc.connect(gain);gain.connect(bus);osc.start(time);osc.stop(time+duration+.04);},
    noise(duration=.1,volume=.1,frequency=700){if(!ac||!this.enabled)return;const size=Math.floor(ac.sampleRate*duration),buffer=ac.createBuffer(1,size,ac.sampleRate),data=buffer.getChannelData(0);for(let i=0;i<size;i++)data[i]=(Math.random()*2-1)*(1-i/size);const src=ac.createBufferSource(),filter=ac.createBiquadFilter(),gain=ac.createGain();src.buffer=buffer;filter.type='lowpass';filter.frequency.value=frequency;gain.gain.value=volume;src.connect(filter);filter.connect(gain);gain.connect(bus);src.start();},
    play(name,volume=1){if(!this.enabled||!ac)return;const t=ac.currentTime;if(last[name]&&t-last[name]<.09)return;last[name]=t;const tone=(f,d=.2,type='sine',v=.2,delay=0,end)=>this.tone(f,t+delay,d,type,v*volume,end);
      if(name==='select'){tone(560,.08,'sine',.12);tone(840,.1,'sine',.08,.035);}
      if(name==='coin'){tone(1300,.2,'sine',.16);tone(1950,.25,'sine',.11,.06);}
      if(name==='build'){this.noise(.17,.35,600);tone(145,.12,'triangle',.26,0,75);tone(220,.16,'triangle',.12,.11);}
      if(name==='hit'){this.noise(.09,.25*volume,1500);tone(180,.08,'triangle',.16,0,65);}
      if(name==='bow'){this.noise(.1,.2*volume,2500);tone(630,.07,'triangle',.1,0,180);}
      if(name==='fire'){this.noise(.35,.23*volume,1200);tone(130,.3,'sine',.16,0,430);}
      if(name==='flag'){[330,440,660].forEach((f,i)=>tone(f,.35,'triangle',.13,i*.07));}
      if(['level','complete','recruit'].includes(name)){[392,494,587,784].forEach((f,i)=>tone(f,.5,'sine',.17,i*.1));}
      if(name==='spell'){[523,784,1047,1568].forEach((f,i)=>tone(f,.8,'sine',.13,i*.07));this.noise(.5,.09,1800);}
      if(name==='victory'){[294,392,494,587,784].forEach((f,i)=>tone(f,.9,'triangle',.17,i*.15));}
      if(name==='danger'){[146,155,146].forEach((f,i)=>tone(f,.65,'triangle',.3,i*.5));}
    },
    ambience(){if(!this.enabled||!ac||document.hidden)return;const sets=[[196,246.94,293.66,392],[174.61,220,261.63,349.23],[164.81,196,246.94,329.63],[146.83,196,220,293.66]],notes=sets[chord++%4],t=ac.currentTime;notes.forEach((f,i)=>{this.tone(f,t+i*.35,5.5,'sine',.042);this.tone(f*2,t+i*.66+1,1.3,'triangle',.025);});for(let i=0;i<3;i++)this.tone(1500+i*350,t+4+i*.16,.12,'sine',.018,2400+i*100);}
  };
})();
