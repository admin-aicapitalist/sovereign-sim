(function(){
  G.inBounds=(x,y)=>x>=0&&y>=0&&x<G.MAP&&y<G.MAP;
  G.tile=(x,y)=>G.inBounds(Math.floor(x),Math.floor(y))?G.tiles[Math.floor(y)*G.MAP+Math.floor(x)]:null;
  G.walkable=(x,y)=>{const t=G.tile(x,y);return !!t&&t.kind!=='water'&&!t.blocked;};
  G.isVisible=(x,y)=>{const t=G.tile(x,y);return !!t&&t.visible;};
  G.isExplored=(x,y)=>{const t=G.tile(x,y);return !!t&&t.explored;};
  G.reveal=function(x,y,r,permanent=true){for(let yy=Math.floor(y-r);yy<=y+r;yy++)for(let xx=Math.floor(x-r);xx<=x+r;xx++){const t=G.tile(xx,yy);if(t&&Math.hypot(xx-x,yy-y)<r){t.visible=true;if(permanent)t.explored=true;}}};
  G.generateWorld=function(){const r=G.rng(82741);G.tiles=[];G.trees=[];G.decor=[];G.vision=[];
    for(let y=0;y<G.MAP;y++)for(let x=0;x<G.MAP;x++){
      const river=32+Math.sin(y*.16)*3.1+Math.sin(y*.4)*.8,water=x>river&&x<river+4.5;
      const pond=Math.hypot((x-7)*.9,(y-33)*1.2)<4.2;
      const path=Math.abs(y-21-Math.sin(x*.23)*.65)<.9&&x>8&&x<33||Math.abs(x-20+Math.sin(y*.3)*.5)<.85&&y>8&&y<34;
      const t={x,y,kind:water||pond?'water':path?'path':'grass',noise:r(),blocked:false,explored:false,visible:false};
      if(water&&y>=19&&y<=21)t.kind='bridge';G.tiles.push(t);
    }
    for(let y=1;y<G.MAP-1;y++)for(let x=1;x<G.MAP-1;x++){
      const t=G.tile(x,y),center=Math.hypot((x-20)*.9,(y-21)*1.1),clear=[[9,12],[30,9],[9,29],[36,31]].some(p=>Math.hypot(x-p[0],y-p[1])<3.4);
      if(t.kind==='grass'&&center>6.8&&!clear&&r()<(center>15?.54:.18)){
        const tree={x:x+.25+r()*.5,y:y+.25+r()*.5,type:(r()<.67?'pine':'oak')+Math.floor(r()*6),scale:.7+r()*.52};G.trees.push(tree);t.blocked=true;
      }else if(t.kind==='grass'&&r()<.22)G.decor.push({x:x+r(),y:y+r(),type:r()<.52?'rock':'flowers',seed:r()});
    }
    // Make all lairs reachable, including a crossing to the eastern camp.
    const clearLine=(ax,ay,bx,by)=>{const n=Math.ceil(Math.hypot(bx-ax,by-ay)*2);for(let i=0;i<=n;i++){const x=G.lerp(ax,bx,i/n),y=G.lerp(ay,by,i/n);for(let dy=-1;dy<=1;dy++)for(let dx=-1;dx<=1;dx++){const t=G.tile(x+dx,y+dy);if(t&&t.kind!=='water')t.blocked=false;}}};
    [[9,12],[30,9],[9,29],[36,31],[36,20]].forEach(p=>clearLine(20,21,p[0],p[1]));clearLine(36,20,36,31);
    G.trees=G.trees.filter(t=>G.tile(t.x,t.y).blocked);G.reveal(20,21,13);
  };
  G.updateVision=function(){G.tiles.forEach(t=>t.visible=false);for(const b of G.buildings)if(!b.dead&&!b.hostile)G.reveal(b.x,b.y,b.data.sight||5);for(const u of G.units)if(!u.dead&&!u.hostile)G.reveal(u.x,u.y,u.data.sight);G.vision=G.vision.filter(v=>v.until>G.time);G.vision.forEach(v=>G.reveal(v.x,v.y,v.r));};
  G.canPlace=function(type,x,y){const d=G.BUILDINGS[type];if(!d||d.hostile||type==='palace')return false;for(let yy=y;yy<y+d.size;yy++)for(let xx=x;xx<x+d.size;xx++){const t=G.tile(xx,yy);if(!t||!t.explored||t.blocked||t.kind==='water'||t.kind==='bridge')return false;}return !G.buildings.some(b=>!b.dead&&Math.abs(b.x-(x+d.size/2))<(b.data.size+d.size)/2+.35&&Math.abs(b.y-(y+d.size/2))<(b.data.size+d.size)/2+.35);};
})();
