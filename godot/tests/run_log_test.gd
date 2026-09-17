extends SceneTree
const S=preload("res://scripts/simulation.gd")
const Store=preload("res://scripts/run_log_store.gd")
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=S.new(); s.start_settlement(s.Settlement.config(41972))
	var configuration=s.run.config.duplicate(true)
	var control=S.new(); control.start_settlement(configuration)
	s.run_log.begin(s)
	for world in [s,control]:
		var guild=world.build("warriors",world.find_site("warriors")); guild.progress=1
		world.recruit(guild.id)
	var elapsed: int=Time.get_ticks_msec()
	for i in 2400: s.tick(0.05)
	var logged_ms: int=Time.get_ticks_msec()-elapsed
	elapsed=Time.get_ticks_msec()
	for i in 2400: control.tick(0.05)
	var control_ms: int=Time.get_ticks_msec()-elapsed
	check(s.snapshot()==control.snapshot(),"Recording preserves the complete deterministic simulation after 120 seconds")
	var events: Array=s.run_log.pending
	check(events.any(func(e):return e.event=="actor.decision"),"Autonomous choices are recorded")
	check(events.filter(func(e):return e.event=="world.sample").size()>=24,"Continuous world state is sampled every five seconds")
	var hero=s.units.filter(func(u):return u.hero)[0]
	s.Shelter.leave(s,hero); hero.hp=hero.max_hp; s.hurt(hero,hero.max_hp*0.9,null)
	check(events.any(func(e):return e.event=="combat.damage" and e.data.target==hero.id),"Combat damage records the target and precedes the resulting Shadow")
	check(events.any(func(e):return e.event=="hero.journey" and e.data.journey.aspect=="shadow"),"Damage that causes Shadow records the journey and reason")
	for i in 150: s.Settlement.event(s,"audit_marker",hero,str(i))
	check(s.run.events.size()==96 and events.filter(func(e):return e.event=="story.event" and e.data.kind=="audit_marker").size()==150,"Durable history exceeds the 96-event UI limit")
	var before: float=hero.hp; hero.potions.healing=1; s.Supplies.update_unit(s,hero,0.05)
	check(events.any(func(e):return e.event=="hero.potion" and e.data.hp_before==before),"Potion recovery identifies the hero and health change")
	var dir: String="/tmp/sovereign-run-log-test-"+s.run.config.id
	var storage=Store.new(dir)
	var batch: Dictionary=s.run_log.batch(s); var count: int=batch.events.size()
	check(storage.append(batch),"A complete run batch persists to native storage")
	s.run_log.pending.clear()
	var snapshot=JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
	var restored=S.new(); check(restored.restore(snapshot),"Save restoration remains compatible")
	restored.run_log.begin(restored,"resumed")
	check(restored.run_log.run_id==s.run_log.run_id and restored.run_log.segment!=s.run_log.segment,"Resuming retains the run ID with a new ordered segment")
	var next: Dictionary=restored.run_log.batch(restored)
	check(storage.append(next),"Resumed events append without overwriting history")
	storage.export_run(s.run_log.run_id)
	var output=JSON.parse_string(FileAccess.get_file_as_string(storage.last_export))
	check(output.events.size()==count+next.events.size(),"Export contains every event across both segments")
	check(output.events[0].event=="run.new" and output.events[count].event=="run.resumed","Segment boundaries preserve initial and resumed checkpoints")
	var failing=Store.new(dir); failing.root_path="/dev/null/run-logs"
	check(not failing.append(batch) and failing.error!="" and batch.events.size()==count,"A failed write reports failure without discarding the caller's events")
	restored.result="abandoned"; restored.run_log.observe(restored); restored.run_log.observe(restored)
	check(restored.run_log.pending.filter(func(e):return e.event=="run.ended").size()==1,"The final checkpoint is recorded exactly once")
	var other=S.new(); other.start_settlement(s.Settlement.config(4)); other.run_log.begin(other)
	storage.append(other.run_log.batch(other))
	check(storage.status().runs.size()==2,"Starting another run preserves the previous run")
	var report={"checks":checks,"failures":failures,"pass":failures.is_empty(),"logged_ms":logged_ms,"control_ms":control_ms,"events_120_seconds":count,"export_bytes":FileAccess.get_file_as_bytes(storage.last_export).size()}
	print("RUN LOG TEST ",JSON.stringify(report))
	FileAccess.open("res://reports/run-log-systems.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
