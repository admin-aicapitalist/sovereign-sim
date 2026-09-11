(function(){
  const operatingMarket = b => b && b.type==='marketplace' && !b.dead && !b.hostile && b.progress===1 && G.buildings.includes(b);

  // Recipes belong to the kingdom; research pauses if its last marketplace falls.
  G.researchPotion=function(key,market){
    const recipe=Object.hasOwn(G.POTIONS,key)&&G.POTIONS[key],a=G.alchemy;
    if(G.result||!recipe||!operatingMarket(market)||a.unlocked[key]||a.project)return false;
    if(recipe.requires&&!a.unlocked[recipe.requires])return false;
    if(G.gold<recipe.research){G.notify('Not enough gold to research '+recipe.name+'.');return false;}
    G.gold-=recipe.research;
    a.project={key,remaining:recipe.time,total:recipe.time};
    G.notify(recipe.name+' potion research has begun.');
    return true;
  };
  G.updateAlchemy=function(dt){
    const a=G.alchemy,p=a.project;
    if(!p||!G.buildings.some(operatingMarket))return;
    p.remaining=Math.max(0,p.remaining-dt);
    if(p.remaining<=0){
      a.unlocked[p.key]=true;a.project=null;
      G.notify(G.POTIONS[p.key].name+' potions are now sold at every Marketplace.');
      G.sound?.play('complete');
      for(const u of G.units)if(u.hero&&!u.dead)u.think=0;
    }
  };
  G.potionShoppingList=function(u){
    if(!u?.hero||u.dead)return [];
    return Object.keys(G.POTIONS).filter(key=>G.alchemy.unlocked[key]&&u.potions[key]<G.POTIONS[key].capacity&&u.gold>=G.POTIONS[key].price);
  };
  G.buyPotions=function(u,market){
    if(!u?.hero||u.dead||!operatingMarket(market)||G.dist(u,market)>=3)return 0;
    let bought=0;
    for(const key of G.potionShoppingList(u)){
      const p=G.POTIONS[key],count=Math.min(p.capacity-u.potions[key],Math.floor(u.gold/p.price));
      if(count<=0)continue;
      u.potions[key]+=count;u.gold-=count*p.price;market.taxPool+=count*p.price;bought+=count;
    }
    G.stats.potionsBought+=bought;
    return bought;
  };
  G.unitArmor=function(u){return (u.data.armor||0)+(u.buffs?.stoneskin>0?G.POTIONS.stoneskin.armor:0);};
  G.unitDamage=function(u,target){
    let damage=u.data.damage+(u.hero?(u.level-1)*4:0);
    if(u.type==='thief'&&target?.kind==='unit'&&target.hostile&&target.target&&!target.target.dead&&!target.target.hostile&&target.target!==u)damage+=14;
    if(u.buffs?.strength>0)damage*=G.POTIONS.strength.damageMultiplier;
    return Math.round(damage);
  };
  G.updateSupplies=function(u,dt){
    if(!u.hero||u.dead)return;
    for(const key of Object.keys(u.buffs))u.buffs[key]=Math.max(0,u.buffs[key]-dt);
    const drink=key=>{u.potions[key]--;G.stats.potionsUsed++;G.fxAt(u.x,u.y,key==='healing'?'heal':'level');};
    if(u.hp<u.maxHp*.45&&u.potions.healing>0){
      drink('healing');u.hp=Math.min(u.maxHp,u.hp+G.POTIONS.healing.heal);
    }
    G.useCombatPotions(u,u.target);
  };
  G.useCombatPotions=function(u,target){
    if(!u.hero||u.dead)return;
    const fighting=target&&!target.dead&&target.hostile&&u.state!=='Fleeing'&&u.state!=='Resting'&&G.dist(u,target)<=u.data.range+(target.kind==='building'?target.data.size*.45:0)+.5;
    if(fighting)for(const key of ['strength','stoneskin'])if(u.potions[key]>0&&u.buffs[key]<=0){
      u.potions[key]--;G.stats.potionsUsed++;G.fxAt(u.x,u.y,'level');u.buffs[key]=G.POTIONS[key].duration;
    }
  };
})();
