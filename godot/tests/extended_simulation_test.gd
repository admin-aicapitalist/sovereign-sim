extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Magic=preload("res://scripts/magic.gd")
const Sanitation=preload("res://scripts/sanitation.gd")
var failures: Array=[]
var checks: int=0
func check(ok: bool,message: String) -> void:
	checks+=1
	if not ok: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=Simulation.new(41972); s.gold=10000
	for key in s.definitions.spells: s.magic.unlocked[key]=true
	var p=s.near_open(s.pos(s.palace())+Vector2(5,0))
	var ally=s.add_unit("warrior",p); var a=s.add_unit("troll",p+Vector2(0.5,0)); var b=s.add_unit("troll",p+Vector2(1,0))
	s.update_vision(); var hp: float=ally.hp
	check(Magic.cast(s,"lightning",a.pos),"Lightning casts on visible hostile units")
	check(a.hp==a.max_hp-s.definitions.spells.lightning.damage+a.definition.armor,"Lightning primary damage includes armor")
	check(b.hp==b.max_hp-s.definitions.spells.lightning.splash+b.definition.armor and ally.hp==hp,"Lightning splash respects armor and allies")
	check(Magic.cast(s,"ward",ally.pos) and ally.magic_buffs.ward==s.definitions.spells.ward.duration,"Royal Ward")
	var money: float=s.gold; var cooldown: float=s.cooldowns.frost
	check(not Magic.cast(s,"frost",Vector2(1,1)) and s.gold==money and s.cooldowns.frost==cooldown,"Fog rejects paid offensive spells without charging")
	var wizard=s.add_unit("wizard",p); wizard.mana=0; wizard.state="Resting"; Magic.update_unit(s,wizard,5)
	check(wizard.mana==20,"Resting wizard regenerates mana")
	wizard.target=a.id; wizard.state="Fighting"; Magic.update_unit(s,wizard,5); check(wizard.mana==30,"Fighting wizard regenerates more slowly")
	s.magic.impacts.clear(); s.cooldowns.meteor=0; check(Magic.cast(s,"meteor",a.pos),"Delayed meteor accepted")
	var restored=Simulation.new(1); check(restored.restore(JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))),"In-flight meteor save loads")
	var before: float=restored.entity(a.id).hp; restored.time+=0.7; Magic.update(restored,0.7)
	check(restored.entity(a.id).hp==before-s.definitions.spells.meteor.damage+a.definition.armor,"Saved meteor impacts exactly once")
	before=restored.entity(a.id).hp; Magic.update(restored,1); check(restored.entity(a.id).hp==before,"Meteor does not repeat")
	for seed in [0,1,4,42,41972]:
		s.reset(seed); s.gold=10000
		while Sanitation.status(s).cottages<7:
			var site=s.find_site("house")
			if site.x<0: break
			s.add_building("house",site)
		Sanitation.update(s,60)
		var sewers=s.buildings.filter(func(e):return e.infestation and not e.dead)
		check(sewers.size()==1,"Safe sewer generated on seed %d"%seed)
		for sewer in sewers:
			check(not s.find_path(s.near_open(s.pos(s.palace())),s.pos(sewer)).is_empty(),"Sewer reachable on seed %d"%seed)
			for y in range(sewer.ty-1,sewer.ty+3):
				for x in range(sewer.tx-1,sewer.tx+3): check(s.tile_at(Vector2(x,y)).kind not in ["water","bridge"],"Sewer bank clearance")
		for rat in s.units.filter(func(u):return u.infestation): check(s.walkable(rat.pos),"Urban rat spawns on walkable ground")
	s.reset(41972)
	var living: int=s.units.size()
	for i in 165:
		var dead=s.add_unit("rat",s.near_point(s.pos(s.palace()),5)); dead.infestation=true; s.hurt(dead,99999,null)
	s.tick(0.05)
	check(s.units.size()==living and s.actors.size()==living,"Cleanup removes dead actors from arrays and indexes")
	print("PASS spell effects, saved impacts, safe sewers and cleanup")
	# Sustained simulation with an invulnerable Palace: exercise raids, staff replacement,
	# the 10-minute troll, corpse cleanup and repeated saves without ending the scenario.
	s.reset(41972); s.palace().hp=1000000000; s.palace().max_hp=s.palace().hp
	var maximum: int=s.units.size()
	for second in 1800:
		for tick in 20: s.tick(0.05)
		s.events.clear(); maximum=maxi(maximum,s.units.size())
		if (second+1)%300==0:
			var copy=Simulation.new(1); check(copy.restore(JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))),"Long-running kingdom remains saveable")
			print("SOAK ",second+1,"s actors=",s.units.size()," live=",s.units.filter(func(u):return not u.dead).size())
	check(s.time>1799 and s.result=="","Thirty-minute controlled run completes")
	check(s.troll_spawned and s.units.any(func(u):return u.type=="troll"),"Hill Troll arrives after ten minutes")
	check(s.stats.losses>0 and s.next_id>50,"Raids and replacement staff remain active")
	check(maximum<=160,"Dead actor retention stays bounded")
	var report={"checks":checks,"failures":failures,"soak_seconds":s.time,"maximum_retained_actors":maximum,"final_actors":s.units.size(),"stats":s.stats,"note":"Palace health raised to keep the controlled 30-minute scenario running; no campaign victory claimed."}
	FileAccess.open("res://reports/full-extended.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
