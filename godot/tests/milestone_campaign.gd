extends SceneTree
const S=preload("res://scripts/simulation.gd")
func _initialize() -> void: call_deferred("run")
func build(s,key: String) -> Dictionary:
	var at: Vector2i=s.find_site(key)
	return s.build(key,at) if at.x>=0 else {}
func step(s,seconds: int) -> void:
	for i in seconds*20: s.tick(0.05)
func run() -> void:
	var s=S.new(41972); s.Mission.start(s,"ember_crown")
	var warriors=build(s,"warriors"); var market=build(s,"marketplace"); step(s,45)
	for i in 4: s.recruit(warriors.id)
	var rangers=build(s,"rangers"); step(s,40); s.recruit(rangers.id); s.Supplies.research(s,"healing",market.id)
	var wizards: Dictionary={}; var temple: Dictionary={}; var flags: int=0
	for second in 2400:
		if s.result!="": break
		if s.gold>600 and warriors.tier==1 and warriors.upgrade_remaining==0: s.upgrade(warriors.id)
		if wizards.is_empty() and s.gold>700: wizards=build(s,"wizards")
		if not wizards.is_empty() and temple.is_empty() and s.gold>600: temple=build(s,"temple")
		if not temple.is_empty() and temple.progress==1 and not temple.dead and s.magic.project.is_empty() and s.gold>400:
			for key in ["heal","lightning","ward","frost"]:
				if not s.Magic.available(s,key): s.Magic.research(s,key,temple.id); break
		for guild in [warriors,rangers,wizards]:
			if not guild.is_empty() and not guild.dead and guild.progress==1 and s.gold>300: s.recruit(guild.id)
		if not s.flags.values().any(func(f):return not f.dead and f.type=="attack") and s.gold>=150:
			var targets: Array=[]; targets.append_array(s.lairs())
			var boss=s.entity(s.mission.boss_id)
			if boss!=null and not boss.dead: targets.append(boss)
			targets.sort_custom(func(a,b):return s.pos(a).distance_to(s.pos(s.palace()))<s.pos(b).distance_to(s.pos(s.palace())))
			if not targets.is_empty(): s.place_flag("attack",s.pos(targets[0]),targets[0].id,150); flags+=1
		step(s,1)
		if second%180==0: print("EMBER ",int(s.time)," lairs=",s.stats.lairs," boss=",s.mission.boss_id," defeated=",s.mission.boss_defeated," palace=",int(s.palace().hp)," heroes=",s.units.filter(func(u):return u.hero and not u.dead).size()," gold=",int(s.gold))
	var report={"seed":s.fixture.seed,"result":s.result,"time":s.time,"stats":s.stats,"mission":s.mission,"flags_posted":flags,"note":"Normal construction, recruitment, upgrades, research and paid bounties. No combat health/damage cheats; heroes act autonomously."}
	var file=FileAccess.open("res://reports/milestone-campaign.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")+"\n")
	var passed: bool=s.result=="victory" and s.mission.boss_defeated and s.stats.lairs==8 and s.stats.equipment_found>0 and s.stats.boss_slams>0
	if passed:
		var save=FileAccess.open("res://reports/milestone-victory-save.json",FileAccess.WRITE); save.store_string(JSON.stringify(s.snapshot()))
	print(JSON.stringify(report)); quit(0 if passed else 1)
