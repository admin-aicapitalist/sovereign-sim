extends RefCounted
## Fixed-step game state; rendering consumes events and never advances the rules.
const RunLog = preload("res://scripts/run_log.gd")
var run_log:=RunLog.new()
func log_event(kind: String,data: Dictionary={}) -> void: run_log.add(self,kind,data)
const Actor = preload("res://scripts/actor.gd")
const SeedRng = preload("res://scripts/seed_rng.gd")
const Generator = preload("res://scripts/world_generator.gd")
const Supplies = preload("res://scripts/supplies.gd")
const Magic = preload("res://scripts/magic.gd")
const Brain = preload("res://scripts/brain.gd")
const Sanitation = preload("res://scripts/sanitation.gd")
const Mission = preload("res://scripts/mission.gd")
const Equipment = preload("res://scripts/equipment.gd")
const Content = preload("res://content/catalog.tres")
const Settlement = preload("res://scripts/settlement_rules.gd")
const Shelter = preload("res://scripts/shelter.gd")
const Court = preload("res://scripts/court_economy.gd")
const Journey = preload("res://scripts/journey.gd")
var run: Dictionary = {}
var definitions: Dictionary = Content.definitions()
var mission: Dictionary = Mission.empty()
var fixture: Dictionary = {}
var size: int = 88
var units: Array[Actor] = []
var buildings: Array[Dictionary] = []
var flags: Dictionary = {}
var loot: Array[Dictionary] = []
var actors: Dictionary = {}
var by_id: Dictionary = {}
var buckets: Dictionary = {}
var grid := AStarGrid2D.new()
var rng := SeedRng.new()
var loot_rng := SeedRng.new()
var sanitation_rng := SeedRng.new()
var next_id: int = 1
var gold: float = 1500
var time: float = 0
var economy: float = 0
var staff_timer: float = 0
var vision_timer: float = 0
var troll_spawned: bool = false
var paused: bool = false
var result: String = ""
var message: String = ""
var stats: Dictionary = {}
var alchemy: Dictionary = {"unlocked":{},"project":{}}
var magic: Dictionary = {"unlocked":{},"project":{},"impacts":[]}
var cooldowns: Dictionary = {}
var sanitation: Dictionary = {"timer":0.0,"last_target":0}
var vision: Array = []
var ruins: Array = []
var projectiles: Array = []
var effects: Array = []
var effect_serial: int=0
var events: Array = []
var notifications: Array = []
var paths_this_tick: int = 0
var stress: bool = false
var revision: int = 0
var fog_revision: int = 0

func _init(seed_value: int = 41972) -> void: reset(seed_value)
func notify(text: String, sound: String = "") -> void:
	log_event("notice",{"text":text,"sound":sound})
	message=text; notifications.append({"text":text,"at":time})
	if notifications.size()>4: notifications.pop_front()
	if sound!="": events.append(sound)
func fx(type: String, point: Vector2, value: float=0, life: float=1.2) -> Dictionary:
	effect_serial+=1
	var effect: Dictionary={"type":type,"x":point.x,"y":point.y,"value":value,"started":time,"life":life,"serial":effect_serial}
	if not stress: effects.append(effect)
	return effect
func reset(seed_value: int = -1, configuration: Dictionary = {}) -> void:
	run_log=RunLog.new()
	if not run.is_empty() or not configuration.is_empty(): definitions=Content.definitions()
	run={} if configuration.is_empty() else Settlement.state(configuration)
	if not run.is_empty(): Settlement.apply(definitions,configuration)
	if seed_value<0:
		seed_value=int(Crypto.new().generate_random_bytes(4).decode_u32(0))
		if seed_value==fixture.get("seed",-1): seed_value=(seed_value+1)&0xffffffff
	fixture=Generator.new().generate(seed_value,definitions.campaign)
	units.clear(); buildings.clear(); flags.clear(); loot.clear(); actors.clear(); by_id.clear(); buckets.clear()
	vision.clear(); ruins.clear(); projectiles.clear(); effects.clear(); events.clear(); notifications.clear()
	mission=Mission.empty()
	next_id=1; gold=1500; time=0; economy=0; staff_timer=0; vision_timer=0; paused=false; result=""; stress=false; troll_spawned=false
	rng=SeedRng.new(seed_value); loot_rng=SeedRng.new(seed_value ^ 0xc2b2ae35); sanitation_rng=SeedRng.new(seed_value ^ 0x27d4eb2f)
	alchemy={"unlocked":{},"project":{}}; magic={"unlocked":{},"project":{},"impacts":[]}; sanitation={"timer":0.0,"last_target":0}; cooldowns.clear()
	for key in definitions.spells: cooldowns[key]=0.0
	stats={"hits":0,"kills":0,"slain":0,"losses":0,"paths":0,"decisions":0,"moves":0,"taxes":0.0,"built":0,"recruits":0,"lairs":0,"bounties":0,"potions_bought":0,"potions_used":0,"loot_gold":0,"loot_potions":0,"loot_caches":0,"infestations_cleared":0,"royal_spells":0,"wizard_spells":0,"path_deferrals":0,"equipment_found":0,"upgrades":0,"boss_slams":0}
	rebuild_grid()
	var level: Dictionary=fixture.level
	add_building("palace",Vector2i(level.start.x,level.start.y))
	for p in level.cottages: add_building("house",Vector2i(p.x,p.y))
	fixture.level.rally=point_data(near_point(pos(palace()),3))
	for site in level.lairs:
		var b=add_building(site.type,Vector2i(site.x,site.y))
		b.site_name=site.name; b.dormant=site.get("frontier",false)
		for i in 2: add_unit(definition_of(b).spawn,near_point(pos(b),3),b.id)
	for i in 3: add_unit("peasant",near_point(pos(palace())+Vector2(0,2),3),palace().id)
	for i in 2: add_unit("guard",near_point(pos(palace())+Vector2(2,2),3),palace().id)
	add_unit("collector",near_point(pos(palace())+Vector2(0,2),2),palace().id)
	update_vision(); rebuild_buckets(); notify("Build a guild and invite heroes to your kingdom."); revision+=1
func start_settlement(configuration: Dictionary) -> bool:
	if not Settlement.valid_config(configuration): return false
	reset(int(configuration.seed),configuration)
	gold=configuration.rules.scenario.starting_gold
	Mission.start(self,configuration.scenario)
	return true
func raid_after() -> float:
	return float(run.config.rules.scenario.raid_after) if not run.is_empty() else 110.0
func point_data(point: Vector2) -> Dictionary: return {"x":point.x,"y":point.y}
func pos(e: Variant) -> Vector2: return e.pos if e is Actor else Vector2(e.x,e.y)
func bpos(b: Dictionary) -> Vector2: return pos(b)
func entity(id: int) -> Variant: return by_id.get(id)
func building(id: int) -> Dictionary:
	var e=by_id.get(id)
	return e if e is Dictionary and e.kind=="building" else {}
func palace() -> Dictionary: return buildings[0]
func definition_of(e: Variant) -> Dictionary: return e.definition if e is Actor else definitions.buildings[e.type]
func lairs() -> Array[Dictionary]:
	var found: Array[Dictionary]=[]
	for b in buildings:
		if b.hostile and not b.dead and not b.infestation: found.append(b)
	return found
func operating(type: String) -> Array:
	return buildings.filter(func(b):return not b.dead and not b.hostile and b.progress==1 and (type=="" or b.type==type))
func in_bounds(point: Vector2) -> bool: return point.x>=0 and point.y>=0 and point.x<size and point.y<size
func tile_at(point: Vector2) -> Dictionary: return fixture.tiles[floori(point.y)*size+floori(point.x)] if in_bounds(point) else {}
func is_visible(point: Vector2) -> bool: return in_bounds(point) and tile_at(point).visible
func is_explored(point: Vector2) -> bool: return in_bounds(point) and tile_at(point).explored
func rebuild_grid() -> void:
	grid.region=Rect2i(0,0,size,size); grid.cell_size=Vector2.ONE; grid.offset=Vector2.ONE*0.5
	grid.diagonal_mode=AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic=AStarGrid2D.HEURISTIC_OCTILE; grid.default_estimate_heuristic=AStarGrid2D.HEURISTIC_OCTILE; grid.update()
	for i in fixture.tiles.size():
		var t=fixture.tiles[i]
		grid.set_point_solid(Vector2i(i%size,int(i/size)),t.blocked or t.kind=="water")
func set_foundation(b: Dictionary, solid: bool) -> void:
	for y in range(int(b.ty),int(b.ty+b.size)):
		for x in range(int(b.tx),int(b.tx+b.size)):
			fixture.tiles[y*size+x].blocked=solid; grid.set_point_solid(Vector2i(x,y),solid)
func walkable(point: Vector2) -> bool: return in_bounds(point) and not grid.is_point_solid(Vector2i(point.floor()))
func near_point(point: Vector2, radius: float=2) -> Vector2:
	for i in 40:
		var angle: float=rng.next()*TAU
		var p: Vector2=point+Vector2(cos(angle),sin(angle))*(0.6+rng.next()*radius)
		if walkable(p): return p
	return near_open(point)
func near_open(point: Vector2, radius: int=6) -> Vector2:
	for r in range(1,radius+1):
		for y in range(floori(point.y)-r,floori(point.y)+r+1):
			for x in range(floori(point.x)-r,floori(point.x)+r+1):
				var p:=Vector2(x+0.5,y+0.5)
				if walkable(p): return p
	return point
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	if not in_bounds(to) or not walkable(from): return []
	if not walkable(to):
		var best:=Vector2(-1,-1)
		for r in range(1,5):
			var distance: float=INF
			for y in range(floori(to.y)-r,floori(to.y)+r+1):
				for x in range(floori(to.x)-r,floori(to.x)+r+1):
					var p:=Vector2(x+0.5,y+0.5)
					if walkable(p) and p.distance_squared_to(from)<distance: best=p; distance=p.distance_squared_to(from)
			if best.x>=0: break
		if best.x<0: return []
		to=best
	return grid.get_point_path(Vector2i(from.floor()),Vector2i(to.floor()))
func add_building(type: String, tile: Vector2i, built: bool=true) -> Dictionary:
	var d: Dictionary=definitions.buildings[type]
	var b={"id":next_id,"kind":"building","type":type,"tx":tile.x,"ty":tile.y,"size":d.size,"x":tile.x+d.size/2.0,"y":tile.y+d.size/2.0,
		"hp":d.hp if built else d.hp*0.2,"max_hp":d.hp,"progress":1.0 if built else 0.0,"hostile":d.get("hostile",false),"dead":false,"tax":0.0,
		"spawn":d.interval+rng.next()*12 if d.has("interval") else 0.0,"cooldown":0.0,"last_hit":-100.0,"reinforced":false,"dormant":false,"infestation":false,"demolished":false,"site_name":d.name,"tier":1,"upgrade_remaining":0.0}
	next_id+=1; buildings.append(b); by_id[b.id]=b; set_foundation(b,true)
	fixture.trees=fixture.trees.filter(func(t):return not Rect2(Vector2(tile),Vector2.ONE*d.size).has_point(Vector2(t.x,t.y)))
	revision+=1; return b
func add_unit(type: String, point: Vector2, home: int=0) -> Actor:
	var u:=Actor.new()
	u.id=next_id; next_id+=1; u.type=type; u.pos=point; u.destination=point; u.home=home if home else palace().id
	u.definition=definitions.units[type]; u.hp=u.definition.hp; u.max_hp=u.hp; u.hostile=u.definition.get("hostile",false); u.hero=u.definition.get("hero",false)
	u.max_mana=u.definition.get("mana",0); u.mana=u.max_mana; u.bravery=u.definition.get("bravery",1); u.animation=rng.next()*4
	u.name=definitions.names[type][int(rng.next()*definitions.names[type].size())] if u.hero else u.definition.name
	u.state="Seeking adventure" if u.hero else "On duty"; u.infestation=building(u.home).get("infestation",false)
	Settlement.prepare_unit(self,u)
	if u.hero: Settlement.event(self,"recruit",u)
	Journey.initialize(self,u)
	units.append(u); actors[u.id]=u; by_id[u.id]=u; return u
func can_build(type: String, tile: Vector2i) -> bool:
	if not definitions.buildings.has(type) or type=="palace" or definitions.buildings[type].get("hostile",false) or result!="": return false
	var d: Dictionary=definitions.buildings[type]
	for y in range(tile.y,tile.y+int(d.size)):
		for x in range(tile.x,tile.x+int(d.size)):
			var p:=Vector2(x,y)
			if not walkable(p) or not is_explored(p) or tile_at(p).kind=="bridge": return false
	var center: Vector2=Vector2(tile)+Vector2.ONE*d.size/2.0
	for b in buildings:
		if not b.dead and absf(b.x-center.x)<(b.size+d.size)/2.0+0.35 and absf(b.y-center.y)<(b.size+d.size)/2.0+0.35: return false
	for p in loot:
		if not p.dead and Rect2(Vector2(tile),Vector2.ONE*d.size).has_point(pos(p)): return false
	for u in units:
		if not u.dead and Rect2(Vector2(tile),Vector2.ONE*d.size).has_point(u.pos): return false
	return true
func find_site(type: String) -> Vector2i:
	var choices: Array=fixture.tiles.filter(func(t):return Vector2(t.x,t.y).distance_to(pos(palace()))<10 and can_build(type,Vector2i(t.x,t.y)))
	choices.sort_custom(func(a,b):return Vector2(a.x,a.y).distance_to(pos(palace()))<Vector2(b.x,b.y).distance_to(pos(palace())))
	return Vector2i(choices[0].x,choices[0].y) if not choices.is_empty() else Vector2i(-1,-1)
func build(type: String, tile: Vector2i) -> Dictionary:
	if not can_build(type,tile): notify("Choose clear, explored ground with room around it."); return {}
	var cost: float=definitions.buildings[type].cost
	if gold<cost: notify("The treasury needs more gold."); return {}
	gold-=cost
	var b=add_building(type,tile,false)
	for u in units:
		if u.type=="peasant": u.think=0
	notify("Construction ordered: "+definition_of(b).name,"build"); return b
func recruit(guild_id: int) -> Actor:
	var b=building(guild_id)
	if b.is_empty() or b.dead or b.progress<1 or result!="": return null
	var d: Dictionary=definition_of(b)
	if not d.has("recruits"): return null
	var count: int=units.filter(func(u):return not u.dead and u.hero and u.home==guild_id).size()
	var cost: float=definitions.units[d.recruits].cost
	if count>=guild_capacity(b) or gold<cost: notify("Guild full or insufficient gold."); return null
	gold-=cost
	var u=add_unit(d.recruits,near_point(pos(b),2.5),guild_id)
	u.gold=24; stats.recruits+=1; notify(u.name+" has joined your kingdom.","recruit"); fx("level",u.pos); return u
func guild_capacity(b: Dictionary) -> int:
	var d: Dictionary=definition_of(b)
	return int(d.get("capacity",0))+int(d.get("upgrade_capacity",0) if b.get("tier",1)>1 else 0)
func upgrade(id: int) -> bool:
	var b=building(id)
	if b.is_empty() or b.dead or b.hostile or b.progress<1 or b.tier!=1 or b.upgrade_remaining>0 or result!="": return false
	var d: Dictionary=definition_of(b)
	if d.upgrade_cost<=0 or gold<d.upgrade_cost: return false
	gold-=d.upgrade_cost; b.upgrade_remaining=d.upgrade_time
	notify("Guild training begun. Recruitment remains available.","build"); return true
func update_upgrades(dt: float) -> void:
	for b in buildings:
		if b.dead or b.upgrade_remaining<=0: continue
		b.upgrade_remaining=maxf(0,b.upgrade_remaining-dt)
		if b.upgrade_remaining==0:
			b.tier=2; var gain: float=b.max_hp*0.25; b.max_hp+=gain; b.hp+=gain; stats.upgrades+=1
			fx("upgrade",pos(b),0,1.6); notify(definition_of(b).name+" upgraded: more beds and stronger guild support.","complete")
func demolish(id: int) -> bool:
	var b=building(id)
	if b.is_empty() or b.dead or b.type!="house" or result!="": return false
	b.demolished=true; hurt(b,b.hp+1,null); Sanitation.update(self,0); return true
func place_flag(type: String, point: Vector2, target: int=0, reward: float=100) -> Dictionary:
	if result!="" or reward<=0 or gold<reward or not in_bounds(point) or type not in ["attack","explore"]: return {}
	var e=entity(target)
	if type=="attack" and (e==null or e.dead or e.kind not in ["unit","building"] or not e.hostile): return {}
	if type=="explore" and not walkable(point): return {}
	for f in flags.values():
		if not f.dead and type=="attack" and f.target==target: notify("Select the existing flag to raise its reward."); return {}
	if type=="attack": point=pos(e)
	gold-=reward
	var f={"id":next_id,"kind":"flag","type":type,"x":point.x,"y":point.y,"target":target,"reward":reward,"dead":false}
	next_id+=1; flags[f.id]=f; by_id[f.id]=f
	for u in units:
		if u.hero: u.think=0
	notify("Bounty posted: %dg."%reward,"flag"); return f
func bounty(id: int, reward: float=100) -> bool:
	var e=entity(id)
	return e!=null and not place_flag("attack",pos(e),id,reward).is_empty()
func raise_bounty(id: int, amount: float=50) -> bool:
	var f=flags.get(id)
	if f==null or f.dead or amount<=0 or gold<amount or result!="": return false
	gold-=amount; f.reward+=amount; events.append("coin"); return true
func cancel_bounty(id: int) -> void:
	var f=flags.get(id)
	if f!=null and not f.dead: gold+=f.reward; f.dead=true; notify("Bounty withdrawn. Gold returned.")
func reveal(point: Vector2, radius: float) -> void:
	for y in range(maxi(0,floori(point.y-radius)),mini(size,ceili(point.y+radius)+1)):
		for x in range(maxi(0,floori(point.x-radius)),mini(size,ceili(point.x+radius)+1)):
			if Vector2(x,y).distance_squared_to(point)<radius*radius:
				fixture.tiles[y*size+x].visible=true; fixture.tiles[y*size+x].explored=true
	fog_revision+=1
func update_vision() -> void:
	for t in fixture.tiles: t.visible=stress; t.explored=t.explored or stress
	if stress: fog_revision+=1; return
	for b in buildings:
		if not b.dead and not b.hostile: reveal(pos(b),definition_of(b).get("sight",5))
	for u in units:
		if not u.dead and not u.hostile and u.inside==0: reveal(u.pos,u.definition.sight)
	vision=vision.filter(func(v):return v.until>time)
	for v in vision: reveal(Vector2(v.x,v.y),v.r)
	fog_revision+=1
func rebuild_buckets() -> void:
	buckets.clear()
	for u in units:
		if u.dead or u.inside>0: continue
		var key:=Vector2i(floori(u.pos.x/6),floori(u.pos.y/6))
		if not buckets.has(key): buckets[key]=[]
		buckets[key].append(u)
func nearby(point: Vector2, radius: float, hostile: bool) -> Array:
	var found: Array=[]
	for y in range(floori((point.y-radius)/6),floori((point.y+radius)/6)+1):
		for x in range(floori((point.x-radius)/6),floori((point.x+radius)/6)+1):
			for u in buckets.get(Vector2i(x,y),[]):
				if not u.dead and u.inside==0 and u.hostile==hostile and point.distance_squared_to(u.pos)<radius*radius: found.append(u)
	return found
func nearest(point: Vector2, choices: Array) -> Variant:
	var best=null; var distance: float=INF
	for e in choices:
		var d: float=point.distance_squared_to(pos(e))
		if d<distance: distance=d; best=e
	return best
func go(u: Actor, point: Vector2, state: String) -> void:
	Shelter.leave(self,u)
	u.target=0; u.state=state
	if u.destination.distance_to(point)>0.8: u.repath=0
	u.destination=point
func navigate(u: Actor, dt: float) -> void:
	if u.inside>0: return
	if u.repath<=0 and (u.pos.distance_to(u.destination)>0.5 or u.path_index<u.path.size()):
		if paths_this_tick>=24: stats.path_deferrals+=1
		else:
			paths_this_tick+=1; stats.paths+=1; u.path=find_path(u.pos,u.destination); u.path_index=1 if u.path.size()>1 else u.path.size(); u.repath=1.6
	var remaining: float=u.definition.speed*dt*Magic.move_multiplier(self,u)*(1.25 if u.state=="Fleeing" else 1.0)
	while remaining>0 and u.path_index<u.path.size():
		var point: Vector2=u.path[u.path_index]
		if not walkable(point): u.path=[]; u.repath=0; u.think=0; break
		var delta: Vector2=point-u.pos; var distance: float=delta.length()
		if distance>0.00001:
			u.heading=delta.normalized()
			u.pos+=delta/distance*minf(distance,remaining)
			if absf(delta.x-delta.y)>0.02: u.facing=1 if delta.x-delta.y>0 else -1
			u.animation+=minf(distance,remaining)*8/0.95; stats.moves+=1
		remaining-=distance
		if u.pos.distance_to(point)<0.001: u.path_index+=1
		else: break
func stop(u: Actor) -> void: u.path=[]; u.path_index=0; u.destination=u.pos
func hurt_unit(u: Actor, damage: float) -> void: hurt(u,damage,null)
func hurt_building(b: Dictionary, damage: float) -> void: hurt(b,damage,null)
func hurt(e: Variant, damage: float, attacker: Variant, damage_kind: String="physical") -> void:
	if e==null or e.dead or e is Actor and e.inside>0: return
	var actual: float=maxf(1,damage-(Supplies.armor(self,e) if e is Actor else 0))
	log_event("combat.damage",{"target":e.id,"attacker":attacker.id if attacker!=null else 0,"kind":damage_kind,"amount":actual,"hp_before":e.hp,"hp_after":maxf(0,e.hp-actual),"position":[pos(e).x,pos(e).y]})
	e.hp-=actual; e.last_hit=time; stats.hits+=1
	var impact:=fx("hit",pos(e),actual,0.75)
	impact.target=e.id; impact.element=damage_kind
	impact.armored=e.type in ["warrior","guard","skeleton"] or e.kind=="building"
	impact.warded=e.kind=="unit" and e.magic_buffs.ward>0
	if attacker!=null: impact.origin=[pos(attacker).x,pos(attacker).y]
	if is_visible(pos(e)) and damage_kind in ["physical","arrow"]:
		events.append("shield-hit" if impact.warded else "combat-metal" if impact.armored else "combat-body")
	if e.kind=="building" and e.hostile and not e.reinforced: e.reinforced=true; e.spawn=minf(e.spawn,4)
	if e.hp>0:
		if e is Actor and e.hero: Journey.wounded(self,e)
		return
	log_event("entity.destroyed",{"id":e.id,"type":e.type,"attacker":attacker.id if attacker!=null else 0})
	e.hp=0; e.dead=true; stats.kills+=1; stats["slain" if e.hostile else "losses"]+=1; fx("collapse" if e.kind=="building" else "death",pos(e),0,2.2)
	if e.kind=="building":
		set_foundation(e,false); Shelter.evict(self,e); ruins.append({"x":e.x,"y":e.y,"size":e.size}); revision+=1
		if e.infestation: stats.infestations_cleared+=1; sanitation.timer=0; notify("Rat sewer cleared. Reduce overcrowding to prevent its return.")
		elif e.hostile: gold+=definition_of(e).reward; stats.lairs+=1; notify(e.site_name+" destroyed. Treasure awaits your heroes.","victory")
		elif e.demolished: notify("Cottage dismantled. No gold or stored taxes refunded.")
		else: notify(definition_of(e).name+" has fallen!","danger")
	Mission.killed(self,e)
	Settlement.killed(self,e,attacker)
	Journey.killed(self,e)
	if e.hostile and not e.infestation and not stress: Supplies.drop_loot(self,e)
	if e is Actor and e.hero: Equipment.drop_hero(self,e)
	if attacker is Actor and attacker.hero and not attacker.dead and e.hostile and not e.infestation:
		grant_experience(attacker,definition_of(e).get("xp",60))
	if e is Actor and e.hero: notify(e.name+" has fallen.","danger")
	for f in flags.values():
		if f.dead or f.target!=e.id: continue
		f.dead=true
		var claimants: Array=units.filter(func(u):return u.hero and not u.dead and u.pos.distance_to(pos(e))<12)
		if claimants.is_empty(): gold+=f.reward
		else:
			for u in claimants: u.gold+=f.reward/claimants.size()
		log_event("economy.bounty_paid",{"bounty":f.id,"target":e.id,"reward":f.reward,"heroes":claimants.map(func(u):return u.id),"refunded":claimants.is_empty()})
		stats.bounties+=1
func attack(u: Actor, e: Variant) -> void:
	if u.inside>0 or e is Actor and e.inside>0: u.target=0; return
	var reach: float=u.definition.range+(e.size*0.45 if e.kind=="building" else 0)
	if u.pos.distance_to(pos(e))>reach: u.destination=pos(e); return
	stop(u); Supplies.combat_potions(self,u,e); u.facing=1 if (pos(e).x-u.pos.x)-(pos(e).y-u.pos.y)>0 else -1
	if pos(e).distance_squared_to(u.pos)>0.00001: u.heading=(pos(e)-u.pos).normalized()
	if u.cooldown>0: return
	u.cooldown=u.definition.rate/Magic.attack_multiplier(self,u); u.attacking=0.34
	if mission.id=="ember_crown":
		u.pending_attack={"target":e.id,"remaining":0.24 if u.definition.range<=2 else 0.36,"duration":0.24 if u.definition.range<=2 else 0.36}
		u.attacking=float(u.pending_attack.duration)+0.2; return
	resolve_attack(u,e)
func grant_experience(hero: Actor,amount: float) -> void:
	if not hero.hero or hero.dead or amount<=0: return
	hero.xp+=amount
	while hero.xp>=hero.level*45:
		hero.xp-=hero.level*45; hero.level+=1; hero.max_hp+=22; hero.hp=minf(hero.max_hp,hero.hp+60)
		Settlement.event(self,"level",hero,str(hero.level))
		fx("level",hero.pos); notify(hero.name+" reached level %d."%hero.level,"level")
func resolve_attack(u: Actor,e: Variant) -> void:
	if e==null or e.dead or u.dead or u.inside>0 or e is Actor and e.inside>0: return
	var reach: float=u.definition.range+(e.size*0.45 if e.kind=="building" else 0)
	if u.pos.distance_to(pos(e))>reach+0.5: return
	var amount: float=Supplies.damage(self,u,e)
	if u.definition.range>2: shoot(u,e,amount,"fireball" if u.type=="wizard" else "arrow")
	else:
		var swing:=fx("swing",u.pos,0,0.32)
		swing.origin=[pos(e).x,pos(e).y]; swing.target=u.id; swing.weapon=u.type
		hurt(e,amount,u)
func shoot(attacker: Variant, e: Variant, damage: float, type: String) -> void:
	var point: Vector2=pos(attacker)
	projectiles.append({"x":point.x,"y":point.y,"target":e.id,"attacker":attacker.id,"damage":damage,"type":type,"speed":11 if type=="fireball" else 19,"life":2.0,"origin":[point.x,point.y],"started":time})
	if is_visible(point): events.append("fire" if type=="fireball" else "bow")
func update_projectiles(dt: float) -> void:
	var keep: Array=[]
	for p in projectiles:
		var e=entity(p.target); var attacker=entity(p.attacker); p.life-=dt
		if e==null or e.dead or p.life<=0 or e is Actor and e.inside>0: continue
		var point:=Vector2(p.x,p.y); var destination: Vector2=pos(e)
		var distance: float=point.distance_to(destination); var step: float=p.speed*dt
		if distance<step+0.3:
			hurt(e,p.damage,attacker,p.type)
			if p.type=="fireball":
				fx("fire",destination,0,0.9)
				if is_visible(destination): events.append("fire-impact")
				for other in nearby(destination,1.6,e.hostile):
					if other.id!=e.id: hurt(other,p.damage*0.35,attacker,"fireball")
		else:
			point=point.move_toward(destination,step); p.x=point.x; p.y=point.y; keep.append(p)
	projectiles=keep
func tick(dt: float) -> void:
	if paused or result!="": return
	time+=dt; paths_this_tick=0; rebuild_buckets()
	for key in cooldowns: cooldowns[key]=maxf(0,cooldowns[key]-dt)
	Supplies.update_research(self,dt); Magic.update(self,dt); update_upgrades(dt); Mission.update(self,dt)
	for u in units:
		if u.dead: continue
		Supplies.update_unit(self,u,dt); Magic.update_unit(self,u,dt)
		if u.inside>0 and building(u.inside).type in ["inn","brothel"]: u.hp=minf(u.max_hp,u.hp+2*dt)
		if u.definition.has("regeneration") and time-u.last_hit>6: u.hp=minf(u.max_hp,u.hp+u.definition.regeneration*dt)
		u.think-=dt; u.cooldown-=dt; u.repath-=dt; u.attacking=maxf(0,u.attacking-dt)
		if u.id==mission.boss_id and mission.slam_remaining>0: stop(u); continue
		if not u.pending_attack.is_empty():
			u.pending_attack.remaining=maxf(0,u.pending_attack.remaining-dt)
			if u.pending_attack.remaining==0:
				resolve_attack(u,entity(int(u.pending_attack.target))); u.pending_attack={}
			else: stop(u); continue
		if u.think<=0:
			stats.decisions+=1; Brain.think(self,u)
			if u.type=="wizard": Magic.think(self,u)
			run_log.decision(self,u)
			u.think=0.55+rng.next()*0.35
		var e=entity(u.target)
		if e!=null and not e.dead and u.state not in ["Fleeing","Resting"]: attack(u,e)
		navigate(u,dt)
		if not u.hostile and time-u.last_hit>8 and u.pos.distance_to(pos(palace()))<7: u.hp=minf(u.max_hp,u.hp+dt*(2.2 if u.hero else 3))
	update_projectiles(dt)
	for b in buildings:
		if b.dead or b.progress<1: continue
		var d: Dictionary=definition_of(b)
		if b.type=="tower":
			b.cooldown-=dt
			if b.cooldown<=0:
				var e=nearest(pos(b),nearby(pos(b),d.range,true))
				if e!=null: shoot(b,e,d.damage,"arrow"); b.cooldown=d.attackRate
		if not b.hostile or stress: continue
		if b.dormant:
			if not is_explored(pos(b)) and b.hp==b.max_hp: continue
			b.dormant=false; b.spawn=d.interval; notify(b.site_name+" stirs in the frontier.","danger")
		b.spawn-=dt
		if b.spawn<=0:
			b.spawn=definitions.sanitation.ratInterval if b.infestation else d.interval*maxf(0.65,1-time/2400)
			if units.filter(func(u):return not u.dead and u.hostile and u.home==b.id).size()<6:
				var u=add_unit(d.spawn,near_point(pos(b),2.7),b.id); u.raider=b.infestation or time>raid_after() and rng.next()<0.72
	if not stress: Sanitation.update(self,dt)
	economy+=dt
	if economy>=10:
		economy-=10
		for b in operating(""):
			var tax: float=definition_of(b).get("tax",0)
			if b.type=="palace": gold+=tax; stats.taxes+=tax
			else: b.tax+=tax
	staff_timer+=dt
	if staff_timer>40 and not stress and not palace().dead:
		staff_timer=0
		for type in ["peasant","collector","guard"]:
			var count: int=units.filter(func(u):return not u.dead and u.type==type).size()
			if count<(3 if type=="peasant" else 2 if type=="guard" else 1): add_unit(type,near_point(pos(palace()),4),palace().id)
	if time>=600 and not troll_spawned and not stress and run.is_empty():
		troll_spawned=true; add_unit("troll",near_point(Vector2(fixture.level.trollEntry.x,fixture.level.trollEntry.y),3)); notify("A Hill Troll approaches from the borderlands!","danger")
	vision_timer+=dt
	if vision_timer>=0.6: vision_timer=0; update_vision()
	for f in flags.values():
		if not f.dead and f.target:
			var e=entity(f.target)
			if e!=null:
				var p: Vector2=pos(e); f.x=p.x; f.y=p.y
	run_log.observe(self) # Capture consumed loot and flags before cleanup.
	if units.size()>160:
		for u in units:
			if u.dead: actors.erase(u.id); by_id.erase(u.id)
		units.assign(units.filter(func(u):return not u.dead))
	for pile in loot:
		if pile.dead: by_id.erase(pile.id)
	loot.assign(loot.filter(func(p):return not p.dead))
	for id in flags.keys():
		if flags[id].dead: by_id.erase(id); flags.erase(id)
	effects=effects.filter(func(e):return time-e.started<e.life)
	if not stress:
		if palace().dead: result="defeat"
		elif (not run.is_empty() and mission.boss_defeated) or (run.is_empty() and lairs().is_empty() and (mission.id=="classic" or mission.boss_defeated)): result="victory"
	if result!="":
		events.append("victory" if result=="victory" else "danger"); run_log.observe(self)
func setup_stress(count: int) -> void:
	reset(41972); stress=true
	for u in units: by_id.erase(u.id)
	units.clear(); actors.clear(); place_flag("attack",pos(lairs()[0]),lairs()[0].id,500)
	var open: Array=[]
	for i in fixture.tiles.size():
		var p:=Vector2(i%size+0.5,int(i/size)+0.5)
		if walkable(p): open.append(p)
	for i in count:
		var u=add_unit("goblin" if i%3==0 else "warrior",open[rng.integer(0,open.size()-1)],palace().id); u.hp=1000000; u.max_hp=u.hp; u.raider=true
	for b in buildings: b.hp=1000000000; b.max_hp=b.hp
	update_vision(); rebuild_buckets(); message="Crowd test: %d actors"%count

const SAVE_FIELDS=["fixture","next_id","time","gold","economy","staff_timer","vision_timer","troll_spawned","paused","result","stress","stats","alchemy","magic","cooldowns","sanitation","vision","ruins","projectiles","effects","mission"]
func snapshot() -> Dictionary:
	var out: Dictionary={"version":3,"rng":rng.state,"loot_rng":loot_rng.state,"sanitation_rng":sanitation_rng.state,"buildings":buildings.duplicate(true),"units":[],"flags":flags.values().duplicate(true),"loot":loot.duplicate(true)}
	for key in SAVE_FIELDS:
		var value=get(key); out[key]=value.duplicate(true) if value is Dictionary or value is Array else value
	for u in units: out.units.append(u.save())
	if not run.is_empty(): out.version=4; out.run=run.duplicate(true)
	return out
func restore(input: Dictionary) -> bool:
	var data: Dictionary=input.duplicate(true)
	var restored_run: Dictionary={}
	if data.get("version")==4:
		if not Settlement.valid_state(data.get("run")) or data.run.is_empty(): return false
		if not data.get("mission") is Dictionary or not data.get("fixture") is Dictionary: return false
		restored_run=data.run.duplicate(true); data.version=3
		if data.get("mission",{}).get("id")!=restored_run.config.scenario or data.get("fixture",{}).get("seed")!=restored_run.config.seed: return false
	elif data.has("run"): return false
	if data.get("version",0)==2:
		if not data.get("stats") is Dictionary or not data.get("units") is Array or not data.get("buildings") is Array or not data.get("loot") is Array: return false
		data.version=3; data.mission=Mission.empty()
		for item in data.get("units",[]):
			if not item is Dictionary: return false
			item.equipment={}; item.pending_attack={}
		for b in data.get("buildings",[]):
			if not b is Dictionary: return false
			b.tier=1; b.upgrade_remaining=0.0
		for p in data.get("loot",[]):
			if not p is Dictionary: return false
			p.items=[]
		for key in ["equipment_found","upgrades","boss_slams"]: data.stats[key]=0
	var schema: Dictionary=snapshot()
	schema.version=3; schema.erase("run")
	schema.alchemy={"unlocked":{},"project":{}}
	schema.magic={"unlocked":{},"project":{},"impacts":[]}
	schema.mission=Mission.empty()
	if data.get("version",0)!=3 or not shape(data,schema): return false
	if data.fixture.get("size")!=size or data.fixture.get("tiles",[]).size()!=size*size or data.buildings.is_empty(): return false
	if not validate_collections(data): return false
	if restored_run.has("court") and not Court.valid(restored_run.court,data.next_id,data.time,data.buildings): return false
	var actor_schema: Dictionary=Actor.new().save(); var ids: Dictionary={}
	actor_schema.erase("heading") # Optional in version 3 saves made before directional casting.
	actor_schema.erase("journey") # Earlier saves did not track narrative journeys.
	actor_schema.erase("inside") # Earlier saves kept resting heroes outside.
	for i in data.fixture.tiles.size():
		var t=data.fixture.tiles[i]
		if not shape(t,fixture.tiles[0]) or t.kind not in ["grass","path","water","bridge"] or t.x!=i%size or t.y!=int(i/size): return false
	for b in data.buildings:
		if not shape(b,palace()) or not definitions.buildings.has(b.type) or not valid_id(b.id,data.next_id,ids): return false
		if b.kind!="building" or not valid_point([b.x,b.y]) or b.progress<0 or b.progress>1 or b.size!=definitions.buildings[b.type].size or b.tx<0 or b.ty<0 or b.tx+b.size>size or b.ty+b.size>size or b.max_hp<=0: return false
	if data.buildings[0].type!="palace": return false
	if data.mission.id not in ["classic","ember_crown"] or data.mission.slam_remaining<0 or data.mission.special_cooldown<0 or data.mission.arrival_remaining<0: return false
	if data.mission.id=="ember_crown":
		if not data.buildings.any(func(b):return b.id==data.mission.encounter_id and b.type=="graveyard"): return false
		if data.mission.boss_id and not data.mission.boss_defeated and not data.units.any(func(u):return u is Dictionary and u.get("id")==data.mission.boss_id and u.get("type")=="troll"): return false
		if not valid_point([data.mission.slam_x,data.mission.slam_y]): return false
	for b in data.buildings:
		if (b.tier!=1 and b.tier!=2) or b.upgrade_remaining<0 or (b.tier==2 and b.upgrade_remaining>0): return false
	for item in data.units:
		if not shape(item,actor_schema) or not definitions.units.has(item.type) or not valid_id(item.id,data.next_id,ids): return false
		if not Shelter.valid(item.get("inside",0),item,data): return false
		if not Journey.valid(item.get("journey",{})): return false
		if not item.get("journey",{}).is_empty() and (restored_run.is_empty() or not item.hero): return false
		if not item.get("journey",{}).is_empty():
			var journey: Dictionary=item.journey
			if journey.entered>data.time or journey.returned>data.time or journey.calling>=data.next_id or journey.target>=data.next_id: return false
			if journey.history.any(func(event):return event.at>data.time): return false
			if journey.version==2:
				if journey.shadow_since>data.time or journey.recovery_at>data.time or journey.recovery_site>=data.next_id or journey.leisure_place>=data.next_id: return false
				if journey.leisure_until>data.time+18.01 or journey.leisure_next>data.time+30.01 or journey.theft_ready>data.time+Court.THEFT_COOLDOWN+0.01: return false
				if journey.recovery_site>0 and not data.buildings.any(func(b):return b.id==journey.recovery_site and b.type==("temple" if item.type=="wizard" else {"warrior":"warriors","ranger":"rangers","thief":"thieves"}.get(item.type,""))): return false
		if item.has("heading"):
			if not item.heading is Array or item.heading.size()!=2 or not finite_number(item.heading[0]) or not finite_number(item.heading[1]): return false
			if absf(item.heading[0])>1.001 or absf(item.heading[1])>1.001: return false
		if item.kind!="unit" or not keyed_values(item.potions,definitions.potions,TYPE_FLOAT) or not keyed_values(item.buffs,{"strength":0,"stoneskin":0},TYPE_FLOAT) or not keyed_values(item.magic_buffs,{"ward":0,"haste":0,"frost":0},TYPE_FLOAT) or not keyed_values(item.spell_cooldowns,definitions.spells,TYPE_FLOAT): return false
		if not item.last_spell.is_empty() and (not shape(item.last_spell,{"key":"","at":0.0}) or not definitions.spells.has(item.last_spell.key)): return false
		if not valid_point(item.pos) or not valid_point(item.destination) or item.max_hp<=0 or item.path_index<0 or item.path_index>item.path.size(): return false
		for slot in item.equipment:
			var key=item.equipment[slot]
			if not key is String or not definitions.items.has(key) or definitions.items[key].slot!=slot: return false
		if not item.pending_attack.is_empty() and (not shape(item.pending_attack,{"target":0,"remaining":0.0,"duration":0.0}) or item.pending_attack.remaining<0 or item.pending_attack.duration<=0): return false
		for p in item.path:
			if not valid_point(p): return false
	for f in data.flags:
		if not shape(f,{"id":0,"kind":"flag","type":"attack","x":0.0,"y":0.0,"target":0,"reward":0.0,"dead":false}) or not valid_id(f.id,data.next_id,ids) or f.reward<0 or f.kind!="flag" or f.type not in ["attack","explore"] or not valid_point([f.x,f.y]): return false
	for p in data.loot:
		if not shape(p,Supplies.loot_schema()) or not valid_id(p.id,data.next_id,ids) or p.kind!="loot" or p.type not in ["loot_chest","loot_pouch"] or not valid_point([p.x,p.y]) or not keyed_values(p.potions,definitions.potions,TYPE_FLOAT): return false
	for p in data.loot:
		for key in p.items:
			if not key is String or not definitions.items.has(key): return false
	if data.gold<0 or data.time<0 or data.result not in ["","victory","defeat","abandoned"]: return false
	if data.result=="abandoned" and restored_run.is_empty(): return false
	run_log=RunLog.new()
	run=restored_run; definitions=Content.definitions()
	if not run.is_empty(): Settlement.apply(definitions,run.config)
	for key in SAVE_FIELDS: set(key,data[key].duplicate(true) if data[key] is Dictionary or data[key] is Array else data[key])
	for effect in effects: effect_serial=maxi(effect_serial,int(effect.get("serial",0)))
	rng.state=int(data.rng); loot_rng.state=int(data.loot_rng); sanitation_rng.state=int(data.sanitation_rng)
	units.clear(); actors.clear(); buildings.assign(data.buildings.duplicate(true)); loot.assign(data.loot.duplicate(true)); flags.clear(); by_id.clear()
	for b in buildings: by_id[int(b.id)]=b
	for p in loot: by_id[int(p.id)]=p
	for f in data.flags: flags[int(f.id)]=f.duplicate(true); by_id[int(f.id)]=flags[int(f.id)]
	for item in data.units:
		var u:=Actor.new()
		for key in Actor.FIELDS: u.set(key,item[key])
		u.inside=int(item.get("inside",0))
		u.journey=item.get("journey",{}).duplicate(true)
		u.pos=Vector2(item.pos[0],item.pos[1]); u.destination=Vector2(item.destination[0],item.destination[1])
		for p in item.path: u.path.append(Vector2(p[0],p[1]))
		u.definition=definitions.units[u.type]
		Settlement.prepare_unit(self,u,true)
		u.heading=Vector2(u.facing,0)
		if u.path_index<u.path.size(): u.heading=(u.path[u.path_index]-u.pos).normalized()
		if item.has("heading"): u.heading=Vector2(item.heading[0],item.heading[1])
		if u.id==mission.boss_id: Mission.apply_boss(self,u)
		Journey.initialize(self,u,true)
		units.append(u); actors[u.id]=u; by_id[u.id]=u
	rebuild_grid(); rebuild_buckets(); revision+=1; fog_revision+=1; notifications.clear(); events.clear(); notify("Kingdom restored."); return true
# Validate every variable-length collection before mutating the live kingdom.
func keyed_values(value: Dictionary, allowed: Dictionary, type: int) -> bool:
	for key in value:
		if not allowed.has(key): return false
		if type==TYPE_FLOAT:
			if not finite_number(value[key]) or value[key]<0: return false
		elif typeof(value[key])!=type: return false
	return true
func validate_collections(data: Dictionary) -> bool:
	for pair in [[data.alchemy,definitions.potions],[data.magic,definitions.spells]]:
		if not keyed_values(pair[0].unlocked,pair[1],TYPE_BOOL): return false
		var project=pair[0].project
		if not project.is_empty() and (not shape(project,{"key":"","remaining":0.0,"total":0.0}) or not pair[1].has(project.key) or project.remaining<0 or project.total<=0): return false
	if not keyed_values(data.cooldowns,definitions.spells,TYPE_FLOAT): return false
	var collections=[
		[data.fixture.trees,{"x":0.0,"y":0.0,"type":"","scale":1.0}],
		[data.fixture.decor,{"x":0.0,"y":0.0,"type":"","seed":0.0}],
		[data.fixture.level.bridges,{"x":0.0,"y":0.0,"axis":""}],
		[data.magic.impacts,{"x":0.0,"y":0.0,"caster":0,"at":0.0}],
		[data.vision,{"x":0.0,"y":0.0,"r":0.0,"until":0.0}],
		[data.ruins,{"x":0.0,"y":0.0,"size":0.0}],
		[data.projectiles,{"x":0.0,"y":0.0,"target":0,"attacker":0,"damage":0.0,"type":"","speed":0.0,"life":0.0}],
		[data.effects,{"x":0.0,"y":0.0,"type":"","value":0.0,"started":0.0,"life":0.0}]]
	for pair in collections:
		for item in pair[0]:
			if not shape(item,pair[1]) or not valid_point([item.x,item.y]): return false
	for tree in data.fixture.trees:
		if tree.type not in ["pine0","pine1","pine2","pine3","pine4","pine5","oak0","oak1","oak2","oak3","oak4","oak5"] or tree.scale<=0: return false
	for effect in data.effects:
		if effect.life<=0 or effect.type.begins_with("spell_") and not definitions.spells.has(effect.type.trim_prefix("spell_")): return false
		if not valid_visual(effect): return false
	for projectile in data.projectiles:
		if projectile.type not in ["arrow","fireball"] or projectile.life<=0 or projectile.speed<=0: return false
		if not valid_visual(projectile): return false
	return true
func valid_visual(item: Dictionary) -> bool:
	# Optional presentation data keeps old saves readable and rejects malformed new data.
	for key in ["serial","target","caster","started","radius","delay"]:
		if item.has(key) and not finite_number(item[key]): return false
	for key in ["serial","target","caster"]:
		if item.has(key) and (item[key]<0 or item[key]>1e12 or item[key]!=floorf(item[key])): return false
	if item.has("radius") and (item.radius<=0 or item.radius>size): return false
	if item.has("delay") and (item.delay<=0 or item.delay>60): return false
	for key in ["armored","warded"]:
		if item.has(key) and not item[key] is bool: return false
	for key in ["element","weapon"]:
		if item.has(key) and not item[key] is String: return false
	if item.has("origin") and not valid_point(item.origin): return false
	if item.has("targets"):
		if not item.targets is Array or item.targets.size()>64: return false
		for target in item.targets:
			if not shape(target,{"id":0,"x":0.0,"y":0.0}) or not valid_point([target.x,target.y]): return false
			if target.id<=0 or target.id>1e12 or target.id!=floorf(target.id): return false
	return true
func valid_id(value: Variant, next: float, ids: Dictionary) -> bool:
	if value<=0 or value>=next or value!=int(value) or ids.has(int(value)): return false
	ids[int(value)]=true; return true
func valid_point(value: Variant) -> bool: return value is Array and value.size()==2 and finite_number(value[0]) and finite_number(value[1]) and in_bounds(Vector2(value[0],value[1]))
func finite_number(value: Variant) -> bool: return (value is int or value is float) and is_finite(value)
func shape(value: Variant, sample: Variant) -> bool:
	if sample is Dictionary:
		if not value is Dictionary: return false
		for key in sample:
			if not value.has(key) or not shape(value[key],sample[key]): return false
		return true
	if sample is int or sample is float: return finite_number(value)
	return typeof(value)==typeof(sample)
