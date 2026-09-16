extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const CharacterAnimator=preload("res://scripts/character_animation.gd")
var checks: int=0
var failures: Array[String]=[]
func check(condition: bool,message: String) -> void:
	checks+=1
	if not condition: failures.append(message); push_error(message)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var assets: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
	var types: int=0
	for key in assets:
		if not key.begins_with("unit_"): continue
		types+=1
		var art: Dictionary=assets[key]
		check(art.frames.size()==144 and art.directions.size()==8,key+" has 144 frames in eight directions")
		var image: Image=load(art.src).get_image()
		check(image.get_width()<=4096 and image.get_height()<=4096,key+" fits mobile texture limits")
		for frame in art.frames:
			var r: Array=frame.frame
			check(r[0]>=0 and r[1]>=0 and r[0]+r[2]<=image.get_width() and r[1]+r[3]<=image.get_height(),key+" frame fits atlas")
			check(absf(r[2]/art.density-frame["size"][0])<0.01 and absf(r[3]/art.density-frame["size"][1])<0.01,key+" crop keeps world scale")
	check(types==12,"All heroes, staff, enemies and the boss use the new artwork")
	for i in 8: check(CharacterAnimator.direction(Vector2.from_angle(i*PI/4))==i,"Direction sector %d"%i)
	var sim=Simulation.new(41972); var actor=sim.units[0]; var art: Dictionary=assets["unit_"+actor.type]
	actor.heading=Vector2.DOWN; actor.id=0; sim.time=0; sim.stop(actor); actor.state="Patrolling"
	check(CharacterAnimator.frame(actor,sim,art)==2,"Idle faces southwest without mirroring")
	sim.time=0.5
	check(CharacterAnimator.frame(actor,sim,art)==10,"Idle breathes on simulation time")
	actor.path=PackedVector2Array([actor.pos+Vector2.RIGHT]); actor.animation=6
	check(CharacterAnimator.frame(actor,sim,art)==int(art.animations.walk[6])+2,"Eight-frame gait samples distance traveled")
	sim.stop(actor); actor.state="Repairing Palace"
	check(art.frames[CharacterAnimator.frame(actor,sim,art)].pose.begins_with("attack"),"Workers animate their tools while repairing")
	actor.pending_attack={"duration":0.24,"remaining":0.01}; actor.attacking=0.21
	check(CharacterAnimator.frame(actor,sim,art)==int(art.animations.attack[2])+2,"Wind-up retains the projectile until impact")
	actor.pending_attack={}; sim.mission.id="ember_crown"; actor.attacking=0.20
	check(CharacterAnimator.frame(actor,sim,art)==int(art.animations.attack[3])+2,"Damage and projectile release use the impact pose")
	actor.attacking=0.001
	check(CharacterAnimator.frame(actor,sim,art)==int(art.animations.attack[5])+2,"Attack follows through before returning to idle")
	var old_save: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://reports/full-victory-save.json"))
	check(sim.restore(old_save),"Existing version-three saves load without character migrations")
	var report={"checks":checks,"failures":failures,"character_types":types,"frames":types*144}
	var file=FileAccess.open("res://reports/characters-native.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")+"\n")
	print("CHARACTER ART "+JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
