extends RefCounted
## Kingdom recipes, personal shopping/buffs, and physical treasure recovery.
static func research(s, key: String, id: int) -> bool:
	var b=s.building(id); var d=s.definitions.potions.get(key)
	if s.result!="" or d==null or b.is_empty() or b.dead or b.type!="marketplace" or b.progress<1: return false
	if s.alchemy.unlocked.get(key,false) or not s.alchemy.project.is_empty() or (d.has("requires") and not s.alchemy.unlocked.get(d.requires,false)): return false
	if s.gold<d.research: s.notify("Not enough gold for potion research."); return false
	s.gold-=d.research; s.alchemy.project={"key":key,"remaining":d.time,"total":d.time}; s.notify(d.name+" potion research has begun."); return true
static func update_research(s, dt: float) -> void:
	var p=s.alchemy.project
	if p.is_empty() or s.operating("marketplace").is_empty(): return
	p.remaining=maxf(0,p.remaining-dt)
	if p.remaining<=0:
		s.alchemy.unlocked[p.key]=true; s.alchemy.project={}; s.notify(s.definitions.potions[p.key].name+" potions now sold at every Marketplace.","complete")
		for u in s.units:
			if u.hero: u.think=0
static func shopping_list(s, u) -> Array:
	var out: Array=[]
	if not u.hero or u.dead: return out
	for key in s.definitions.potions:
		var d=s.definitions.potions[key]
		if s.alchemy.unlocked.get(key,false) and u.potions[key]<d.capacity and u.gold>=d.price: out.append(key)
	return out
static func buy(s, u, b) -> int:
	if not u.hero or u.dead or b==null or b.dead or b.type!="marketplace" or b.progress<1 or u.pos.distance_to(s.pos(b))>=3: return 0
	var bought: int=0
	for key in shopping_list(s,u):
		var d=s.definitions.potions[key]
		var count: int=mini(int(d.capacity-u.potions[key]),floori(u.gold/d.price))
		if count<=0: continue
		u.potions[key]+=count; u.gold-=count*d.price; b.tax+=count*d.price; bought+=count
	s.stats.potions_bought+=bought; return bought
static func armor(s, u) -> float:
	return u.definition.get("armor",0)+s.Equipment.bonus(s,u,"armor")+(s.definitions.potions.stoneskin.armor if u.buffs.stoneskin>0 else 0)+(s.definitions.spells.ward.armor if u.magic_buffs.ward>0 else 0)
static func damage(s, u, target=null) -> float:
	var value: float=u.definition.damage+s.Equipment.bonus(s,u,"damage")+((u.level-1)*4 if u.hero else 0)
	if u.type=="thief" and target!=null and target.kind=="unit" and target.hostile:
		var distracted=s.entity(target.target)
		if distracted!=null and not distracted.dead and not distracted.hostile and distracted.id!=u.id: value+=14
	if u.buffs.strength>0: value*=s.definitions.potions.strength.damageMultiplier
	return floorf(value+0.5)
static func update_unit(s, u, dt: float) -> void:
	if not u.hero or u.dead: return
	for key in u.buffs: u.buffs[key]=maxf(0,u.buffs[key]-dt)
	if u.hp<u.max_hp*0.45 and u.potions.healing>0:
		u.potions.healing-=1; s.stats.potions_used+=1; u.hp=minf(u.max_hp,u.hp+s.definitions.potions.healing.heal); s.fx("heal",u.pos)
	combat_potions(s,u,s.entity(u.target))
static func combat_potions(s, u, target) -> void:
	if not u.hero or u.dead or target==null or target.dead or not target.hostile or u.state in ["Fleeing","Resting"]: return
	if u.pos.distance_to(s.pos(target))>u.definition.range+(target.size*0.45 if target.kind=="building" else 0)+0.5: return
	for key in ["strength","stoneskin"]:
		if u.potions[key]>0 and u.buffs[key]<=0:
			u.potions[key]-=1; s.stats.potions_used+=1; u.buffs[key]=s.definitions.potions[key].duration; s.fx("level",u.pos)
static func loot_schema() -> Dictionary:
	return {"id":0,"kind":"loot","type":"loot_pouch","x":0.0,"y":0.0,"chest":false,"source":"","gold":0.0,"potions":{"healing":0,"strength":0,"stoneskin":0},"dead":false,"items":[]}
static func loot_table(s,e) -> Dictionary:
	return {} if e.infestation else s.definitions.loot["lairs" if e.kind=="building" else "monsters"].get(e.type,{})
static func drop_loot(s,e) -> Variant:
	var table=loot_table(s,e)
	if table.is_empty(): return null
	var amount: int=s.loot_rng.integer(int(table.gold[0]),int(table.gold[1]))
	if not s.run.is_empty() and e.kind=="building" and s.Settlement.frontier(s,e.id): amount=ceili(amount*s.run.config.rules.condition.frontier_gold)
	var potions: Dictionary={"healing":0,"strength":0,"stoneskin":0}
	for entry in table.potions:
		if s.loot_rng.next()<entry[1]: potions[entry[0]]+=int(entry[2]) if entry.size()>2 else 1
	var origin: Vector2=s.pos(e); var point:=Vector2(-1,-1)
	for radius in range(0,7):
		var distance: float=INF
		for y in range(floori(origin.y)-radius,floori(origin.y)+radius+1):
			for x in range(floori(origin.x)-radius,floori(origin.x)+radius+1):
				if maxi(absi(x-floori(origin.x)),absi(y-floori(origin.y)))!=radius: continue
				var p:=Vector2(x+0.5,y+0.5)
				if s.walkable(p) and p.distance_squared_to(origin)<distance: point=p; distance=p.distance_squared_to(origin)
		if point.x>=0: break
	if point.x<0:
		var distance: float=INF
		for t in s.fixture.tiles:
			var p:=Vector2(t.x+0.5,t.y+0.5)
			if s.walkable(p) and p.distance_squared_to(origin)<distance: point=p; distance=p.distance_squared_to(origin)
	if point.x<0: return null
	var chest: bool=e.kind=="building" or e.type=="troll"
	if not chest:
		for p in s.loot:
			if not p.dead and not p.chest and s.pos(p)==point:
				p.gold+=amount
				for key in potions: p.potions[key]+=potions[key]
				p.source="Spoils of battle"; return p
	var pile=loot_schema()
	pile.merge({"id":s.next_id,"x":point.x,"y":point.y,"chest":chest,"type":"loot_chest" if chest else "loot_pouch","source":e.site_name if e.kind=="building" else e.name,"gold":amount,"potions":potions},true)
	if s.mission.id=="ember_crown":
		if e.id==s.mission.boss_id: pile.items=["ember_crown"]
		elif e.id==s.mission.encounter_id: pile.items=["runeblade","warden_mail"]
		elif e.kind=="building": pile.items=["iron_blade" if int(s.stats.lairs)%2 else "warden_mail"]
	s.next_id+=1; s.loot.append(pile); s.by_id[pile.id]=pile; return pile
static func usable(s,u,p) -> float:
	var value: float=p.gold
	for key in p.items:
		if s.Equipment.wants(s,u,key): value+=100*s.definitions.items[key].rank
	for key in p.potions: value+=minf(p.potions[key],s.definitions.potions[key].capacity-u.potions[key])*s.definitions.potions[key].price
	return value
static func collect(s,u,p) -> bool:
	if not u.hero or u.dead or p==null or p.dead or not s.loot.has(p) or not s.walkable(s.pos(p)) or u.pos.distance_to(s.pos(p))>0.95: return false
	var a:=Vector2i(u.pos.floor()); var b:=Vector2i(s.pos(p).floor())
	if a.x!=b.x and a.y!=b.y and (not s.walkable(Vector2(a.x,b.y)) or not s.walkable(Vector2(b.x,a.y))): return false
	var gold: float=p.gold; var count: int=0
	u.gold+=gold; p.gold=0
	for key in p.potions:
		var take: int=mini(int(p.potions[key]),int(s.definitions.potions[key].capacity-u.potions[key]))
		u.potions[key]+=take; p.potions[key]-=take; count+=take
	var equipped: int=s.Equipment.collect(s,u,p)
	if gold==0 and count==0 and equipped==0: return false
	s.stats.loot_gold+=gold; s.stats.loot_potions+=count
	if p.items.is_empty() and p.potions.values().all(func(n):return n<=0): p.dead=true; s.stats.loot_caches+=1
	if gold>0: s.fx("gold",u.pos,gold)
	if count>0: s.fx("heal",u.pos)
	if p.chest: s.notify(u.name+" recovered %dg and %d potions."%[gold,count])
	return true
static func seek(s,u) -> bool:
	var choices: Array=[]
	for p in s.loot:
		if p.dead or usable(s,u,p)<=0 or u.pos.distance_to(s.pos(p))>=(14 if u.type=="thief" else 10) or not s.is_visible(s.pos(p)) or not s.walkable(s.pos(p)): continue
		if not s.nearby(s.pos(p),4.5,true).is_empty(): continue
		if s.buildings.any(func(b):return not b.dead and b.hostile and s.pos(b).distance_to(s.pos(p))<3.5): continue
		choices.append(p)
	choices.sort_custom(func(a,b):return usable(s,u,a)/(3+u.pos.distance_to(s.pos(a)))>usable(s,u,b)/(3+u.pos.distance_to(s.pos(b))))
	for p in choices.slice(0,3):
		if collect(s,u,p): u.state="Collecting loot"; u.target=0; u.goal=0; u.loot_target=0; s.stop(u); return true
		if u.loot_target==p.id and u.path_index<u.path.size(): u.state="Recovering treasure"; u.target=0; u.goal=0; return true
		if s.paths_this_tick>=24: s.stats.path_deferrals+=1; break
		s.paths_this_tick+=1; s.stats.paths+=1
		var path: PackedVector2Array=s.find_path(u.pos,s.pos(p))
		if path.is_empty() or path[-1]!=s.pos(p): continue
		u.loot_target=p.id; u.path=path; u.path_index=1 if path.size()>1 else path.size(); u.repath=1.6; u.destination=s.pos(p); u.state="Recovering treasure"; u.target=0; u.goal=0; return true
	if u.loot_target: s.stop(u)
	u.loot_target=0; return false
