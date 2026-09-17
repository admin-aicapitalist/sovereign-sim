extends RefCounted
## Diagnostic history, independent of saves, presentation and gameplay RNG.
var enabled: bool=false
var run_id: String=""
var segment: String=""
var pending: Array=[]
var sequence: int=0
var actors: Dictionary={}
var buildings: Dictionary={}
var flags: Dictionary={}
var loot: Dictionary={}
var kingdom: Dictionary={}
var next_sample: float=0
var ended: bool=false
func begin(s,origin: String="new") -> void:
	enabled=true; run_id=s.run.get("config",{}).get("id",Crypto.new().generate_random_bytes(16).hex_encode())
	segment=Crypto.new().generate_random_bytes(8).hex_encode(); next_sample=s.time
	add(s,"run."+origin,{"checkpoint":s.snapshot(),"definitions":s.definitions,"engine":Engine.get_version_info().string,"schema":1,"wall_time_utc":Time.get_datetime_string_from_system(true)})
	observe(s)
func add(s,kind: String,data: Dictionary={}) -> void:
	if not enabled: return
	sequence+=1
	pending.append({"seq":sequence,"segment":segment,"time":snappedf(s.time,0.001),"event":kind,"data":data.duplicate(true)})
func changes(s,kind: String,id: int,current: Dictionary,previous: Dictionary) -> void:
	if not previous.has(id): add(s,kind+".created",current)
	elif previous[id]!=current:
		var changed: Dictionary={}; var before: Dictionary={}
		for key in current:
			if previous[id].get(key)!=current[key]: changed[key]=current[key]; before[key]=previous[id].get(key)
		add(s,kind+".changed",{"id":id,"before":before,"after":changed})
	if not previous.has(id) or previous[id]!=current: previous[id]=current.duplicate(true)
func decision(s,u) -> void:
	if not enabled: return
	var data: Dictionary={"id":u.id,"type":u.type,"state":u.state,"target":u.target,"goal":u.goal,"inside":u.inside,"position":[u.pos.x,u.pos.y],"destination":[u.destination.x,u.destination.y],"hp":u.hp,"max_hp":u.max_hp}
	if u.hero and not u.journey.is_empty():
		data.aspect=u.journey.aspect; data.stage=u.journey.stage
		if u.journey.stage in ["call","refusal"]: data.support=s.Journey.gates(s,u)
	add(s,"actor.decision",data)
func observe(s) -> void:
	if not enabled: return
	for u in s.units:
		var current={"id":u.id,"type":u.type,"name":u.name,"home":u.home,"hero":u.hero,"hostile":u.hostile,"raider":u.raider,"dead":u.dead,"state":u.state,"target":u.target,"goal":u.goal,"inside":u.inside,"gold":u.gold,"carried":u.carried,"level":u.level,"xp":u.xp,"max_hp":u.max_hp,"equipment":u.equipment,"potions":u.potions,"last_spell":u.last_spell}
		changes(s,"actor",u.id,current,actors)
	for b in s.buildings:
		changes(s,"building",b.id,{"id":b.id,"type":b.type,"name":b.site_name,"x":b.x,"y":b.y,"hostile":b.hostile,"dead":b.dead,"complete":b.progress>=1,"dormant":b.dormant,"tier":b.tier,"tax":b.tax,"upgrading":b.upgrade_remaining>0},buildings)
	for f in s.flags.values():
		var flag: Dictionary=f.duplicate(); flag.erase("x"); flag.erase("y")
		changes(s,"bounty",f.id,flag,flags)
	for p in s.loot: changes(s,"loot",p.id,p,loot)
	var current={"gold":s.gold,"result":s.result,"paused":s.paused,"research":{"potions":s.alchemy.unlocked,"spells":s.magic.unlocked,"potion_project":s.alchemy.project.get("key",""),"spell_project":s.magic.project.get("key","")},"mission":{"revealed":s.mission.revealed,"monastery_cleared":s.mission.encounter_cleared,"boss_id":s.mission.boss_id,"enraged":s.mission.enraged,"boss_defeated":s.mission.boss_defeated},"court":s.run.get("court",{})}
	changes(s,"kingdom",0,current,kingdom)
	if s.time>=next_sample:
		next_sample=s.time+5
		var cast: Array=[]
		for u in s.units:
			if not u.dead: cast.append({"id":u.id,"position":[u.pos.x,u.pos.y],"hp":u.hp,"mana":u.mana,"state":u.state,"inside":u.inside,"path_remaining":maxi(0,u.path.size()-u.path_index),"journey":journey_state(u) if u.hero else {}})
		add(s,"world.sample",{"actors":cast,"buildings":s.buildings.map(func(b):return {"id":b.id,"hp":b.hp,"progress":b.progress,"next_spawn":b.spawn}),"gold":s.gold,"rng":s.rng.state,"stats":s.stats,"boss_arrival_remaining":s.mission.arrival_remaining})
	if s.result!="" and not ended:
		ended=true; add(s,"run.ended",{"result":s.result,"record":s.Settlement.record(s) if not s.run.is_empty() else {},"checkpoint":s.snapshot()})
func journey_state(u) -> Dictionary:
	var state: Dictionary=u.journey.duplicate(); state.erase("history"); return state
func batch(s) -> Dictionary:
	if pending.is_empty(): return {}
	return {"run_id":run_id,"seed":s.fixture.seed,"scenario":s.mission.id,"condition":s.run.get("config",{}).get("condition","legacy"),"outcome":s.result,"game_time":s.time,"events":pending.duplicate(true)}
