(async function(){
  const params=new URLSearchParams(location.search);G.headless=false;G.welcoming=!params.has('auto');G.modalOpen=false;G.seedOverride=G.normalizeSeed(params.get('seed'));
  G.makeSprites();G.spriteAssetsReady=G.loadSpriteAssets();await G.spriteAssetsReady;G.reset();
  const demo=Number(params.get('demo')||0);if(demo>=2){for(const[type,x,y]of [['warriors',16,18],['rangers',22,16],['wizards',24,21],['marketplace',19,24],['temple',16,24],['tower',25,26]]){for(let yy=y;yy<y+2;yy++)for(let xx=x;xx<x+2;xx++){const t=G.tile(xx,yy);if(t)t.blocked=false;}G.addBuilding(type,x,y,true);}for(const type of ['warrior','warrior','ranger','wizard']){const home=G.buildings.find(b=>b.data.recruits===type);const p=G.nearPoint(home.x,home.y,3);G.addUnit(type,p.x,p.y,home);}G.gold=1800;G.updateVision();}
  if(demo===1)for(const type of Object.keys(G.UNITS)){const p=G.nearPoint(20,24,4);G.addUnit(type,p.x,p.y,G.palace);}
  const forward=G.clamp(Number(params.get('t'))||0,0,3600);for(let t=0;t<forward&&!G.result;t+=.1)G.update(.1);
  G.initRender();G.initInput();G.ui.init();if(params.get('zoom'))G.camera.zoom=G.clamp(Number(params.get('zoom'))||1.12,G.ZOOM_MIN,G.ZOOM_MAX);
  G.start=function(){if(!G.welcoming)return;G.welcoming=false;document.body.classList.remove('welcoming');$('welcome').style.opacity='0';$('welcome').style.pointerEvents='none';setTimeout(()=>$('welcome').classList.add('hidden'),700);G.centerCamera();if(!G.sound.enabled)G.sound.toggle();G.ui.update(true);};
  function $(id){return document.getElementById(id);}
  if(G.welcoming){document.body.classList.add('welcoming');G.camera.x-=window.innerWidth*.17/G.camera.zoom;}else $('welcome').classList.add('hidden');
  if(G.result)G.ui.showEnd(G.result);
  let last=performance.now(),uiTime=0;
  function frame(now){const dt=Math.min((now-last)/1000,.08);last=now;if(!G.welcoming&&!document.hidden){let sim=dt*G.speed;while(sim>0){const step=Math.min(sim,.05);G.update(step);sim-=step;}}G.updateCamera(dt);G.render(dt);uiTime+=dt;if(uiTime>.25){uiTime=0;G.ui.update();}requestAnimationFrame(frame);}
  requestAnimationFrame(frame);
})();
