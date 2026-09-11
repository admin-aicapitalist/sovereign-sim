(function(){
  const E=G.environment={decor:[],rails:[]},CHUNK=256,GUTTER=8,MAX_BYTES=96*1024*1024;
  const cache=new Map(),patterns=new Map();let bytes=0,detail=1,revision=0;
  let mapPath,waterPath,flowPath,roadPath,courtPath,bridgePath,patches=[],bridgeTiles=[];
  const hash=(x,y)=>{let n=Math.imul(x+731,374761393)^Math.imul(y+919,668265263);n=Math.imul(n^(n>>>13),1274126177);return(n^(n>>>16))>>>0;};
  const water=t=>t&&(t.kind==='water'||t.kind==='bridge');
  const project=points=>points.map(([x,y])=>{const p=G.iso(x,y);return[p.x,p.y];});
  function closedPath(loops){const path=new Path2D();for(const points of loops){if(!points.length)continue;path.moveTo(...points[0]);for(const p of points.slice(1))path.lineTo(...p);path.closePath();}return path;}
  function smooth(points,iterations){for(let k=0;k<iterations;k++){const next=[];for(let i=0;i<points.length;i++){const a=points[i],b=points[(i+1)%points.length];next.push([a[0]*.75+b[0]*.25,a[1]*.75+b[1]*.25],[a[0]*.25+b[0]*.75,a[1]*.25+b[1]*.75]);}points=next;}return points;}
  function contours(predicate,rounds=2,rough=false){
    const edges=[],starts=new Map();
    const add=(a,b)=>{const edge={a,b,used:false};edges.push(edge);const key=a.join(',');if(!starts.has(key))starts.set(key,[]);starts.get(key).push(edge);};
    for(const t of G.tiles)if(predicate(t)){
      const x=t.x,y=t.y;
      if(!predicate(G.tile(x,y-1)))add([x,y],[x+1,y]);
      if(!predicate(G.tile(x+1,y)))add([x+1,y],[x+1,y+1]);
      if(!predicate(G.tile(x,y+1)))add([x+1,y+1],[x,y+1]);
      if(!predicate(G.tile(x-1,y)))add([x,y+1],[x,y]);
    }
    const loops=[];
    for(const first of edges){if(first.used)continue;const points=[];let edge=first;
      while(edge&&!edge.used){edge.used=true;points.push(edge.a);edge=starts.get(edge.b.join(','))?.find(e=>!e.used);}
      if(points.length<3)continue;
      let outline=smooth(points,rounds);
      if(rough)outline=outline.map(([x,y])=>[x+Math.sin(x*7.4+y*9.1)*.045,y+Math.sin(x*11.9-y*6.8)*.045]);
      loops.push(project(outline));
    }
    return closedPath(loops);
  }
  function pattern(ctx,key){
    const sprite=G.sprites[key];if(!sprite?.assetLoaded)return null;
    if(!patterns.has(key)){const p=ctx.createPattern(sprite.canvas,'repeat');p.setTransform(new DOMMatrix([sprite.w/sprite.canvas.width,0,0,sprite.h/sprite.canvas.height,0,0]));patterns.set(key,p);}
    return patterns.get(key);
  }
  function fillMaterial(ctx,key,fallback,path,rect){
    ctx.save();if(path)ctx.clip(path);ctx.fillStyle=pattern(ctx,key)||fallback;
    ctx.fillRect(rect.x,rect.y,rect.w,rect.h);ctx.restore();
  }
  function near(p,rect,margin=80){return p.x>rect.x-margin&&p.x<rect.x+rect.w+margin&&p.y>rect.y-margin&&p.y<rect.y+rect.h+margin;}
  E.ready=()=>!!G.sprites['terrain-grass']?.assetLoaded;
  E.prepare=function(){
    for(const entry of cache.values()){entry.canvas.width=entry.canvas.height=0;}cache.clear();patterns.clear();bytes=0;revision++;
    mapPath=closedPath([project([[0,0],[G.MAP,0],[G.MAP,G.MAP],[0,G.MAP]])]);
    waterPath=contours(water,2,true);
    flowPath=contours(t=>t?.kind==='water',1,false);
    roadPath=contours(t=>t?.kind==='path',2,true);
    bridgePath=contours(t=>t?.kind==='bridge',0,false);
    const center=G.palace||{x:20.5,y:20.5};
    courtPath=closedPath([project(Array.from({length:48},(_,i)=>{const a=i*Math.PI/24,r=3.42+.10*Math.sin(i*2.9);return[center.x+Math.cos(a)*r,center.y+Math.sin(a)*r];}))]);
    bridgeTiles=G.tiles.filter(t=>t.kind==='bridge');E.decor=[];E.rails=[];patches=[];
    // These details have a separate deterministic seed and never change navigation.
    for(const d of G.decor){
      const n=hash(Math.floor(d.x*13),Math.floor(d.y*13));
      const key=d.type==='rock'?'rock'+n%4:n%7===0?'shrub'+n%3:n%3===0?'grass'+n%2:'flowers'+n%2;
      E.decor.push({...d,key,scale:d.type==='rock'?.62:.76});
    }
    for(let i=0;i<G.trees.length;i++){
      const t=G.trees[i],p=G.iso(t.x,t.y);
      if(i%3===0)patches.push({...p,r:25+hash(i,2)%18,forest:true});
      if(i%43===0)E.decor.push({x:t.x+.42,y:t.y+.18,key:i%2?'log':'stump',scale:.77});
    }
    for(const t of G.tiles){
      if(t.kind!=='grass')continue;
      if(hash(t.x,t.y)%17===0){const p=G.iso(t.x+.5,t.y+.5);patches.push({...p,r:23+hash(t.y,t.x)%18,forest:false});}
      const neighbours=[[0,-1],[1,0],[0,1],[-1,0]].filter(([x,y])=>G.tile(t.x+x,t.y+y)?.kind==='water');
      if(neighbours.length&&hash(t.x,t.y)%3!==0){const [dx,dy]=neighbours[0];
        E.decor.push({x:t.x+.5+dx*.32,y:t.y+.5+dy*.32,key:hash(t.x,t.y)%5===0?'rock1':'reeds'+hash(t.x,t.y)%2,scale:.75});
      }
    }
    for(const t of bridgeTiles){
      if(G.tile(t.x,t.y-1)?.kind!=='bridge')E.rails.push({x:t.x+.5,y:t.y,key:'bridge-rail',scale:1});
      if(G.tile(t.x,t.y+1)?.kind!=='bridge')E.rails.push({x:t.x+.5,y:t.y+1,key:'bridge-rail',scale:1});
    }
    E.decor=E.decor.filter(d=>G.sprites[d.key]?.assetLoaded);
    E.rails=E.rails.filter(d=>G.sprites[d.key]?.assetLoaded);
  };
  function paintChunk(ctx,rect){
    ctx.save();ctx.clip(mapPath);
    fillMaterial(ctx,'terrain-grass','#82935d',null,rect);
    for(const patch of patches){if(!near(patch,rect,55))continue;
      for(let ring=0;ring<3;ring++){
        const r=patch.r*(1.12-ring*.13),points=[];
        for(let i=0;i<16;i++){const a=i*Math.PI/8,k=1+.14*Math.sin(i*2.3+patch.x);points.push([patch.x+Math.cos(a)*r*k,patch.y+Math.sin(a)*r*k*.5]);}
        ctx.save();ctx.globalAlpha=patch.forest ? .10 : .055;
        fillMaterial(ctx,'terrain-dirt','#92855f',closedPath([points]),rect);ctx.restore();
      }
    }
    ctx.lineJoin='round';ctx.strokeStyle='#73814f65';ctx.lineWidth=12;ctx.stroke(roadPath);
    ctx.strokeStyle='#a29b7180';ctx.lineWidth=6;ctx.stroke(roadPath);
    fillMaterial(ctx,'terrain-road','#b9a778',roadPath,rect);
    ctx.strokeStyle='#c6b78a60';ctx.lineWidth=.65;ctx.stroke(roadPath);
    ctx.strokeStyle='#96957790';ctx.lineWidth=7;ctx.stroke(courtPath);
    fillMaterial(ctx,'terrain-paving','#b4b19b',courtPath,rect);
    // Sand, damp earth, shallow green water, then deeper blue-green current.
    ctx.save();ctx.strokeStyle=pattern(ctx,'terrain-dirt')||'#938562';
    for(const [width,alpha] of [[22,.18],[16,.25],[11,.38]]){ctx.lineWidth=width;ctx.globalAlpha=alpha;ctx.stroke(waterPath);}
    ctx.strokeStyle=pattern(ctx,'terrain-road')||'#b6a579';ctx.globalAlpha=.72;ctx.lineWidth=5;ctx.stroke(waterPath);ctx.restore();
    fillMaterial(ctx,'terrain-water','#52858c',waterPath,rect);
    ctx.save();ctx.clip(waterPath);
    ctx.strokeStyle='#a4b8a411';ctx.lineWidth=29;ctx.stroke(waterPath);
    ctx.strokeStyle='#a5bb9f17';ctx.lineWidth=14;ctx.stroke(waterPath);
    ctx.strokeStyle='#5b785c70';ctx.lineWidth=1.4;ctx.stroke(waterPath);
    ctx.strokeStyle='#ced4b944';ctx.lineWidth=.4;ctx.stroke(waterPath);ctx.restore();
    ctx.fillStyle='#88734f';ctx.fill(bridgePath);
    const deck=G.sprites['bridge-deck'];
    for(const t of bridgeTiles){const p=G.iso(t.x,t.y);if(!near(p,rect,70))continue;
      if(deck?.assetLoaded)G.paintSprite(ctx,deck,p.x-32,p.y,64,32);
      else{ctx.strokeStyle='#b49a6c';ctx.lineWidth=2;for(let i=0;i<8;i++)G.art.line(ctx,[[p.x-32+i*4,p.y+16-i*2],[p.x+i*4,p.y+32-i*2]],'#b49a6c',2);}
    }
    ctx.restore();
  }
  function chunk(x,y,density){
    const key=density+':'+x+':'+y;
    if(cache.has(key)){const entry=cache.get(key);cache.delete(key);cache.set(key,entry);return entry.canvas;}
    const canvas=document.createElement('canvas');canvas.width=canvas.height=(CHUNK+GUTTER*2)*density;
    const ctx=canvas.getContext('2d');ctx.scale(density,density);ctx.translate(GUTTER-x*CHUNK,GUTTER-y*CHUNK);
    ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';
    paintChunk(ctx,{x:x*CHUNK-GUTTER,y:y*CHUNK-GUTTER,w:CHUNK+GUTTER*2,h:CHUNK+GUTTER*2});
    const cost=canvas.width*canvas.height*4;cache.set(key,{canvas,cost});bytes+=cost;
    while(bytes>MAX_BYTES&&cache.size>1){const oldest=cache.keys().next().value,entry=cache.get(oldest);bytes-=entry.cost;entry.canvas.width=entry.canvas.height=0;cache.delete(oldest);}
    return canvas;
  }
  E.drawGround=function(ctx,rect,pixelsPerUnit){
    const x0=Math.max(Math.floor(-G.MAP*G.TW/2/CHUNK),Math.floor(rect.x/CHUNK)),x1=Math.min(Math.ceil(G.MAP*G.TW/2/CHUNK)-1,Math.floor((rect.x+rect.w)/CHUNK)),y0=Math.max(0,Math.floor(rect.y/CHUNK)),y1=Math.min(Math.ceil(G.MAP*G.TH/CHUNK)-1,Math.floor((rect.y+rect.h)/CHUNK));
    if(x0>x1||y0>y1)return;
    detail=pixelsPerUnit<=1.35?1:pixelsPerUnit<=2.7?2:4;
    const count=(x1-x0+1)*(y1-y0+1);
    while(detail>1&&count*(CHUNK+GUTTER*2)**2*detail**2*4>MAX_BYTES)detail/=2;
    ctx.save();ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';
    for(let y=y0;y<=y1;y++)for(let x=x0;x<=x1;x++){
      const canvas=chunk(x,y,detail);
      ctx.drawImage(canvas,GUTTER*detail,GUTTER*detail,CHUNK*detail,CHUNK*detail,x*CHUNK,y*CHUNK,CHUNK,CHUNK);
    }
    ctx.restore();
  };
  E.drawWater=function(ctx,rect,time){
    const glints=pattern(ctx,'terrain-water-glints');if(!glints)return;
    const s=G.sprites['terrain-water-glints'],sx=s.w/s.canvas.width,sy=s.h/s.canvas.height;
    ctx.save();ctx.clip(mapPath);ctx.clip(waterPath);ctx.clip(flowPath);ctx.globalAlpha=.42;
    glints.setTransform(new DOMMatrix([sx,0,0,sy,(time*2.8)%256,(time*.42)%128]));
    ctx.fillStyle=glints;ctx.fillRect(rect.x,rect.y,rect.w,rect.h);
    ctx.globalAlpha=.23+.08*Math.sin(time*.8);
    glints.setTransform(new DOMMatrix([sx,0,0,sy,(-time*1.4+70)%256,(-time*.17+37)%128]));
    ctx.fillRect(rect.x,rect.y,rect.w,rect.h);ctx.restore();
  };
  E.layout=function(key,scale=1){const sprite=G.sprites[key];if(!sprite?.assetLoaded)return null;return{sprite,x:-sprite.anchor[0]*scale,y:-sprite.anchor[1]*scale,w:sprite.w*scale,h:sprite.h*scale};};
  E.drawProp=function(ctx,prop){const layout=E.layout(prop.key,prop.scale);if(!layout)return;const p=G.iso(prop.x,prop.y);G.paintSprite(ctx,layout.sprite,p.x+layout.x,p.y+layout.y,layout.w,layout.h);};
  E.drawTree=function(ctx,tree,time){
    const layout=E.layout(tree.type,tree.scale*.84);if(!layout)return false;
    const p=G.iso(tree.x,tree.y),sway=Math.sin(time*1.05+tree.x*.3+tree.y*.7)*.65;
    ctx.save();ctx.translate(p.x,p.y);ctx.transform(1,0,sway/Math.max(1,-layout.y),1,0,0);
    ctx.imageSmoothingEnabled=true;ctx.imageSmoothingQuality='high';
    G.paintSprite(ctx,layout.sprite,layout.x,layout.y,layout.w,layout.h);ctx.restore();return true;
  };
  E.stats=()=>({ready:E.ready(),chunks:cache.size,bytes,maxBytes:MAX_BYTES,detail,revision,decor:E.decor.length,rails:E.rails.length});
})();
