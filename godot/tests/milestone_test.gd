extends SceneTree
const S=preload("res://scripts/simulation.gd")
const Cue=preload("res://scenes/combat_cue.tscn")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,description: String) -> void:
	checks+=1
	if not ok: failures.append(description); push_error(description)
func step(s,seconds: float) -> void:
	for i in int(seconds*20): s.tick(0.05)
func place(s,key: String) -> Dictionary:
	var at: Vector2i=s.find_site(key)
	check(at.x>=0,"Available site: "+key)
	return s.add_building(key,at)
func roundtrip(s) -> Dictionary: return JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=S.new(); var original: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	for kind in ["units","buildings","spells"]:
		for key in original[kind]:
			for field in original[kind][key]: check(s.definitions[kind][key][field]==original[kind][key][field],"Resource preserves %s.%s.%s"%[kind,key,field])
	var edited=load("res://content/units/warrior.tres").duplicate(true); edited.damage=77
	check(edited.data().damage==77 and s.definitions.units.warrior.damage!=77,"Inspector resource edits serialize without mutating running balance")
	s.gold=10000; var guild=place(s,"warriors"); var hero=s.recruit(guild.id)
	var before: float=s.gold; var attack: float=s.Supplies.damage(s,hero)
	check(s.upgrade(guild.id) and s.gold==before-275,"Upgrade charges once")
	check(not s.upgrade(guild.id),"Duplicate upgrade blocked")
	s.paused=true; step(s,4); check(guild.upgrade_remaining==30,"Pause freezes training"); s.paused=false
	var clone=S.new(1); check(clone.restore(roundtrip(s)),"Save halfway through guild training")
	s.update_upgrades(30); clone.update_upgrades(30)
	check(guild.tier==2 and s.guild_capacity(guild)==6 and guild.max_hp==1062.5,"Upgrade adds capacity and 25 percent building health")
	check(s.Supplies.damage(s,hero)==attack+4 and s.Supplies.armor(s,hero)==6,"Guild support applies to existing heroes")
	for i in 5: check(s.recruit(guild.id)!=null,"Upgraded guild permits six recruits")
	check(s.recruit(guild.id)==null,"Seventh recruit refused")
	check(not s.upgrade(s.palace().id),"Palace upgrade refused")
	var unfinished=s.add_building("rangers",s.find_site("rangers"),false)
	check(not s.upgrade(unfinished.id),"Unfinished guild cannot upgrade")
	var poor=place(s,"wizards"); s.gold=0; check(not s.upgrade(poor.id),"Insufficient upgrade funds rejected")
	check(clone.building(guild.id).tier==2,"Training continuation after save")

	s.reset(41972); s.Mission.start(s,"ember_crown"); s.gold=10000
	guild=place(s,"warriors"); hero=s.recruit(guild.id)
	var a=s.lairs().filter(func(b):return b.id!=s.mission.encounter_id)
	for b in a.slice(0,2): s.hurt(b,999999,hero)
	s.Mission.update(s,0)
	check(s.mission.revealed and s.is_explored(s.pos(s.building(s.mission.encounter_id))),"Two lairs reveal monastery")
	var monastery=s.building(s.mission.encounter_id); before=s.gold
	s.hurt(monastery,999999,hero); s.Mission.update(s,0)
	check(s.mission.encounter_cleared and s.gold==before+s.definition_of(monastery).reward+250,"Monastery encounter awards crown gold")
	var relic=s.loot.filter(func(p):return p.items.has("runeblade"))[0]
	hero.pos=s.pos(relic); attack=s.Supplies.damage(s,hero)
	check(s.Supplies.collect(s,hero,relic) and hero.equipment.weapon=="runeblade" and hero.equipment.armor=="warden_mail","Relics are physically recovered and equipped")
	check(s.Supplies.damage(s,hero)==attack+12 and s.Supplies.armor(s,hero)==8,"Relics change combat stats")
	var weak=s.loot.filter(func(p):return p.items.has("iron_blade"))[0]
	hero.pos=s.pos(weak); s.Supplies.collect(s,hero,weak)
	check(hero.equipment.weapon=="runeblade" and weak.items.has("iron_blade"),"Worse equipment is left for another hero")
	s.hurt(hero,999999,null)
	var recovered=s.loot.filter(func(p):return p.items.has("runeblade"))[0]
	var successor=s.add_unit("ranger",s.pos(recovered),guild.id)
	check(s.Supplies.collect(s,successor,recovered) and successor.equipment.weapon=="runeblade","Equipment survives hero death")
	check(s.mission.boss_id==0 and s.mission.arrival_remaining==30,"Relic recovery window before boss arrival")
	s.Mission.update(s,30)
	var boss=s.entity(s.mission.boss_id)
	check(boss!=null and boss.name=="The Ember Warlord" and boss.max_hp==2200,"Distinct boss spawns")
	var id: int=boss.id; s.Mission.update(s,0); check(s.mission.boss_id==id,"Boss is spawned once")
	var arena: Vector2=s.near_open(s.pos(monastery)); boss.pos=arena; successor.pos=arena+Vector2(0.5,0)
	s.rebuild_buckets(); s.mission.special_cooldown=0; s.Mission.update(s,0)
	check(s.mission.slam_remaining==1.8,"Slam begins with a warning")
	check(s.Mission.dodge(s,successor) and successor.state=="Dodging the ground slam","Heroes try to leave the telegraph")
	var hp: float=successor.hp; clone=S.new(1)
	check(clone.restore(roundtrip(s)),"Save during boss telegraph, with relics")
	check(clone.entity(id).name==boss.name and clone.mission.slam_remaining==1.8,"Boss identity and telegraph restore")
	s.Mission.update(s,1.8); clone.Mission.update(clone,1.8)
	check(successor.hp==hp-(80-s.Supplies.armor(s,successor)),"Ground slam uses armor and real health")
	check(clone.entity(successor.id).hp==successor.hp,"Restored ground slam deals identical damage once")
	hp=successor.hp; s.Mission.update(s,0); check(successor.hp==hp,"Impact cannot repeat")
	boss.hp=boss.max_hp*0.4; var count: int=s.units.size(); s.Mission.update(s,0)
	check(s.mission.enraged and s.units.size()==count+2,"Half-health enrage calls reinforcements once")
	s.Mission.update(s,0); check(s.units.size()==count+2,"Enrage cannot duplicate reinforcements")
	for b in s.lairs(): s.hurt(b,999999,null)
	s.tick(0.05); check(s.result=="","Clearing lairs does not bypass living boss")
	s.hurt(boss,999999,null); s.tick(0.05)
	check(s.result=="victory" and s.mission.boss_defeated,"Victory needs boss and eight lairs")
	check(s.loot.any(func(p):return p.items.has("ember_crown")),"Boss drops unique crown")

	var save: Dictionary=roundtrip(s); clone=S.new()
	check(clone.restore(save),"Completed mission save loads")
	for key in ["equipment","pending_attack"]:
		var broken=save.duplicate(true); broken.units[0][key]={"bad":"secret"}
		check(not clone.restore(broken),"Reject corrupt "+key)
	var bad=save.duplicate(true); bad.buildings[0].tier=1.5
	check(not clone.restore(bad),"Reject fractional building tier")
	bad=save.duplicate(true); bad.mission.slam_remaining=-1
	check(not clone.restore(bad),"Reject negative boss warning")
	var archive:=ZIPReader.new(); check(archive.open("res://tests/fixtures/legacy-v2-save.zip")==OK,"Open original save fixture")
	var legacy: Dictionary=JSON.parse_string(archive.read_file("kingdom-v2.json").get_string_from_utf8()); archive.close()
	check(legacy.version==2 and clone.restore(legacy) and clone.mission.id=="classic","Existing version-2 saves migrate")
	check_attacks()
	var cue=Cue.instantiate(); root.add_child(cue); cue.sample(0.3,1)
	check(is_equal_approx(cue.progress,0.3),"AnimationPlayer samples simulation time")
	cue.sample(0.3,1); check(is_equal_approx(cue.progress,0.3),"Animation remains frozen when simulation is paused")
	cue.queue_free()
	print("Milestone system checks: ",checks," / failures: ",failures.size())
	var report={"checks":checks,"failures":failures,"pass":failures.is_empty()}
	var file=FileAccess.open("res://reports/milestone-systems.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)

func check_attacks() -> void:
	var s=S.new(41972); s.Mission.start(s,"ember_crown")
	for u in s.units: u.dead=true
	var at: Vector2=s.near_open(s.pos(s.palace())+Vector2(4,0))
	var hero=s.add_unit("warrior",at,0); var target=s.add_unit("troll",at+Vector2(0.5,0),0)
	hero.think=100; target.think=100; target.cooldown=100
	var hp: float=target.hp; s.attack(hero,target)
	check(not hero.pending_attack.is_empty() and target.hp==hp,"Melee damage waits for attack windup")
	step(s,0.1); check(target.hp==hp,"No early damage during windup")
	var remaining: float=hero.pending_attack.remaining
	s.paused=true; step(s,1); check(hero.pending_attack.remaining==remaining,"Pause freezes pending attack")
	s.paused=false; var clone=S.new(1); check(clone.restore(roundtrip(s)),"Save restores a pending attack")
	step(s,0.2); step(clone,0.2)
	check(target.hp<hp and clone.entity(target.id).hp==target.hp,"Restored windup deals identical damage")
	hp=target.hp; step(s,0.1); check(target.hp==hp,"Completed attack deals damage once")
	hero.cooldown=0; s.attack(hero,target); target.pos=s.near_open(at+Vector2(12,0)); step(s,0.3)
	check(target.hp==hp,"Target leaving melee range avoids impact")
	target.pos=at+Vector2(0.5,0); hero.cooldown=0; s.attack(hero,target); s.hurt(hero,999999,null); step(s,0.3)
	check(target.hp==hp,"Dead attacker cannot finish its windup")
