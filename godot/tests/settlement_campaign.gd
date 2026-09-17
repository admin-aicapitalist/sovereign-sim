extends SceneTree
const S=preload("res://scripts/simulation.gd")
const Rules=preload("res://scripts/settlement_rules.gd")
var reports: Array=[]
func _initialize() -> void: call_deferred("run")
func build(s,key: String) -> Dictionary:
	var tile=s.find_site(key)
	return s.build(key,tile) if tile.x>=0 else {}
func advance(s,seconds: int) -> void:
	for i in seconds*20: s.tick(0.05)
func campaign(seed_value: int,charter: String,condition: String) -> Dictionary:
	var s=S.new(); s.start_settlement(Rules.config(seed_value,charter,condition))
	var warriors=build(s,"warriors"); var market=build(s,"marketplace"); advance(s,45)
	for i in 4: s.recruit(warriors.id)
	var rangers=build(s,"rangers"); advance(s,40)
	var wizards: Dictionary={}; var temple: Dictionary={}
	var construction_ok: bool=not warriors.is_empty() and not market.is_empty() and not rangers.is_empty()
	for second in 1800:
		if s.result!="": break
		if not s.alchemy.unlocked.get("healing",false) and s.alchemy.project.is_empty(): s.Supplies.research(s,"healing",market.id)
		if s.gold>600 and warriors.tier==1 and warriors.upgrade_remaining==0: s.upgrade(warriors.id)
		if wizards.is_empty() and s.gold>700: wizards=build(s,"wizards")
		if not wizards.is_empty() and temple.is_empty() and s.gold>600: temple=build(s,"temple")
		if not temple.is_empty() and temple.progress==1 and not temple.dead and s.magic.project.is_empty() and s.gold>400:
			for key in ["heal","lightning","ward","frost"]:
				if not s.Magic.available(s,key): s.Magic.research(s,key,temple.id); break
		for guild in [warriors,rangers,wizards]:
			if not guild.is_empty() and not guild.dead and guild.progress==1 and s.gold>300: s.recruit(guild.id)
		if not s.flags.values().any(func(f):return not f.dead and f.type=="attack") and s.gold>=150:
			var targets: Array=[]
			targets.append_array(s.lairs().filter(func(b):return s.is_explored(s.pos(b))))
			var boss=s.entity(s.mission.boss_id)
			if boss!=null and not boss.dead and s.is_explored(boss.pos): targets.append(boss)
			targets.sort_custom(func(a,b):
				if a.id==s.mission.boss_id: return true
				if b.id==s.mission.boss_id: return false
				return s.pos(a).distance_to(s.pos(s.palace()))<s.pos(b).distance_to(s.pos(s.palace())))
			if not targets.is_empty(): s.place_flag("attack",s.pos(targets[0]),targets[0].id,150)
		advance(s,1)
		if second==150:
			var resumed=S.new()
			if not resumed.restore(JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))): construction_ok=false
			else:
				s=resumed; warriors=s.building(warriors.id); market=s.building(market.id); rangers=s.building(rangers.id)
				if not wizards.is_empty(): wizards=s.building(wizards.id)
				if not temple.is_empty(): temple=s.building(temple.id)
	var hero_deaths: int=s.run.heroes.values().filter(func(h):return h.dead).size()
	return {"seed":seed_value,"geography":s.fixture.name,"charter":charter,"condition":condition,"outcome":s.result,"seconds":s.time,"lairs":s.stats.lairs,"hero_deaths":hero_deaths,"recruits":s.stats.recruits,"renown":Rules.record(s).get("renown",0),"pass":construction_ok and s.result=="victory" and s.mission.boss_defeated}
func run() -> void:
	for seed_value in [0,1,4]:
		for charter in ["crown","guild_compact"]:
			for condition in ["untroubled","rich_ruins"]:
				var report=campaign(seed_value,charter,condition); reports.append(report); print("SETTLEMENT ",JSON.stringify(report))
	var passed: bool=reports.all(func(r):return r.pass)
	var file=FileAccess.open("res://reports/settlement-campaign.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"pass":passed,"runs":reports,"note":"Paid construction, recruitment, upgrades, potion/spell research, and bounties on explored targets. Autonomous heroes, no combat cheats. Each run resumes from a save. Human pacing and replay appeal remain untested."},"\t")+"\n")
	quit(0 if passed else 1)
