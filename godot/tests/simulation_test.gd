extends SceneTree
const Simulation = preload("res://scripts/simulation.gd")
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		push_error(message)

func advance(sim: Simulation, seconds: float) -> void:
	for i in int(seconds*20):
		sim.tick(0.05)

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var sim := Simulation.new()
	check(sim.size == 88 and sim.lairs().size() == 1,"Imported 88×88 map and one campaign lair")
	var lair: Dictionary = sim.lairs()[0]
	var start := sim.near_open(sim.bpos(sim.palace()))
	var end := sim.near_open(sim.bpos(lair))
	var path := sim.grid.get_point_path(Vector2i(start),Vector2i(end))
	check(path.size()>0,"Lair reachable from starting settlement")
	for point in path:
		check(sim.walkable(point),"Path stays on walkable ground")
	var initial_gold: float = sim.gold
	check(sim.build("warriors",Vector2i(sim.palace().tx,sim.palace().ty)).is_empty(),"Cannot overwrite Palace")
	check(sim.build("nonsense",Vector2i(0,0)).is_empty(),"Unknown building rejected")
	check(sim.gold == initial_gold,"Invalid construction does not charge gold")
	sim.paused = true
	advance(sim,10)
	check(sim.time == 0,"Pause freezes simulation")
	sim.paused = false
	var guild := sim.build("warriors",sim.find_site("warriors"))
	check(not guild.is_empty(),"Legal guild placement")
	if guild.is_empty():
		quit(1)
		return
	check(sim.gold == initial_gold-350,"Guild costs the original 350 gold")
	check(sim.recruit(guild.id)==null,"Cannot recruit before construction completes")
	advance(sim,60)
	check(guild.progress == 1,"Workers autonomously finish construction")
	check(sim.stats.built == 1,"Construction completion counted once")
	for i in 4:
		var hero := sim.recruit(guild.id)
		check(hero != null and hero.gold == 24,"Recruit includes personal supply money")
	check(sim.recruit(guild.id)==null,"Four-bed guild capacity enforced")
	var treasury: float = sim.gold
	check(sim.bounty(lair.id),"Bounty accepted")
	check(sim.gold == treasury-100,"Bounty payment escrowed")
	sim.cancel_bounty(lair.id)
	check(sim.gold == treasury,"Bounty cancellation refunds full escrow")
	check(sim.bounty(lair.id),"Attack bounty posted again")
	advance(sim,30)
	check(sim.stats.moves > 0 and sim.stats.paths > 0,"Real actor movement and A* pathfinding")
	check(sim.stats.taxes > 0,"Economy generates and collects taxes")

	# Save in mid-journey; serialize exactly as the browser/native save does.
	var saved: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot(),"",true,true))
	var restored := Simulation.new()
	check(restored.restore(saved),"Save envelope accepted")
	check(restored.units.size() == sim.units.size(),"All actors restored")
	check(restored.gold == sim.gold and restored.time == sim.time,"Treasury and clock restored")
	check(restored.rng.state == sim.rng.state,"64-bit RNG state survives JSON via string")
	advance(sim,5)
	advance(restored,5)
	check(absf(restored.gold-sim.gold) < 0.001,"Restored economy continues identically")
	check(restored.stats.hits == sim.stats.hits,"Restored combat continues identically")
	for i in sim.units.size():
		check(sim.units[i].pos.distance_to(restored.units[i].pos) < 0.001,"Restored paths continue identically")
	check(not restored.restore({"version":99}),"Unsupported save rejected")
	var broken: Dictionary = saved.duplicate(true)
	broken.units[0].pos = ["corrupt"]
	var before_reject: float = restored.time
	check(not restored.restore(broken) and restored.time == before_reject,"Malformed actor rejected without changing the kingdom")
	broken = saved.duplicate(true)
	broken.buildings[0] = null
	check(not restored.restore(broken),"Malformed building rejected")

	advance(sim,700)
	check(sim.result == "victory","Scripted kingdom wins through autonomous bounty combat")
	check(sim.stats.hits>0 and sim.stats.kills>0,"Actual combat and deaths occurred")
	check(sim.flags.is_empty(),"Completed bounty paid exactly once")
	check(not sim.grid.is_point_solid(Vector2i(lair.tx,lair.ty)),"Destroyed foundations become walkable")
	var dead_save: Dictionary = JSON.parse_string(JSON.stringify(sim.snapshot(),"",true,true))
	check(restored.restore(dead_save),"Completed kingdom restores")
	check(not restored.grid.is_point_solid(Vector2i(lair.tx,lair.ty)),"Destroyed foundations remain open after load")
	print("CAMPAIGN time=",sim.time," stats=",JSON.stringify(sim.stats)," result=",sim.result)
	sim.reset()
	sim.hurt_building(sim.palace(),99999)
	sim.tick(0.05)
	check(sim.result == "defeat","Palace defeat triggers game over")
	sim.reset()
	check(sim.flags.is_empty() and sim.loot.is_empty() and sim.result == "","New kingdom clears transient state")

	var benches: Array = []
	for count in [100,300,1000]:
		sim.setup_stress(count)
		advance(sim,3)
		var timings: Array[float] = []
		for i in 200:
			var before: int = Time.get_ticks_usec()
			sim.tick(0.05)
			timings.append((Time.get_ticks_usec()-before)/1000.0)
		timings.sort()
		check(sim.units.size()==count,"Stress load remains constant")
		check(sim.stats.moves>0 and sim.stats.hits>0 and sim.stats.paths>0,"Stress performs movement, pathfinding and combat")
		benches.append({"units":count,"tick_p50_ms":timings[100],"tick_p95_ms":timings[190],"stats":sim.stats.duplicate(),"simulation_seconds":sim.time})
	var report: Dictionary = {"engine":Engine.get_version_info().string,"os":OS.get_name(),"processor":OS.get_processor_name(),"kind":"native headless simulation only; not browser FPS","tests_failed":failures,"benchmarks":benches}
	var file := FileAccess.open("res://reports/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report))
	print("PASS: simulation regression suite" if failures.is_empty() else "FAIL: "+str(failures))
	quit(0 if failures.is_empty() else 1)
