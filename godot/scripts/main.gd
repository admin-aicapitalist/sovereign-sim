extends Node2D
const Simulation=preload("res://scripts/simulation.gd")
const WorldView=preload("res://scripts/world_view.gd")
const KingdomUI=preload("res://scripts/kingdom_ui.gd")
const Sound=preload("res://scripts/sound.gd")
const Magic=preload("res://scripts/magic.gd")
const Supplies=preload("res://scripts/supplies.gd")
var mission_id: String="ember_crown"
var sim:=Simulation.new()
var world:=WorldView.new()
var ui:=KingdomUI.new()
var sound:=Sound.new()
var camera:=Vector2.ZERO
var zoom: float=1.15
var speed: int=1
var accumulator: float=0
var ui_elapsed: float=0
var dropped_time: float=0
var started: bool=false
var pinned_seed: int=-1
var drag: Dictionary={}
var pointer_touch: bool=false
var window: JavaScriptObject
var bridge_callback: JavaScriptObject
var test_enabled: bool=false
var css_size:=Vector2i.ZERO
var benchmark: Dictionary={}
var profile: Dictionary={}
var benchmark_frames: Array[float]=[]
var benchmark_ticks: Array[float]=[]
var benchmark_visible: Array[float]=[]

func _ready() -> void:
	if OS.has_feature("web"):
		window=JavaScriptBridge.get_interface("window")
		test_enabled=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).get('test')==='1'"))
		var seed=JavaScriptBridge.eval("new URLSearchParams(location.search).get('seed')")
		if seed!=null and str(seed).strip_edges()!="": pinned_seed=Simulation.SeedRng.normalize(seed)
		started=bool(JavaScriptBridge.eval("new URLSearchParams(location.search).has('auto')"))
		sync_viewport()
	sim.reset(pinned_seed); Simulation.Mission.start(sim,mission_id)
	add_child(sound); world.sim=sim; add_child(world); ui.main=self; add_child(ui); center()
	if test_enabled:
		bridge_callback=JavaScriptBridge.create_callback(_web_command); window.sovereignCommand=bridge_callback
	if not started: ui.show_welcome()
	update_ui()
func sync_viewport() -> void:
	if window==null: return
	var wanted:=Vector2i(int(window.innerWidth),int(window.innerHeight))
	if wanted!=css_size:
		css_size=wanted; get_window().content_scale_mode=Window.CONTENT_SCALE_MODE_CANVAS_ITEMS; get_window().content_scale_size=wanted
func center() -> void: camera=WorldView.iso(sim.pos(sim.palace()))
func center_on(point: Vector2) -> void: camera=WorldView.iso(point)
func change_zoom(factor: float,point: Vector2=Vector2(-1,-1)) -> void:
	var size:=get_viewport_rect().size
	if point.x<0: point=size*Vector2(0.5,0.47)
	var before:=world.to_local(point); zoom=clampf(zoom*factor,0.35,2.1); camera=before-(point-size*Vector2(0.5,0.47))/zoom
func set_mode(kind: String,key: String) -> void:
	world.mode_kind=kind; world.mode_key=key if kind!="" else ""; world.build_type=key if kind=="build" else ""
	Input.set_default_cursor_shape(Input.CURSOR_CROSS if kind!="" else Input.CURSOR_ARROW)
func new_game(seed_value: int=-1) -> void:
	if ui.modal!=null: ui.close_modal(false)
	sim.reset(seed_value if seed_value>=0 else pinned_seed); Simulation.Mission.start(sim,mission_id); accumulator=0; benchmark.clear(); speed=1; zoom=1.15; world.selected=0; world.hovered=0; set_mode("",""); center()
	ui.last_result=""; ui.action_signature=""; ui.objective_ids=[]; ui.last_selection=-1; ui.objectives_open=false; update_ui()
func _process(dt: float) -> void:
	var began: int=Time.get_ticks_usec()
	sync_viewport(); ui.layout()
	if started and ui.modal==null:
		var direction:=Vector2.ZERO
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT): direction.x-=1
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT): direction.x+=1
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP): direction.y-=1
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN): direction.y+=1
		var mouse:=get_viewport().get_mouse_position(); var size:=get_viewport_rect().size
		if not pointer_touch and drag.is_empty() and mouse.y>ui.top.size.y and mouse.y<ui.deck.position.y:
			if mouse.x>0 and mouse.x<8: direction.x-=1
			if mouse.x>size.x-8: direction.x+=1
		camera+=direction*440*dt/zoom
	camera=WorldView.iso(WorldView.uniso(camera).clamp(Vector2.ZERO,Vector2.ONE*sim.size))
	if started and not sim.paused and sim.result=="" and ui.modal==null:
		accumulator+=dt*speed
		if accumulator>0.5: dropped_time+=accumulator-0.5; accumulator=0.5
		while accumulator>=0.05:
			var before: int=Time.get_ticks_usec(); sim.tick(0.05)
			if not benchmark.is_empty() and benchmark.elapsed>=3: benchmark_ticks.append((Time.get_ticks_usec()-before)/1000.0)
			accumulator-=0.05
	else: accumulator=0
	var size:=get_viewport_rect().size
	var title_screen: bool=ui.modal_kind=="welcome"
	var view_origin:=size*(Vector2(0.73,0.64) if title_screen and size.x>=900 else Vector2(0.5,0.47))
	var view_zoom: float=1.65 if title_screen and size.x>=900 else zoom
	world.position=view_origin-camera*view_zoom; world.scale=Vector2.ONE*view_zoom
	world.visible_rect=Rect2(camera-view_origin/view_zoom,size/view_zoom)
	world.cursor=WorldView.uniso(world.to_local(get_viewport().get_mouse_position())); world.refresh()
	for event in sim.events: sound.play(event)
	sim.events.clear()
	if not benchmark.is_empty():
		benchmark.elapsed+=dt
		if benchmark.elapsed>=3: benchmark_frames.append(dt*1000); benchmark_visible.append(world.rendered_units)
		if benchmark.elapsed>=benchmark.duration+3: finish_benchmark()
	ui_elapsed+=dt
	if ui_elapsed>=0.25: ui_elapsed=0; update_ui()
	if not benchmark.is_empty() and benchmark.elapsed>=3:
		var current={"main_process":(Time.get_ticks_usec()-began)/1000.0,"world_draw":world.draw_ms,"world_refresh":world.refresh_ms,"ui_refresh":ui.refresh_ms,"minimap_draw":ui.minimap.draw_ms}
		for key in current:
			if not profile.has(key): profile[key]=[]
			profile[key].append(current[key])
func update_ui() -> void:
	if not ui.is_inside_tree(): return
	ui.refresh()
	if test_enabled and benchmark.is_empty(): window.sovereignState=JSON.stringify(debug_state())
func _unhandled_input(event: InputEvent) -> void:
	if not started or ui.modal!=null: return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]: change_zoom(1.1 if event.button_index==MOUSE_BUTTON_WHEEL_UP else 0.91,event.position)
		elif event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			pointer_touch=event.device==InputEvent.DEVICE_ID_EMULATION
			drag={"button":event.button_index,"origin":event.position,"last":event.position,"moved":false,"touch":pointer_touch}
	if event is InputEventMouseMotion and drag.is_empty(): world.hovered=world.hit_test(world.to_local(event.position))
	if event is InputEventMagnifyGesture: change_zoom(event.factor,event.position)
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: sim.paused=not sim.paused
			KEY_F: center()
			KEY_1: speed=1; sim.paused=false
			KEY_2: speed=2; sim.paused=false
			KEY_3: speed=3; sim.paused=false
		update_ui()
func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.physical_keycode==KEY_ESCAPE:
		if ui.modal!=null and ui.modal_kind not in ["welcome","end"]: ui.close_modal()
		elif world.mode_kind!="": set_mode("","")
		else: world.selected=0
		update_ui(); get_viewport().set_input_as_handled()
	if drag.is_empty(): return
	if event is InputEventMouseMotion:
		if event.position.distance_to(drag.origin)>5: drag.moved=true
		if drag.button==MOUSE_BUTTON_RIGHT or drag.touch and drag.moved: camera-=(event.position-drag.last)/zoom
		drag.last=event.position
	if event is InputEventMouseButton and not event.pressed and event.button_index==drag.button:
		var moved: bool=drag.moved; var button: int=drag.button; drag.clear()
		if not moved:
			if button==MOUSE_BUTTON_RIGHT: set_mode("","")
			else: click_world(event.position,event.shift_pressed)
		get_viewport().set_input_as_handled(); update_ui()
func click_world(point: Vector2,shift: bool=false) -> void:
	var local:=world.to_local(point); var ground:=WorldView.uniso(local); var id:int=world.hit_test(local); var hit=sim.entity(id)
	var ok: bool=false
	match world.mode_kind:
		"build":
			var b=sim.build(world.mode_key,Vector2i(ground.floor())); ok=not b.is_empty()
			if ok: world.selected=b.id
		"bounty":
			var target: int=id if hit!=null and hit.kind in ["unit","building"] and hit.hostile else 0
			var flag=sim.place_flag(world.mode_key,ground,target); ok=not flag.is_empty()
			if ok: world.selected=flag.id
		"spell": ok=Magic.cast(sim,world.mode_key,Magic.target_point(sim,world.mode_key,ground,hit))
		_: world.selected=id; sound.play("select"); ui.objectives_open=false
	if ok and not shift: set_mode("","")
func save_game() -> void:
	var text: String=JSON.stringify(sim.snapshot(),"",true,true)
	var ok: bool=false
	if OS.has_feature("web"): ok=bool(JavaScriptBridge.eval("(function(){try{localStorage.setItem('sovereign-godot-save-v2',"+JSON.stringify(text)+");return true;}catch(e){return false;}})()"))
	else:
		var file=FileAccess.open("user://kingdom-v2.json",FileAccess.WRITE)
		if file!=null: file.store_string(text); ok=true
	sim.notify("Kingdom saved in this browser." if ok and OS.has_feature("web") else "Kingdom saved." if ok else "Could not store the save. Check available storage and site permissions."); update_ui()
func load_game() -> void:
	var text: String=""
	if OS.has_feature("web"):
		var stored=JavaScriptBridge.eval("(function(){try{return localStorage.getItem('sovereign-godot-save-v2');}catch(e){return null;}})()")
		if stored!=null: text=str(stored)
	elif FileAccess.file_exists("user://kingdom-v2.json"): text=FileAccess.get_file_as_string("user://kingdom-v2.json")
	var parser:=JSON.new(); var data=parser.data if parser.parse(text)==OK else null
	if not data is Dictionary or not sim.restore(data): sim.notify("No compatible saved kingdom was found.")
	else:
		if ui.modal!=null: ui.close_modal(false)
		mission_id=sim.mission.id; started=true; accumulator=0; world.selected=0; set_mode("",""); center(); ui.last_result=""; ui.action_signature=""
	update_ui()
func percentile(values: Array,fraction: float) -> float:
	if values.is_empty(): return 0
	var sorted=values.duplicate(); sorted.sort(); return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))]
func finish_benchmark() -> void:
	var sum: float=0; var seen: float=0
	for frame in benchmark_frames: sum+=frame
	for count in benchmark_visible: seen+=count
	var result={"units":sim.units.size(),"frames":benchmark_frames.size(),"average_fps":benchmark_frames.size()*1000.0/maxf(1,sum),"frame_p50_ms":percentile(benchmark_frames,0.5),"frame_p95_ms":percentile(benchmark_frames,0.95),"tick_p50_ms":percentile(benchmark_ticks,0.5),"tick_p95_ms":percentile(benchmark_ticks,0.95),"visible_units_mean":seen/maxi(1,benchmark_visible.size()),"dropped_sim_seconds":dropped_time,"simulation_seconds":sim.time,"stats":sim.stats.duplicate(),"engine":Engine.get_version_info().string,"warmup_seconds":3,"measurement_seconds":benchmark.duration,"platform":OS.get_name()}
	result.profile_ms={}
	for key in profile: result.profile_ms[key]={"p50":percentile(profile[key],0.5),"p95":percentile(profile[key],0.95)}
	benchmark.clear(); sim.paused=true
	if test_enabled: window.sovereignBenchmark=JSON.stringify(result)
	print("BENCHMARK "+JSON.stringify(result)); update_ui()
func debug_state() -> Dictionary:
	var units: Array=[]
	for u in sim.units: units.append(u.save())
	var state={"mission":sim.mission,"mission_objective":Simulation.Mission.objective(sim),"cue_count":world.cues.size(),"seed":sim.fixture.seed,"region":sim.fixture.name,"time":sim.time,"gold":sim.gold,"result":sim.result,"paused":sim.paused,"speed":speed,"started":started,"selection":world.selected,"mode_kind":world.mode_kind,"mode":world.mode_key,"modal":ui.modal_kind,"units":units,"buildings":sim.buildings,"flags":sim.flags.values().filter(func(f):return not f.dead),"loot":sim.loot,"alchemy":sim.alchemy,"magic":sim.magic,"cooldowns":sim.cooldowns,"stats":sim.stats,"rng":sim.rng.state,"message":sim.message,"camera":[camera.x,camera.y],"zoom":zoom,"viewport":[get_viewport_rect().size.x,get_viewport_rect().size.y],"widgets":ui.debug_widgets(),"explored":sim.fixture.tiles.filter(func(t):return t.explored).size(),"visible":sim.fixture.tiles.filter(func(t):return t.visible).size(),"build_sites":{},"entities_on_screen":[],"rendered_units":world.rendered_units,"sound":sound.enabled,"inspector_text":ui.details.text,"modal_rect":[ui.modal_panel.position.x,ui.modal_panel.position.y,ui.modal_panel.size.x,ui.modal_panel.size.y] if ui.modal!=null else [],"minimap_rect":[ui.minimap.global_position.x,ui.minimap.global_position.y,ui.minimap.size.x,ui.minimap.size.y]}
	for type in ["warriors","rangers","wizards","marketplace","temple","house","tower","thieves"]:
		var tile=sim.find_site(type); var p=world.to_global(WorldView.iso(Vector2(tile)+Vector2.ONE*0.1)); state.build_sites[type]={"tile":[tile.x,tile.y],"point":[p.x,p.y]}
	for e in sim.units+sim.buildings+sim.flags.values()+sim.loot:
		var p=world.to_global(WorldView.iso(sim.pos(e))+Vector2(0,-20 if e.kind=="unit" else -35 if e.kind=="building" else 0)); state.entities_on_screen.append({"id":e.id,"point":[p.x,p.y]})
	state.character_visuals=[]
	for u in sim.units.slice(0,40):
		var key: String="unit_warlord" if u.id==sim.mission.boss_id else "unit_"+u.type
		var art: Dictionary=world.manifest[key]
		var frame: int=WorldView.CharacterAnimation.frame(u,sim,art)
		state.character_visuals.append({"id":u.id,"key":key,"frame":frame,"direction":WorldView.CharacterAnimation.direction(u.heading),"pose":art.frames[frame].pose})
	return state
func _web_command(args: Array) -> void:
	var parser:=JSON.new()
	if args.is_empty() or parser.parse(str(args[0]))!=OK or not parser.data is Dictionary: return
	var request: Dictionary=parser.data
	match request.get("action",""):
		"reset": mission_id=request.get("mission","classic"); new_game(int(request.get("seed",41972))); started=true; sim.paused=true
		"pause": sim.paused=request.get("value",true)
		"step":
			var paused: bool=sim.paused; sim.paused=false
			for i in clampi(int(request.get("seconds",1)*20),0,48000): sim.tick(0.05)
			sim.paused=paused
		"position":
			var actor=sim.actors.get(int(request.id))
			if actor!=null:
				actor.pos=Vector2(request.x,request.y); actor.target=0; actor.think=0; sim.stop(actor); sim.update_vision(); sim.rebuild_buckets()
		"character_gallery":
			# Test-only art fixture, deliberately exercised through the real world renderer.
			mission_id="classic"; new_game(41972); started=true; sim.paused=true
			for actor in sim.units: sim.actors.erase(actor.id); sim.by_id.erase(actor.id)
			sim.units.clear()
			var center_at: Vector2=sim.pos(sim.palace())+Vector2(7,7)
			var types: Array=["warrior","guard","ranger","wizard","peasant","collector","thief","goblin","skeleton","rat","troll","troll"]
			for i in types.size():
				var across: float=(i%6-2.5)*2.8
				var down: float=(floori(i/6.0)-0.5)*7.5
				var at: Vector2=center_at+Vector2(across+down,-across+down)*0.5
				var actor=sim.add_unit(types[i],at,sim.palace().id)
				actor.think=999; actor.heading=Vector2.RIGHT
				if i==11: sim.mission.boss_id=actor.id
			sim.fixture.trees.assign(sim.fixture.trees.filter(func(t):return Vector2(t.x,t.y).distance_to(center_at)>15))
			sim.revision+=1; sim.reveal(center_at,20); sim.rebuild_buckets(); camera=WorldView.iso(center_at); zoom=1.55
		"character_pose":
			sim.time=float(request.get("time",0))
			for actor in sim.units:
				actor.heading=Vector2.from_angle(int(request.get("direction",0))*PI/4)
				actor.animation=float(request.get("frame",0)); actor.attacking=0; actor.pending_attack={}; sim.stop(actor)
				actor.state="Patrolling"
				match request.get("pose","idle"):
					"walk": actor.path=PackedVector2Array([actor.pos+actor.heading*5]); actor.path_index=0
					"attack": actor.attacking=0.34-float(request.get("frame",0))*0.05
					"windup": actor.pending_attack={"target":0,"duration":0.24,"remaining":maxf(0.001,0.24-float(request.get("frame",0))*.08)}
					"work": actor.state="Building a cottage"
		"upgrade": sim.upgrade(int(request.id))
		"select": world.selected=int(request.id)
		"camera": camera=WorldView.iso(Vector2(request.x,request.y))
		"center": center()
		"mode": set_mode(request.get("kind","build"),request.get("type","warriors"))
		"save": save_game()
		"load": load_game()
		"damage": sim.hurt(sim.entity(int(request.id)),request.amount,null)
		"reveal": sim.reveal(Vector2(request.x,request.y),request.get("radius",10))
		"laboratory":
			mission_id=request.get("mission","classic"); new_game(41972); started=true; sim.paused=true; sim.gold=20000
			for type in ["warriors","rangers","wizards","thieves","marketplace","temple","tower"]:
				var site=sim.find_site(type)
				if site.x>=0: sim.add_building(type,site)
			for type in ["warrior","ranger","wizard","thief"]:
				var guild=sim.operating("").filter(func(b):return sim.definition_of(b).get("recruits","")==type)[0]; sim.recruit(guild.id)
			sim.update_vision()
		"benchmark":
			if ui.modal!=null: ui.close_modal(false)
			sim.setup_stress(clampi(int(request.count),1,2000)); started=true; world.selected=0; set_mode("",""); camera=WorldView.iso(Vector2.ONE*sim.size/2); zoom=0.35; speed=1; accumulator=0; dropped_time=0
			profile.clear(); benchmark_frames.clear(); benchmark_ticks.clear(); benchmark_visible.clear(); window.sovereignBenchmark=""; benchmark={"elapsed":0.0,"duration":clampf(request.get("seconds",15),5,60)}
	update_ui()
