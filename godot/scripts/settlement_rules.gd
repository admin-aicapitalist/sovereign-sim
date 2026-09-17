extends RefCounted
## Run rules and factual records. No rendering or profile persistence dependencies.
static func content() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://content/settlements.json"))
static func config(seed_value: int, charter: String="crown", condition: String="untroubled") -> Dictionary:
	var data=content()
	return {"version":1,"content_version":data.version,"id":Crypto.new().generate_random_bytes(16).hex_encode(),"seed":seed_value,"scenario":"ember_crown","charter":charter,"condition":condition,"rules":{"scenario":data.scenario.duplicate(true),"charter":data.charters[charter].duplicate(true),"condition":data.conditions[condition].duplicate(true),"rewards":data.rewards.duplicate(true)}}
static func valid_config(c: Variant) -> bool:
	if not c is Dictionary or c.get("version")!=1 or c.get("content_version")!=1: return false
	if not c.get("id") is String or c.id.length()!=32 or not c.id.is_valid_hex_number(): return false
	if not number(c.get("seed")) or c.seed<0 or c.seed>4294967295 or c.seed!=floorf(c.seed): return false
	var data=content()
	if c.get("scenario")!="ember_crown" or not data.charters.has(c.get("charter")) or not data.conditions.has(c.get("condition")): return false
	# Validate the saved rule shape, then honor its resolved values. Balance or copy
	# edits must not silently change a settlement that is already in progress.
	var expected={"scenario":data.scenario,"charter":data.charters[c.charter],"condition":data.conditions[c.condition],"rewards":data.rewards}
	if not c.get("rules") is Dictionary: return false
	for section in expected:
		if not c.rules.get(section) is Dictionary: return false
		for key in expected[section]:
			var value=c.rules[section].get(key)
			if expected[section][key] is String:
				if not value is String or value.length()>2048: return false
			elif not number(value) or value<0 or value>10000: return false
	for key in ["guild_cost","tax"]:
		if c.rules.charter[key]<=0 or c.rules.charter[key]>10: return false
	for key in ["frontier_hp","frontier_gold"]:
		if c.rules.condition[key]<=0 or c.rules.condition[key]>10: return false
	if c.rules.scenario.slam_warning<=0: return false
	return c.rules.rewards==data.rewards
static func number(n: Variant) -> bool:
	return (n is int or n is float) and is_finite(n)
static func state(c: Dictionary) -> Dictionary:
	return {"config":c.duplicate(true),"heroes":{},"events":[],"final_attack":""}
static func apply(definitions: Dictionary, c: Dictionary) -> void:
	var rules=c.rules
	for key in definitions.buildings:
		var b: Dictionary=definitions.buildings[key]
		if b.has("recruits"): b.cost=ceili(b.cost*rules.charter.guild_cost)
		if b.has("tax"): b.tax*=rules.charter.tax
	definitions.mission.name=rules.scenario.name
	definitions.mission.description=rules.scenario.description
	definitions.mission.arrival_delay=rules.scenario.arrival_delay
	definitions.mission.slam_warning=rules.scenario.slam_warning
static func frontier(s, id: int) -> bool:
	var b=s.building(id)
	return not b.is_empty() and s.fixture.level.lairs.any(func(site):return site.get("frontier",false) and site.x==b.tx and site.y==b.ty)
static func prepare_unit(s,u, restoring: bool=false) -> void:
	if s.run.is_empty() or not u.hostile or not frontier(s,u.home): return
	var multiplier: float=s.run.config.rules.condition.frontier_hp
	u.definition=u.definition.duplicate(true); u.definition.hp*=multiplier
	if not restoring: u.max_hp=u.definition.hp; u.hp=u.max_hp
static func event(s, kind: String, hero=null, detail: String="") -> void:
	if s.run.is_empty(): return
	var record={"at":s.time,"kind":kind,"hero":hero.id if hero!=null else 0,"name":hero.name if hero!=null else "","detail":detail}
	s.run.events.append(record)
	if s.run.events.size()>96: s.run.events.pop_front()
	if hero!=null:
		var key=str(hero.id)
		if not s.run.heroes.has(key): s.run.heroes[key]={"name":hero.name,"type":hero.type,"level":hero.level,"dead":false,"lairs":0,"boss":false,"equipment":[],"last":"Joined the settlement"}
		var h: Dictionary=s.run.heroes[key]
		h.level=hero.level; h.dead=hero.dead
		if kind=="lair": h.lairs+=1; h.last="Helped defeat "+detail
		elif kind=="boss": h.boss=true; h.last="Helped defeat the Ember Warlord"
		elif kind=="equipment":
			if not h.equipment.has(detail): h.equipment.append(detail)
			h.last="Equipped "+detail
		elif kind=="death": h.last="Fell at level %d"%hero.level
		elif kind=="level": h.last="Reached level "+detail
		elif kind=="explore": h.last="Claimed an exploration bounty"
static func killed(s,e,attacker) -> void:
	if s.run.is_empty(): return
	if e.id==s.palace().id: s.run.final_attack=attacker.name if attacker!=null and attacker is Object else s.definition_of(attacker).name if attacker!=null else "The Palace was destroyed"
	if e is Object and e.hero: event(s,"death",e)
	if e.kind=="building" and e.hostile and not e.infestation or e.id==s.mission.boss_id:
		# Participation means being alive and within the same radius used for bounty payouts.
		for hero in s.units:
			if hero.hero and not hero.dead and hero.pos.distance_to(s.pos(e))<12:
				event(s,"boss" if e.id==s.mission.boss_id else "lair",hero,e.site_name if e.kind=="building" else e.name)
static func record(s) -> Dictionary:
	if s.run.is_empty() or s.result=="": return {}
	var cleared: Array=[]; var frontier_count: int=0
	for b in s.buildings:
		if b.hostile and b.dead and not b.infestation:
			cleared.append(b.id)
			if frontier(s,b.id): frontier_count+=1
	var awards: Array=[]; var r: Dictionary=s.run.config.rules.rewards
	if cleared.size()>=1: awards.append({"label":"First original lair","amount":r.first_lair})
	if cleared.size()>=2: awards.append({"label":"Second original lair","amount":r.second_lair})
	if s.mission.encounter_cleared: awards.append({"label":"Ashen Monastery recovered","amount":r.monastery})
	if s.result=="victory": awards.append({"label":"Victory","amount":r.victory})
	if frontier_count>0: awards.append({"label":"Optional frontier lairs (maximum two)","amount":mini(frontier_count,r.frontier_limit)*r.frontier})
	var total: int=0
	for a in awards: total+=int(a.amount)
	var heroes: Array=s.run.heroes.values().duplicate(true)
	for u in s.units:
		if u.hero:
			for h in heroes:
				if h==s.run.heroes.get(str(u.id),{}): h.level=u.level; h.dead=u.dead
	heroes.sort_custom(func(a,b):return merit(a)>merit(b))
	return {"id":s.run.config.id,"config":s.run.config.duplicate(true),"outcome":s.result,"time":s.time,"gold":s.gold,"lairs":cleared.size(),"monastery":s.mission.encounter_cleared,"boss":s.mission.boss_defeated,"losses":s.stats.losses,"recruits":s.stats.recruits,"final_attack":s.run.final_attack,"heroes":heroes.slice(0,3),"awards":awards,"renown":total}
static func merit(h: Dictionary) -> int:
	return int(h.boss)*100+h.equipment.size()*20+h.lairs*5+h.level
static func valid_state(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if not valid_config(value.get("config")) or not value.get("heroes") is Dictionary or not value.get("events") is Array or not value.get("final_attack") is String: return false
	if value.events.size()>96: return false
	for key in value.heroes:
		var h=value.heroes[key]
		if not key is String or not h is Dictionary: return false
		for field in ["name","type","last"]:
			if not h.get(field) is String: return false
		for field in ["level","lairs"]:
			if not number(h.get(field)) or h[field]<0: return false
		if not h.get("dead") is bool or not h.get("boss") is bool or not h.get("equipment") is Array: return false
		for item in h.equipment:
			if not item is String: return false
	for e in value.events:
		if not e is Dictionary or not number(e.get("at")) or not number(e.get("hero")): return false
		for field in ["kind","name","detail"]:
			if not e.get(field) is String: return false
	return true
