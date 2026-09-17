extends RefCounted
static func available(s,key: String) -> bool:
	return s.definitions.spells.has(key) and (s.definitions.spells[key].get("innate",false) or s.magic.unlocked.get(key,false))
static func research(s,key: String,id: int) -> bool:
	var d=s.definitions.spells.get(key); var b=s.building(id)
	if s.result!="" or d==null or b.is_empty() or b.dead or b.type!="temple" or b.progress<1 or available(s,key) or not s.magic.project.is_empty(): return false
	if d.has("prerequisite") and not available(s,d.prerequisite): return false
	if s.gold<d.research: s.notify("Not enough gold to learn "+d.name+"."); return false
	s.gold-=d.research; s.magic.project={"key":key,"remaining":d.time,"total":d.time}; s.notify("The Temple has begun studying "+d.name+"."); return true
static func targets(s,key: String,point: Vector2) -> Array:
	var d=s.definitions.spells.get(key); var out: Array=[]
	if d==null: return out
	for e in s.units+s.buildings:
		if e.dead or s.pos(e).distance_to(point)>=d.radius or e.hostile!=d.get("offensive",false): continue
		if key=="heal" and e.hp>=e.max_hp: continue
		if key in ["ward","haste"] and e.kind!="unit": continue
		out.append(e)
	return out
static func target_point(s,key: String,ground: Vector2,hit) -> Vector2:
	if key=="farsight" or hit==null: return ground
	if hit.kind=="flag": hit=s.entity(hit.target)
	if hit==null or hit.dead or hit.kind not in ["unit","building"]: return ground
	var d=s.definitions.spells.get(key)
	if d!=null and (hit.hostile if d.get("offensive",false) else not hit.hostile and (key=="heal" or hit.kind=="unit")): return s.pos(hit)
	return ground
static func cast(s,key: String,point: Vector2) -> bool:
	var d=s.definitions.spells.get(key)
	if s.result!="" or d==null or not s.in_bounds(point): return false
	if not available(s,key): s.notify("Select a completed Temple to learn "+d.name+"."); return false
	if key!="farsight" and not s.is_visible(point): s.notify("Your subjects must be able to see the target."); return false
	if s.cooldowns[key]>0: s.notify("That spell is still recharging."); return false
	if s.gold<d.cost: s.notify("Not enough gold for this spell."); return false
	if key!="farsight" and targets(s,key,point).is_empty(): s.notify("Choose a valid target in the spell's area."); return false
	s.gold-=d.cost; s.cooldowns[key]=d.cooldown; s.stats.royal_spells+=1; apply(s,key,point,null); s.events.append("spell-"+key); return true
static func wizard_cast(s,u,key: String,point: Vector2) -> bool:
	if s.Journey.is_shadow(u): return false
	var d=s.definitions.spells.get(key)
	if s.paused or s.result!="" or u.dead or u.hostile or u.type!="wizard" or not s.units.has(u) or d==null or not available(s,key): return false
	if not s.in_bounds(point) or u.pos.distance_to(point)>=u.definition.castRange or u.cast_timer>0 or u.spell_cooldowns.get(key,0)>0 or u.mana<d.mana: return false
	if key!="farsight" and targets(s,key,point).is_empty(): return false
	u.mana-=d.mana; u.spell_cooldowns[key]=d.cooldown; u.cast_timer=3; u.attacking=0.6; u.cooldown=maxf(u.cooldown,0.7); u.last_spell={"key":key,"at":s.time}; s.stats.wizard_spells+=1
	if point.distance_squared_to(u.pos)>0.00001: u.heading=(point-u.pos).normalized()
	apply(s,key,point,u)
	if s.is_visible(u.pos): s.events.append("spell-"+key)
	return true
static func apply(s,key: String,point: Vector2,caster) -> void:
	var d=s.definitions.spells[key]; var chosen: Array=targets(s,key,point)
	chosen.sort_custom(func(a,b):return s.pos(a).distance_to(point)<s.pos(b).distance_to(point))
	if key=="farsight":
		s.vision.append({"x":point.x,"y":point.y,"r":d.radius,"until":s.time+d.duration}); s.reveal(point,d.radius)
	elif key=="meteor": s.magic.impacts.append({"x":point.x,"y":point.y,"caster":caster.id if caster!=null else 0,"at":s.time+d.delay})
	else:
		for i in chosen.size():
			var e=chosen[i]
			if key=="heal": e.hp=minf(e.max_hp,e.hp+d.heal)
			elif key in ["ward","haste"]: e.magic_buffs[key]=d.duration
			else:
				s.hurt(e,d.splash if key=="lightning" and i>0 else d.damage,caster,key)
				if key=="frost" and not e.dead and e.kind=="unit": e.magic_buffs.frost=d.duration
	var at: Vector2=s.pos(chosen[0]) if key=="lightning" and not chosen.is_empty() else point
	var effect: Dictionary=s.fx("spell_"+key,at,0,d.delay if key=="meteor" else d.visualDuration)
	effect.radius=d.radius; effect.targets=[]
	for e in chosen.slice(0,64): effect.targets.append({"id":e.id,"x":s.pos(e).x,"y":s.pos(e).y})
	if caster!=null: effect.caster=caster.id; effect.origin=[caster.pos.x,caster.pos.y]
	if key=="meteor": effect.delay=d.delay
static func update(s,dt: float) -> void:
	var p=s.magic.project
	if not p.is_empty() and not s.operating("temple").is_empty():
		p.remaining=maxf(0,p.remaining-dt)
		if p.remaining==0:
			s.magic.unlocked[p.key]=true; s.magic.project={}; s.notify(s.definitions.spells[p.key].name+" learned by the crown and every wizard.","complete")
			for u in s.units:
				if u.type=="wizard": u.think=0
	var due: Array=s.magic.impacts.filter(func(i):return i.at<=s.time)
	s.magic.impacts=s.magic.impacts.filter(func(i):return i.at>s.time)
	for impact in due:
		var point:=Vector2(impact.x,impact.y)
		for e in targets(s,"meteor",point): s.hurt(e,s.definitions.spells.meteor.damage,s.entity(impact.caster),"meteor")
		var burst: Dictionary=s.fx("meteor_impact",point,0,2.5)
		burst.radius=s.definitions.spells.meteor.radius
		if s.is_visible(point): s.events.append("meteor-impact")
static func update_unit(s,u,dt: float) -> void:
	for key in u.magic_buffs: u.magic_buffs[key]=maxf(0,u.magic_buffs[key]-dt)
	if u.type!="wizard": return
	var target=s.entity(u.target)
	var resting: bool=u.state=="Resting" or target==null or target.dead
	u.mana=minf(u.max_mana,u.mana+dt*(4 if resting else 2)); u.cast_timer=maxf(0,u.cast_timer-dt)
	for key in u.spell_cooldowns: u.spell_cooldowns[key]=maxf(0,u.spell_cooldowns[key]-dt)
static func move_multiplier(s,u) -> float:
	return (s.definitions.spells.haste.speed if u.magic_buffs.haste>0 else 1)*(s.definitions.spells.frost.speed if u.magic_buffs.frost>0 else 1)
static func attack_multiplier(s,u) -> float:
	return (s.definitions.spells.haste.attackSpeed if u.magic_buffs.haste>0 else 1)*(s.definitions.spells.frost.attackSpeed if u.magic_buffs.frost>0 else 1)
static func ready(s,u,key: String) -> bool: return available(s,key) and u.spell_cooldowns.get(key,0)<=0 and u.mana>=s.definitions.spells[key].mana
static func think(s,u) -> void:
	if s.Journey.is_shadow(u): return
	if u.cast_timer>0: return
	var nearby: Array=[]
	for e in s.units+s.buildings:
		if not e.dead and s.pos(e).distance_to(u.pos)<u.definition.castRange: nearby.append(e)
	var foes: Array=nearby.filter(func(e):return e.hostile)
	var allies: Array=nearby.filter(func(e):return not e.hostile and e.kind=="unit")
	if ready(s,u,"heal"):
		var hurt: Array=nearby.filter(func(e):return not e.hostile and e.max_hp-e.hp>=50 and e.hp/e.max_hp<(0.7 if e.kind=="unit" else 0.5))
		hurt.sort_custom(func(a,b):return a.hp/a.max_hp<b.hp/b.max_hp)
		if not hurt.is_empty() and wizard_cast(s,u,"heal",s.pos(hurt[0])): return
	if ready(s,u,"frost"):
		for e in foes:
			if e.kind=="unit" and e.magic_buffs.frost<=0 and (u.pos.distance_to(e.pos)<2.5 or foes.filter(func(f):return f.kind=="unit" and f.pos.distance_to(e.pos)<s.definitions.spells.frost.radius and f.magic_buffs.frost<=0).size()>=2):
				if wizard_cast(s,u,"frost",s.pos(e)): return
	if ready(s,u,"ward"):
		var threatened: Array=allies.filter(func(a):return a.magic_buffs.ward<=0 and foes.any(func(e):return e.kind=="unit" and e.target==a.id and e.pos.distance_to(a.pos)<4))
		threatened.sort_custom(func(a,b):return a.hp/a.max_hp<b.hp/b.max_hp)
		if not threatened.is_empty() and wizard_cast(s,u,"ward",s.pos(threatened[0])): return
	if u.state in ["Fleeing","Resting"]: return
	if ready(s,u,"meteor"):
		for e in foes:
			if (e.id==u.target and e.kind=="building" and e.hp>350) or foes.filter(func(f):return s.pos(f).distance_to(s.pos(e))<s.definitions.spells.meteor.radius).size()>=3:
				if wizard_cast(s,u,"meteor",s.pos(e)): return
	if ready(s,u,"haste"):
		for a in allies:
			var target=s.entity(a.target)
			if a.hero and a.magic_buffs.haste<=0 and target!=null and not target.dead and a.pos.distance_to(s.pos(target))<a.definition.range+1:
				if wizard_cast(s,u,"haste",a.pos): return
	if ready(s,u,"lightning"):
		var chosen: Array=foes.filter(func(e):return e.kind=="unit" or e.id==u.target)
		chosen.sort_custom(func(a,b):return a.hp>b.hp)
		if not chosen.is_empty() and wizard_cast(s,u,"lightning",s.pos(chosen[0])): return
	if foes.is_empty() and u.mana>=70 and ready(s,u,"farsight"):
		for t in s.fixture.tiles:
			var point:=Vector2(t.x,t.y)
			if not t.explored and s.walkable(point) and point.distance_to(u.pos)<u.definition.castRange-1:
				wizard_cast(s,u,"farsight",point+Vector2.ONE*0.5); return
