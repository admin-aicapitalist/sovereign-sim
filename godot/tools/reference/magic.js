(function(){
  const spell = key => Object.hasOwn(G.SPELLS,key) ? G.SPELLS[key] : null;
  const temple = b => b?.type==='temple' && !b.dead && !b.hostile && b.progress===1 && G.buildings.includes(b);
  const living = () => [...G.units,...G.buildings].filter(e=>!e.dead);
  const inCircle = (e,x,y,r) => Math.hypot(e.x-x,e.y-y)<r;
  G.spellAvailable = key => !!spell(key) && (!!spell(key).innate || !!G.magic.unlocked[key]);
  G.spellLockReason = function(key){
    const d=spell(key);if(!d)return 'Unknown spell';
    if(G.spellAvailable(key))return '';
    if(G.magic.project?.key===key)return 'Learning · '+Math.ceil(G.magic.project.remaining)+'s';
    return 'Learn at Temple';
  };
  G.researchSpell = function(key,building){
    const d=spell(key),m=G.magic;
    if(G.result||!d||!temple(building)||G.spellAvailable(key)||m.project)return false;
    if(d.prerequisite&&!G.spellAvailable(d.prerequisite))return false;
    if(G.gold<d.research){G.notify('Not enough gold to learn '+d.name+'.');return false;}
    G.gold-=d.research;m.project={key,remaining:d.time,total:d.time};
    G.notify('The Temple has begun studying '+d.name+'.');return true;
  };
  G.spellTargets = function(key,x,y){
    const d=spell(key);if(!d)return [];
    return living().filter(e=>inCircle(e,x,y,d.radius)&&
      (d.offensive?e.hostile:!e.hostile)&&
      (key==='heal'?e.hp<e.maxHp:key==='ward'||key==='haste'?e.kind==='unit':true));
  };
  G.spellPoint = function(key,ground,hit){
    if(key==='farsight')return ground;
    const d=spell(key),e=hit?.kind==='flag'?hit.target:hit;
    if(!d||!e||e.dead||!['unit','building'].includes(e.kind))return ground;
    return (d.offensive?e.hostile:!e.hostile&&(key==='heal'||e.kind==='unit'))?e:ground;
  };
  G.spellEffect = function(key,x,y,caster){
    if(G.headless)return;
    const serial=++G.magic.visualSerial;
    G.effects.push({type:'spell',spell:key,x,y,time:0,started:G.time,life:G.SPELLS[key].visualDuration,
      seed:G.rng(G.seed^Math.imul(serial,2654435761))(),caster:caster?{x:caster.x,y:caster.y}:null});
  };
  function apply(key,x,y,caster){
    const d=spell(key),targets=G.spellTargets(key,x,y).sort((a,b)=>G.dist(a,{x,y})-G.dist(b,{x,y}));
    if(key==='farsight'){
      G.vision.push({x,y,r:d.radius,until:G.time+d.duration});G.reveal(x,y,d.radius);
    }else if(key==='meteor'){
      // Damage lands with the visible impact, independent of frame rate or rendering.
      G.magic.impacts.push({x,y,caster,at:G.time+d.delay});
    }else for(const [i,e]of targets.entries()){
      if(key==='heal')e.hp=Math.min(e.maxHp,e.hp+d.heal);
      else if(key==='ward'||key==='haste')e.magicBuffs[key]=d.duration;
      else {
        G.damage(e,key==='lightning'&&i>0?d.splash:d.damage,caster);
        if(key==='frost'&&!e.dead&&e.kind==='unit')e.magicBuffs.frost=d.duration;
      }
    }
    G.spellEffect(key,key==='lightning'&&targets.length?targets[0].x:x,key==='lightning'&&targets.length?targets[0].y:y,caster);
  }
  G.cast = function(key,x,y){
    const d=spell(key);
    if(G.result||G.modalOpen||!d)return false;
    if(!Number.isFinite(x)||!Number.isFinite(y)||!G.inBounds(x,y)){G.notify('Choose a location within the borderlands.');return false;}
    if(!G.spellAvailable(key)){G.notify('Select a completed Temple to learn '+d.name+'.');return false;}
    if(key!=='farsight'&&!G.isVisible(x,y)){G.notify('Your subjects must be able to see the spell’s target.');return false;}
    if(G.cooldowns[key]>0){G.notify('This spell is still recharging.');return false;}
    if(G.gold<d.cost){G.notify('Not enough gold for this spell.');return false;}
    if(key!=='farsight'&&!G.spellTargets(key,x,y).length){G.notify(d.offensive?'Choose a monster or lair.':key==='heal'?'Choose wounded subjects or a damaged building.':'Choose friendly units to bless.');return false;}
    G.gold-=d.cost;G.cooldowns[key]=d.cooldown;G.stats.royalSpells++;
    apply(key,x,y,null);G.sound?.play('spell-'+key);return true;
  };
  G.castWizardSpell = function(u,key,x,y){
    const d=spell(key);
    if(G.paused||G.result||!u||u.dead||u.hostile||u.type!=='wizard'||!G.units.includes(u)||!d||!G.spellAvailable(key))return false;
    if(!Number.isFinite(x)||!Number.isFinite(y)||!G.inBounds(x,y)||!inCircle(u,x,y,u.data.castRange))return false;
    if(u.castTimer>0||u.spellCooldowns[key]>0||u.mana<d.mana)return false;
    if(key!=='farsight'&&!G.spellTargets(key,x,y).length)return false;
    u.mana-=d.mana;u.spellCooldowns[key]=d.cooldown;u.castTimer=3;u.attacking=.6;
    u.attackTimer=Math.max(u.attackTimer,.7);u.lastSpell={key,at:G.time};G.stats.wizardSpells++;
    apply(key,x,y,u);if(G.isVisible(u.x,u.y))G.sound?.play('spell-'+key,.25);return true;
  };
  G.updateMagic = function(dt){
    const m=G.magic,p=m.project;
    if(p&&G.buildings.some(temple)){
      p.remaining=Math.max(0,p.remaining-dt);
      if(p.remaining===0){m.unlocked[p.key]=true;m.project=null;G.notify(G.SPELLS[p.key].name+' learned. You and every wizard can now cast it.');G.sound?.play('complete');for(const u of G.units)if(u.type==='wizard')u.think=0;}
    }
    const due=m.impacts.filter(i=>i.at<=G.time);m.impacts=m.impacts.filter(i=>i.at>G.time);
    for(const i of due){for(const e of G.spellTargets('meteor',i.x,i.y))G.damage(e,G.SPELLS.meteor.damage,i.caster);if(G.isVisible(i.x,i.y))G.sound?.play('meteor-impact',.6);}
  };
  G.updateUnitMagic = function(u,dt){
    for(const k of Object.keys(u.magicBuffs))u.magicBuffs[k]=Math.max(0,u.magicBuffs[k]-dt);
    if(u.type!=='wizard')return;
    const resting=u.state==='Resting'||!u.target||u.target.dead;
    u.mana=Math.min(u.maxMana,u.mana+dt*(resting?4:2));
    u.castTimer=Math.max(0,u.castTimer-dt);
    for(const k of Object.keys(u.spellCooldowns))u.spellCooldowns[k]=Math.max(0,u.spellCooldowns[k]-dt);
  };
  G.magicMoveMultiplier = u => (u.magicBuffs.haste>0?G.SPELLS.haste.speed:1)*(u.magicBuffs.frost>0?G.SPELLS.frost.speed:1);
  G.magicAttackMultiplier = u => (u.magicBuffs.haste>0?G.SPELLS.haste.attackSpeed:1)*(u.magicBuffs.frost>0?G.SPELLS.frost.attackSpeed:1);
  G.thinkWizard = function(u){
    if(u.castTimer>0)return;
    const ready=k=>G.spellAvailable(k)&&!(u.spellCooldowns[k]>0)&&u.mana>=G.SPELLS[k].mana;
    const nearby=living().filter(e=>inCircle(e,u.x,u.y,u.data.castRange));
    const foes=nearby.filter(e=>e.hostile),allies=nearby.filter(e=>!e.hostile&&e.kind==='unit');
    const cast=(k,e)=>G.castWizardSpell(u,k,e.x,e.y);
    if(ready('heal')){
      const hurt=nearby.filter(e=>!e.hostile&&e.maxHp-e.hp>=50&&e.hp/e.maxHp<(e.kind==='unit'?.7:.5)).sort((a,b)=>a.hp/a.maxHp-b.hp/b.maxHp)[0];
      if(hurt&&cast('heal',hurt))return;
    }
    if(ready('frost')){
      const close=foes.find(e=>e.kind==='unit'&&!e.magicBuffs.frost&&(G.dist(u,e)<2.5||foes.filter(f=>f.kind==='unit'&&G.dist(e,f)<G.SPELLS.frost.radius&&!f.magicBuffs.frost).length>=2));
      if(close&&cast('frost',close))return;
    }
    if(ready('ward')){
      const threatened=allies.filter(a=>!a.magicBuffs.ward&&foes.some(e=>e.target===a&&G.dist(e,a)<4)).sort((a,b)=>a.hp/a.maxHp-b.hp/b.maxHp)[0];
      if(threatened&&cast('ward',threatened))return;
    }
    if(u.state==='Fleeing'||u.state==='Resting')return;
    if(ready('meteor')){
      const cluster=foes.find(e=>(e===u.target&&e.kind==='building'&&e.hp>350)||foes.filter(f=>G.dist(e,f)<G.SPELLS.meteor.radius).length>=3);
      if(cluster&&cast('meteor',cluster))return;
    }
    if(ready('haste')){
      const fighter=allies.find(a=>a.hero&&!a.magicBuffs.haste&&a.target&&!a.target.dead&&G.dist(a,a.target)<a.data.range+1);
      if(fighter&&cast('haste',fighter))return;
    }
    if(ready('lightning')){
      const target=foes.filter(e=>e.kind==='unit'||e===u.target).sort((a,b)=>b.hp-a.hp)[0];
      if(target&&cast('lightning',target))return;
    }
    // Scout only outside combat, retaining mana for an unexpected encounter.
    if(!foes.length&&u.mana>=70&&ready('farsight')){
      const tile=G.tiles.find(t=>!t.explored&&G.walkable(t.x,t.y)&&G.dist(u,t)<u.data.castRange-1);
      if(tile)cast('farsight',{x:tile.x+.5,y:tile.y+.5});
    }
  };
})();
