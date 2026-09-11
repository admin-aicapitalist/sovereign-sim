(function(){
  G.lootTable=e=>e.infestation?null:G.LOOT[e.kind==='building'?'lairs':'monsters'][e.type];
  const hasContents=p=>p.gold>0||Object.values(p.potions).some(n=>n>0);
  const usable=(u,p)=>p.gold+Object.entries(p.potions).reduce((sum,[key,n])=>sum+Math.min(n,G.POTIONS[key].capacity-u.potions[key])*G.POTIONS[key].price,0);
  G.dropLoot=function(e){
    const table=G.lootTable(e);if(!e.hostile||!table)return null;
    const r=G.lootRandom,roll=([min,max])=>min+Math.floor(r()*(max-min+1));
    const gold=roll(table.gold),potions={healing:0,strength:0,stoneskin:0};
    for(const [key,chance,count=1]of table.potions)if(r()<chance)potions[key]+=count;
    let point=null;
    for(let radius=0;radius<=6&&!point;radius++){
      const choices=[];
      for(let y=Math.floor(e.y)-radius;y<=Math.floor(e.y)+radius;y++)for(let x=Math.floor(e.x)-radius;x<=Math.floor(e.x)+radius;x++){
        if(Math.max(Math.abs(x-Math.floor(e.x)),Math.abs(y-Math.floor(e.y)))!==radius||!G.walkable(x,y))continue;
        choices.push({x:x+.5,y:y+.5});
      }
      point=choices.sort((a,b)=>G.dist(a,e)-G.dist(b,e))[0];
    }
    point=point||G.tiles.filter(t=>G.walkable(t.x,t.y)).sort((a,b)=>G.dist(a,e)-G.dist(b,e)).map(t=>({x:t.x+.5,y:t.y+.5}))[0];
    if(!point)return null;
    const chest=e.kind==='building'||e.type==='troll';
    // Repeated fighting on one tile adds to the same pouch instead of piling up objects.
    let pile=!chest&&G.loot.find(p=>!p.dead&&!p.chest&&p.x===point.x&&p.y===point.y);
    if(pile){pile.gold+=gold;for(const key of Object.keys(potions))pile.potions[key]+=potions[key];pile.source='Spoils of battle';}
    else{pile={...point,id:'loot-'+(++G.lootSerial),kind:'loot',type:chest?'loot_chest':'loot_pouch',chest,source:e.siteName||e.data.name,gold,potions,dead:false};G.loot.push(pile);}
    return pile;
  };
  G.collectLoot=function(u,p){
    if(!u?.hero||u.dead||!p||p.dead||!G.loot.includes(p)||!G.walkable(p.x,p.y)||G.dist(u,p)>.95)return false;
    const ax=Math.floor(u.x),ay=Math.floor(u.y),bx=Math.floor(p.x),by=Math.floor(p.y);
    if(ax!==bx&&ay!==by&&(!G.walkable(ax,by)||!G.walkable(bx,ay)))return false;
    const gold=p.gold;let count=0;u.gold+=gold;p.gold=0;
    for(const [key,n]of Object.entries(p.potions)){const take=Math.min(n,G.POTIONS[key].capacity-u.potions[key]);u.potions[key]+=take;p.potions[key]-=take;count+=take;}
    if(!gold&&!count)return false;
    G.stats.lootGold+=gold;G.stats.lootPotions+=count;
    if(!hasContents(p)){p.dead=true;G.stats.lootCaches++;}
    if(gold)G.fxAt(u.x,u.y,'gold',gold);if(count)G.fxAt(u.x,u.y,'blessing');
    if(p.chest)G.notify(u.name+' recovered '+[gold?gold+' gold':null,count?count+' potion'+(count===1?'':'s'):null].filter(Boolean).join(' and ')+'.');
    return true;
  };
  G.seekLoot=function(u){
    const candidates=G.loot.filter(p=>!p.dead&&usable(u,p)>0&&G.dist(u,p)<(u.type==='thief'?14:10)&&G.isVisible(p.x,p.y)&&G.walkable(p.x,p.y)
      &&!G.units.some(e=>!e.dead&&e.hostile&&G.dist(e,p)<4.5)
      &&!G.buildings.some(b=>!b.dead&&b.hostile&&G.dist(b,p)<3.5));
    candidates.sort((a,b)=>usable(u,b)/(3+G.dist(u,b))-usable(u,a)/(3+G.dist(u,a)));
    for(const p of candidates.slice(0,3)){
      if(G.collectLoot(u,p)){u.state='Collecting loot';u.target=null;u.goal=null;u.path=[];u.lootTarget=null;return true;}
      if(u.lootTarget===p&&u.path.length&&u.destination&&G.dist(u.destination,p)<.1){u.state='Recovering treasure';u.target=null;u.goal=null;return true;}
      const path=G.findPath(u.x,u.y,p.x,p.y),end=path.at(-1);
      if(!end||end.x!==p.x||end.y!==p.y)continue;
      u.lootTarget=p;u.path=path;u.destination={x:p.x,y:p.y};u.state='Recovering treasure';u.target=null;u.goal=null;return true;
    }
    if(u.lootTarget){u.path=[];u.destination=null;}u.lootTarget=null;return false;
  };
  G.lootDescription=function(e){
    const t=G.lootTable(e);if(!t)return 'No loot from urban infestations.';
    return t.gold.join('–')+' gold'+(t.potions.length?' · '+t.potions.map(([key,chance,count=1])=>Math.round(chance*100)+'% '+(count>1?count+'× ':'')+G.POTIONS[key].name).join(', '):'');
  };
})();
