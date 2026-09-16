extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Magic=preload("res://scripts/magic.gd")
const Fixture=preload("res://scripts/arcane_gallery.gd")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var art: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/casting.json"))
	check(art.frames.size()==128,"Sixteen poses in eight real directions")
	var bitmap: Texture2D=load(art.src)
	check(bitmap.get_width()<=4096 and bitmap.get_height()<=4096,"Casting atlas fits conservative browser texture limits")
	for f in art.frames:
		check(f.frame[0]>=0 and f.frame[1]>=0 and f.frame[0]+f.frame[2]<=bitmap.get_width() and f.frame[1]+f.frame[3]<=bitmap.get_height(),"Packed frame stays inside texture")
		for key in ["staff","hand"]:
			var point:=Vector2(f.sockets[key][0],f.sockets[key][1])+Vector2(f.anchor[0],f.anchor[1])
			check(point.x>=-3 and point.y>=-3 and point.x<=f.size[0]+3 and point.y<=f.size[1]+3,"Socket projects onto the rendered character")
	var s=Simulation.new(); var scene: Dictionary=Fixture.setup(s)
	var wizard=s.entity(scene.wizard)
	var enemy=s.units.filter(func(u):return u.type=="goblin")[0]
	var warrior=s.units.filter(func(u):return u.type=="warrior")[0]
	var gold: float=s.gold; var mana: float=wizard.mana; var hp: float=warrior.hp; var rng_state: int=s.rng.state
	check(Magic.wizard_cast(s,wizard,"heal",scene.friend),"Wizard heals through normal magic logic")
	check(warrior.hp==hp+130 and wizard.mana==mana-25 and s.gold==gold,"Casting performance preserves immediate healing and independent mana cost")
	check(s.rng.state==rng_state,"Presentation consumes no simulation randomness")
	var heal: Dictionary=s.effects[-1]
	check(heal.caster==wizard.id and heal.targets.any(func(t):return t.id==warrior.id),"Healing carries actual recipient and caster coordinates")
	check(wizard.heading.dot((scene.friend-wizard.pos).normalized())>0.999,"Wizard faces the spell target")
	s.effects.clear(); hp=enemy.hp
	check(Magic.cast(s,"meteor",scene.foe),"Royal meteor starts")
	check(enemy.hp==hp and s.effects[-1].type=="spell_meteor" and not s.magic.impacts.is_empty(),"Meteor warning precedes damage")
	var saved: Dictionary=s.snapshot(); var restored=Simulation.new()
	check(restored.restore(saved),"New spell effects restore from a complete save")
	check(restored.entity(wizard.id).heading.distance_to(wizard.heading)<0.00001,"Restored wizard retains the same casting direction")
	for i in 12: restored.tick(0.05)
	check(restored.entity(enemy.id).hp==hp and not restored.effects.any(func(e):return e.type=="meteor_impact"),"No meteor damage or burst before the warning finishes")
	restored.tick(0.05)
	check(restored.entity(enemy.id).hp<hp and restored.effects.any(func(e):return e.type=="meteor_impact"),"Meteor damage and burst resolve together")
	check(restored.effects.all(func(e):return e.type!="spell_meteor"),"Warning leaves on impact")
	check(restored.entity(warrior.id).hp==warrior.hp,"Meteor preserves friendly health")
	var serials: Dictionary={}
	for e in restored.effects:
		check(not serials.has(e.serial),"Effect IDs remain unique after save/load"); serials[e.serial]=true
	var legacy: Dictionary=saved.duplicate(true)
	for unit in legacy.units: unit.erase("heading")
	for e in legacy.effects:
		for key in ["serial","target","element","armored","warded","origin","targets","caster","radius","delay"]: e.erase(key)
	check(Simulation.new().restore(legacy),"Legacy effects without presentation metadata still restore")
	for heading in [[INF,0],[0,"north"],[4,0],"invalid"]:
		var bad: Dictionary=saved.duplicate(true); bad.units[0].heading=heading
		check(not Simulation.new().restore(bad),"Malformed saved casting direction is rejected")
	for pair in [["targets","invalid"],["targets",[{"id":1,"x":"bad","y":0}]],["origin",[INF,1]],["radius",1e30],["serial",-1],["warded",1],["element",[]]]:
		var bad: Dictionary=saved.duplicate(true); bad.effects[0][pair[0]]=pair[1]
		check(not Simulation.new().restore(bad),"Reject malformed visual metadata: "+pair[0])
	s.effects.clear(); warrior.magic_buffs.ward=16; hp=warrior.hp
	s.hurt(warrior,35,enemy)
	check(s.effects[0].warded and s.effects[0].armored and s.effects[0].target==warrior.id,"Ward hit identifies armor, direction and actual recipient")
	check(warrior.hp==hp-maxf(1,35-Simulation.Supplies.armor(s,warrior)),"Ward retains the real armor calculation")
	s.effects.clear(); enemy.pos=warrior.pos+Vector2(0.6,0)
	s.resolve_attack(warrior,enemy)
	check(s.effects.any(func(e):return e.type=="swing") and s.effects.any(func(e):return e.type=="hit"),"Melee trails accompany a resolved hit")
	s.effects.clear(); s.shoot(wizard,enemy,40,"fireball")
	check(s.projectiles[-1].origin==[wizard.pos.x,wizard.pos.y],"Projectile retains its real flight origin")
	for i in 30: s.update_projectiles(0.05)
	check(s.projectiles.is_empty() and s.effects.any(func(e):return e.type=="fire"),"Fireball trail ends in a real impact")
	FileAccess.open("res://reports/arcane-systems.json",FileAccess.WRITE).store_string(JSON.stringify({"checks":checks,"failures":failures},"  ")+"\n")
	print("ARCANE CHECKS ",checks," FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)
