(function(){
  G.inBounds=(x,y)=>x>=0&&y>=0&&x<G.MAP&&y<G.MAP;
  G.tile=(x,y)=>G.inBounds(Math.floor(x),Math.floor(y))?G.tiles[Math.floor(y)*G.MAP+Math.floor(x)]:null;
  G.walkable=(x,y)=>{const t=G.tile(x,y);return !!t&&t.kind!=='water'&&!t.blocked;};
  G.isVisible=(x,y)=>{const t=G.tile(x,y);return !!t&&t.visible;};
  G.isExplored=(x,y)=>{const t=G.tile(x,y);return !!t&&t.explored;};
  G.reveal=function(x,y,r,permanent=true){for(let yy=Math.floor(y-r);yy<=y+r;yy++)for(let xx=Math.floor(x-r);xx<=x+r;xx++){const t=G.tile(xx,yy);if(t&&Math.hypot(xx-x,yy-y)<r){t.visible=true;if(permanent)t.explored=true;}}};
  G.generateWorld=function(){
    const {random:r,home,pineChance,forestPhase}=G.generateLayout();
    for(let y=1;y<G.MAP-1;y++)for(let x=1;x<G.MAP-1;x++){
      const t=G.tile(x,y),forest=(Math.sin(x*.16+forestPhase[0])+Math.cos(y*.14+forestPhase[1])+Math.sin((x+y)*.075+forestPhase[2]))/3;
      const density=forest>.2?.66:forest>-.2?.34:.1;
      if(t.kind==='grass'&&!t.clearing&&r()<density){
        G.trees.push({x:x+.25+r()*.5,y:y+.25+r()*.5,type:(r()<pineChance?'pine':'oak')+Math.floor(r()*6),scale:.7+r()*.52});t.blocked=true;
      }else if(t.kind==='grass'&&r()<.22)G.decor.push({x:x+r(),y:y+r(),type:r()<.52?'rock':'flowers',seed:r()});
    }
    G.reveal(home.x,home.y,13);
  };
  G.updateVision=function(){G.tiles.forEach(t=>t.visible=false);for(const b of G.buildings)if(!b.dead&&!b.hostile)G.reveal(b.x,b.y,b.data.sight||5);for(const u of G.units)if(!u.dead&&!u.hostile)G.reveal(u.x,u.y,u.data.sight);G.vision=G.vision.filter(v=>v.until>G.time);G.vision.forEach(v=>G.reveal(v.x,v.y,v.r));};
  G.canPlace=function(type,x,y){const d=G.BUILDINGS[type];if(!d||d.hostile||type==='palace')return false;if(G.loot.some(p=>!p.dead&&p.x>=x&&p.x<x+d.size&&p.y>=y&&p.y<y+d.size))return false;for(let yy=y;yy<y+d.size;yy++)for(let xx=x;xx<x+d.size;xx++){const t=G.tile(xx,yy);if(!t||!t.explored||t.blocked||t.kind==='water'||t.kind==='bridge')return false;}return !G.buildings.some(b=>!b.dead&&Math.abs(b.x-(x+d.size/2))<(b.data.size+d.size)/2+.35&&Math.abs(b.y-(y+d.size/2))<(b.data.size+d.size)/2+.35);};
  G.findBuildingSite=function(type){return G.tiles.filter(t=>G.dist(t,G.palace)<10&&G.canPlace(type,t.x,t.y)).sort((a,b)=>G.dist(a,G.palace)-G.dist(b,G.palace))[0]||null;};
})();
