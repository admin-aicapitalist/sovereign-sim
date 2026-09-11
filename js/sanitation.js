(function(){
  G.sanitationStatus=function(){
    const cottages=G.buildings.filter(b=>!b.dead&&b.type==='house'&&b.progress===1).length;
    const target=Math.ceil(Math.max(0,cottages-G.SANITATION.safeCottages)/G.SANITATION.cottagesPerSewer);
    const active=G.buildings.filter(b=>!b.dead&&b.infestation).length;
    return {cottages,target,active,nextIn:target>active?Math.ceil(G.SANITATION.incubation-G.sanitation.timer):null};
  };
  function rat(origin,home){
    const p=G.nearPoint(origin.x,origin.y,3),u=G.addUnit('rat',p.x,p.y,home);
    u.infestation=true;u.raider=true;return u;
  }
  G.spawnInfestation=function(){
    const houses=G.buildings.filter(b=>!b.dead&&b.type==='house'&&b.progress===1),sites=[];
    for(const t of G.tiles){
      const p={x:t.x+1,y:t.y+1};if(!houses.some(h=>G.dist(h,p)>=3&&G.dist(h,p)<10))continue;
      if(G.buildings.some(b=>!b.dead&&Math.abs(b.x-p.x)<(b.data.size+2)/2+1&&Math.abs(b.y-p.y)<(b.data.size+2)/2+1))continue;
      if(G.buildings.some(b=>!b.dead&&b.infestation&&G.dist(b,p)<8))continue;
      if(G.units.some(u=>!u.dead&&Math.abs(u.x-p.x)<1.5&&Math.abs(u.y-p.y)<1.5)||G.loot.some(l=>!l.dead&&Math.abs(l.x-p.x)<2&&Math.abs(l.y-p.y)<2))continue;
      const ring=[];let dry=true;
      for(let dy=-1;dy<=2;dy++)for(let dx=-1;dx<=2;dx++){
        const tile=G.tile(t.x+dx,t.y+dy);if(!tile||tile.kind==='water'||tile.kind==='bridge'){dry=false;continue;}
        if(dx>=0&&dx<2&&dy>=0&&dy<2){if(tile.kind!=='grass')dry=false;}
        else if(G.walkable(tile.x,tile.y))ring.push({x:tile.x+.5,y:tile.y+.5});
      }
      if(dry&&ring.length)sites.push({x:t.x,y:t.y,ring,score:houses.reduce((sum,h)=>sum+Math.max(0,10-G.dist(h,p)),0)+G.sanitationRandom()*4});
    }
    sites.sort((a,b)=>b.score-a.score);
    const origin=G.nearPoint(G.palace.x,G.palace.y,4);
    const site=sites.find(p=>p.ring.some(q=>G.dist(origin,q)<1||G.findPath(origin.x,origin.y,q.x,q.y).length));
    if(!site){
      // Filling every building plot cannot suppress the consequence of overcrowding.
      const {target}=G.sanitationStatus();if(!target||G.units.filter(u=>!u.dead&&u.infestation).length>=target*6)return false;
      const house=houses[Math.floor(G.sanitationRandom()*houses.length)];rat(house,null);rat(house,null);
      G.notify('Overcrowded drains spill rats into the neighborhood!','danger');return true;
    }
    for(let y=site.y-1;y<=site.y+2;y++)for(let x=site.x-1;x<=site.x+2;x++)G.tile(x,y).blocked=false;
    G.trees=G.trees.filter(t=>!(t.x>=site.x-1&&t.x<site.x+3&&t.y>=site.y-1&&t.y<site.y+3));
    const b=G.addBuilding('sewer',site.x,site.y);b.infestation=true;b.siteName='Overcrowded Sewer';
    b.data={...b.data,name:'Overcrowded Sewer',subtitle:'Rats beneath the neighborhood',interval:G.SANITATION.ratInterval,reward:0,description:'Overcrowding opened this sewer. It breeds rats every '+G.SANITATION.ratInterval+' seconds. Destroy it and limit cottage growth; it can return while the town is overcrowded. No gold or experience rewards.'};
    b.spawnTimer=b.data.interval;b.hp=b.maxHp=650;rat(b,b);rat(b,b);G.reveal(b.x,b.y,3);
    if(!G.headless)G.makeTerrain?.();G.notify('Too many cottages! A rat sewer has opened near your homes.','danger');return b;
  };
  G.updateSanitation=function(dt){
    const s=G.sanitationStatus();
    if(s.target>G.sanitation.lastTarget)G.notify('Overcrowding: '+s.cottages+' cottages can support '+s.target+' rat sewer'+(s.target===1?'':'s')+'. Clear infestations and protect your homes.','danger');
    G.sanitation.lastTarget=s.target;
    if(s.target<=s.active){G.sanitation.timer=0;return;}
    G.sanitation.timer+=dt;
    if(G.sanitation.timer>=G.SANITATION.incubation){G.sanitation.timer=0;G.spawnInfestation();}
  };
})();
