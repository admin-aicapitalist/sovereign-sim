extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
const WorldView = preload("res://scripts/world_view.gd")
var sim := Simulation.new()
var world := WorldView.new()
var camera := Vector2.ZERO
var zoom: float = 1.15
var speed: int = 1
var accumulator: float = 0
var ui_elapsed: float = 0
var root: Control
var top: PanelContainer
var bottom: PanelContainer
var inspector: PanelContainer
var campaign: PanelContainer
var treasury: Label
var status: Label
var details: Label
var objective: Label
var action: Button
var withdraw: Button
var pause_button: Button
var info: Label
var last_size := Vector2.ZERO
var bridge_callback: JavaScriptObject
var window: JavaScriptObject
var benchmark: Dictionary = {}
var benchmark_result: Dictionary = {}
var benchmark_frames: Array[float] = []
var benchmark_ticks: Array[float] = []
var benchmark_visible: Array[float] = []
var steps_this_frame: int = 0
var sim_ms: float = 0
var dropped_time: float = 0
var test_enabled: bool = false

func _ready() -> void:
	world.sim = sim
	add_child(world)
	center()
	make_ui()
	if OS.has_feature("web"):
		window = JavaScriptBridge.get_interface("window")
		test_enabled = str(window.location.search).contains("test=1")
		if test_enabled:
			bridge_callback = JavaScriptBridge.create_callback(_web_command)
			window.sovereignCommand = bridge_callback
	update_ui()

func center() -> void:
	camera = WorldView.iso(sim.bpos(sim.palace()))

func panel(color: String = "e5d3af") -> PanelContainer:
	var p := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color)
	style.border_color = Color("ae8851")
	style.set_border_width_all(2)
	style.set_content_margin_all(16)
	style.set_corner_radius_all(3)
	p.add_theme_stylebox_override("panel", style)
	root.add_child(p)
	return p

func label(text: String, font_size: int = 18, color: String = "453525") -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color(color))
	return l

func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 38
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(callback)
	return b

func make_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	var theme := Theme.new()
	theme.default_font = preload("res://assets/alegreya.ttf")
	theme.default_font_size = 18
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("69372b")
	normal.border_color = Color("b49458")
	normal.set_border_width_all(1)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 7
	normal.content_margin_bottom = 7
	theme.set_stylebox("normal","Button",normal)
	var hover := normal.duplicate()
	hover.bg_color = Color("895039")
	theme.set_stylebox("hover","Button",hover)
	theme.set_stylebox("pressed","Button",hover)
	theme.set_color("font_color","Button",Color("f1e0b7"))
	root.theme = theme
	top = panel("28271f")
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation",18)
	top.add_child(top_row)
	var title := label("SOVEREIGN",26,"ecd4a0")
	title.add_theme_font_override("font",preload("res://assets/cinzel.ttf"))
	top_row.add_child(title)
	treasury = label("",22,"ecd4a0")
	treasury.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_row.add_child(treasury)
	pause_button = button("Pause",func(): sim.paused = not sim.paused; update_ui())
	top_row.add_child(pause_button)
	top_row.add_child(button("1× / 3×",func(): speed = 3 if speed == 1 else 1))
	top_row.add_child(button("Save",save_game))
	top_row.add_child(button("Load",load_game))
	top_row.add_child(button("New",new_game))
	campaign = panel()
	var col := VBoxContainer.new()
	campaign.add_child(col)
	col.add_child(label("THE ROYAL CAMPAIGN",15,"866640"))
	col.add_child(label("The Young Kingdom",24))
	objective = label("",17)
	objective.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(objective)
	col.add_child(button("Find the lair",func():
		if not sim.lairs().is_empty():
			world.selected = sim.lairs()[0].id
			camera = WorldView.iso(sim.bpos(sim.lairs()[0]))
			update_ui()))
	col.add_child(button("Return to Palace",center))
	inspector = panel()
	var inspect_col := VBoxContainer.new()
	inspector.add_child(inspect_col)
	inspect_col.add_child(label("YOUR KINGDOM",15,"866640"))
	details = label("Select a building or hero.",19)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inspect_col.add_child(details)
	action = button("Recruit",selected_action)
	inspect_col.add_child(action)
	withdraw = button("Withdraw bounty",func(): sim.cancel_bounty(world.selected); update_ui())
	inspect_col.add_child(withdraw)
	bottom = panel("28271f")
	var commands := VBoxContainer.new()
	commands.add_theme_constant_override("separation",10)
	bottom.add_child(commands)
	commands.add_child(label("CONSTRUCT YOUR KINGDOM",16,"c9ad73"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",10)
	commands.add_child(row)
	for type in ["warriors","rangers","marketplace","house","tower"]:
		var d: Dictionary = sim.definitions.buildings[type]
		var b := button("%s · %dg" % [d.get("short",d.name),d.cost],func(): world.build_type = type; sim.message = "Click clear ground to place " + d.name; update_ui())
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(b)
	status = label("",18,"e2cca5")
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	commands.add_child(status)
	info = label("WASD / right-drag: pan    Wheel: zoom    Space: pause    F: Palace    Esc: cancel",14,"b19e7c")
	commands.add_child(info)
	world.selected = sim.palace().id

func layout_ui() -> void:
	var s := get_viewport_rect().size
	if s == last_size:
		return
	last_size = s
	top.position = Vector2.ZERO
	top.size = Vector2(s.x,76)
	campaign.position = Vector2(18,98)
	campaign.size = Vector2(258,0)
	inspector.position = Vector2(s.x-276,98)
	inspector.size = Vector2(258,0)
	bottom.position = Vector2(18,s.y-192)
	bottom.size = Vector2(s.x-36,174)

func selected_action() -> void:
	var b := sim.building(world.selected)
	if b.is_empty():
		return
	if b.hostile:
		sim.bounty(b.id)
	else:
		sim.recruit(b.id)
	update_ui()

func update_ui() -> void:
	var heroes: int = 0
	for u in sim.units:
		if not u.dead and u.hero:
			heroes += 1
	treasury.text = "%dg    %d heroes    Day %d" % [sim.gold,heroes,1+int(sim.time/120)]
	pause_button.text = "Resume" if sim.paused else "Pause"
	objective.text = "Destroy the frontier lair.\nKeep your Palace standing.\n\n%s · Seed %d\n%s" % [sim.fixture.name,sim.fixture.seed,"Realm secured" if sim.result == "victory" else "1 lair remains"]
	status.text = sim.message if sim.result == "" else ("Victory — the realm is yours. Start a new kingdom to play again." if sim.result == "victory" else "The Palace has fallen. Start a new kingdom to try again.")
	if world.build_type != "":
		status.text = "Place %s · Esc cancels · Shift keeps building" % sim.definitions.buildings[world.build_type].name
	action.visible = false
	withdraw.visible = false
	var b := sim.building(world.selected)
	if not b.is_empty() and not b.dead:
		var d: Dictionary = sim.definitions.buildings[b.type]
		details.text = "%s\n\nHealth: %d / %d\n%s" % [d.name,b.hp,b.max_hp,"Construction: %d%%" % (b.progress*100) if b.progress<1 else "Operational"]
		if b.hostile:
			details.text += "\nBounty: %dg" % sim.flags.get(int(b.id),0)
			action.text = "Post / raise bounty · 100g"
			action.visible = true
			action.disabled = sim.gold < 100 or sim.result != ""
			withdraw.visible = sim.flags.has(int(b.id))
		elif d.has("recruits"):
			action.text = "Recruit %s · %dg" % [d.recruits,sim.definitions.units[d.recruits].cost]
			action.visible = true
			action.disabled = b.progress < 1 or sim.result != ""
		else:
			details.text += "\nTax reserves: %dg" % b.tax
	elif sim.actors.has(world.selected):
		var u: Simulation.Actor = sim.actors[world.selected]
		details.text = "%s\n\n%s\nHealth: %d / %d\nPurse: %dg" % [u.definition.name,u.state,u.hp,u.max_hp,u.gold]
	else:
		details.text = "Select a building or hero."
	if test_enabled and benchmark.is_empty():
		window.sovereignState = JSON.stringify(debug_state())

func _process(dt: float) -> void:
	layout_ui()
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		camera.x -= 550*dt/zoom
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		camera.x += 550*dt/zoom
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		camera.y -= 550*dt/zoom
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		camera.y += 550*dt/zoom
	var map_camera := WorldView.uniso(camera)
	map_camera = map_camera.clamp(Vector2.ZERO,Vector2.ONE*sim.size)
	camera = WorldView.iso(map_camera)
	sim_ms = 0
	steps_this_frame = 0
	if not sim.paused and sim.result == "":
		accumulator += dt * speed
		# Bound catch-up work; record lost time rather than hiding overload in reports.
		if accumulator > 0.5:
			dropped_time += accumulator-0.5
			accumulator = 0.5
		while accumulator >= 0.05:
			var start: int = Time.get_ticks_usec()
			sim.tick(0.05)
			var elapsed: float = (Time.get_ticks_usec()-start)/1000.0
			sim_ms += elapsed
			steps_this_frame += 1
			if not benchmark.is_empty() and benchmark.elapsed >= 3:
				benchmark_ticks.append(elapsed)
			accumulator -= 0.05
	else:
		accumulator = 0
	var s := get_viewport_rect().size
	world.position = s*Vector2(0.5,0.47)-camera*zoom
	world.scale = Vector2.ONE*zoom
	world.visible_rect = Rect2(camera-s*Vector2(0.5,0.47)/zoom,s/zoom)
	world.cursor = WorldView.uniso(world.to_local(get_viewport().get_mouse_position()))
	world.queue_redraw()
	if not benchmark.is_empty():
		benchmark.elapsed += dt
		if benchmark.elapsed >= 3:
			benchmark_frames.append(dt*1000)
			benchmark_visible.append(float(world.rendered_units))
		if benchmark.elapsed >= benchmark.duration+3:
			finish_benchmark()
	ui_elapsed += dt
	if ui_elapsed >= 0.25:
		ui_elapsed = 0
		update_ui()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
		camera -= event.relative/zoom
	if event is InputEventMouseButton and event.pressed:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			var before := world.to_local(event.position)
			zoom = clampf(zoom*(1.12 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 0.89),0.3,2.1)
			var s := get_viewport_rect().size
			camera = before-(event.position-s*Vector2(0.5,0.47))/zoom
		elif event.button_index == MOUSE_BUTTON_LEFT:
			var point := world.to_local(event.position)
			if world.build_type != "":
				var b := sim.build(world.build_type,Vector2i(WorldView.uniso(point).floor()))
				if not b.is_empty():
					world.selected = b.id
					if not event.shift_pressed:
						world.build_type = ""
			else:
				world.selected = world.hit_test(point)
			update_ui()
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_SPACE: sim.paused = not sim.paused
			KEY_F: center()
			KEY_ESCAPE: world.build_type = ""
			KEY_1: speed = 1
			KEY_3: speed = 3
		update_ui()

func new_game() -> void:
	sim.reset()
	benchmark.clear()
	accumulator = 0
	speed = 1
	world.selected = sim.palace().id
	world.build_type = ""
	zoom = 1.15
	center()
	update_ui()

func save_game() -> void:
	var text: String = JSON.stringify(sim.snapshot(),"",true,true)
	if OS.has_feature("web"):
		var saved = JavaScriptBridge.eval("(function(){try{localStorage.setItem('sovereign-godot-save-v1',"+JSON.stringify(text)+");return true;}catch(e){return false;}})()")
		sim.message = "Kingdom saved in this browser." if saved else "This browser could not store the save. Check available storage and site permissions."
	else:
		var file := FileAccess.open("user://kingdom.json",FileAccess.WRITE)
		if file == null:
			sim.message = "Could not write the save file."
			return
		file.store_string(text)
		sim.message = "Kingdom saved."
	update_ui()

func load_game() -> void:
	var text: String = ""
	if OS.has_feature("web"):
		var stored = JavaScriptBridge.eval("(function(){try{return localStorage.getItem('sovereign-godot-save-v1');}catch(e){return null;}})()")
		if stored != null:
			text = str(stored)
	elif FileAccess.file_exists("user://kingdom.json"):
		text = FileAccess.get_file_as_string("user://kingdom.json")
	var parser := JSON.new()
	var data = parser.data if parser.parse(text) == OK else null
	if not data is Dictionary or not sim.restore(data):
		sim.message = "No compatible saved kingdom was found."
	else:
		accumulator = 0
		world.build_type = ""
		world.selected = sim.palace().id
	update_ui()

func percentile(values: Array[float], fraction: float) -> float:
	if values.is_empty():
		return 0
	var sorted := values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))]

func finish_benchmark() -> void:
	var sum: float = 0
	var seen: float = 0
	for frame in benchmark_frames:
		sum += frame
	for count in benchmark_visible:
		seen += count
	benchmark_result = {"units": sim.units.size(),"frames": benchmark_frames.size(),
		"average_fps": benchmark_frames.size()*1000.0/maxf(1,sum),
		"frame_p50_ms": percentile(benchmark_frames,0.5),"frame_p95_ms": percentile(benchmark_frames,0.95),
		"tick_p50_ms": percentile(benchmark_ticks,0.5),"tick_p95_ms": percentile(benchmark_ticks,0.95),
		"visible_units_mean": seen/maxi(1,benchmark_visible.size()),"dropped_sim_seconds": dropped_time,
		"simulation_seconds": sim.time,"stats": sim.stats.duplicate(),"engine": Engine.get_version_info().string,
		"warmup_seconds": 3,"measurement_seconds": benchmark.duration,"platform": OS.get_name()}
	benchmark.clear()
	sim.paused = true
	if test_enabled:
		window.sovereignBenchmark = JSON.stringify(benchmark_result)
	print("BENCHMARK " + JSON.stringify(benchmark_result))
	update_ui()

func debug_state() -> Dictionary:
	var state := sim.snapshot()
	state.message = sim.message
	state.selection = world.selected
	state.mode = world.build_type
	state.rendered_units = world.rendered_units
	state.build_site = []
	var site := sim.find_site("warriors")
	var point := world.to_global(WorldView.iso(Vector2(site)+Vector2.ONE*0.1))
	state.build_site = [point.x,point.y]
	state.build_tile = [site.x,site.y]
	state.widgets = {}
	for name in ["action","pause_button"]:
		var control: Control = get(name)
		var r := control.get_global_rect()
		state.widgets[name] = [r.get_center().x,r.get_center().y]
	state.buildings_on_screen = []
	for b in sim.buildings:
		var p := world.to_global(WorldView.iso(sim.bpos(b))+Vector2(0,-35))
		state.buildings_on_screen.append({"id": b.id,"point": [p.x,p.y]})
	return state

func _web_command(args: Array) -> void:
	var request = JSON.parse_string(str(args[0]))
	if not request is Dictionary:
		return
	match request.get("action",""):
		"reset": new_game()
		"pause": sim.paused = request.get("value",true)
		"step":
			var was_paused: bool = sim.paused
			sim.paused = false
			for i in mini(int(request.get("seconds",1)*20),12000):
				sim.tick(0.05)
			sim.paused = was_paused
		"select": world.selected = int(request.id)
		"center": center()
		"camera": camera = WorldView.iso(Vector2(request.x,request.y))
		"mode": world.build_type = request.type
		"save": save_game()
		"load": load_game()
		"benchmark":
			sim.setup_stress(clampi(int(request.count),1,2000))
			world.selected = 0
			world.build_type = ""
			camera = WorldView.iso(Vector2.ONE*sim.size/2.0)
			zoom = 0.35
			speed = 1
			accumulator = 0
			dropped_time = 0
			benchmark_frames.clear()
			benchmark_ticks.clear()
			benchmark_visible.clear()
			window.sovereignBenchmark = ""
			benchmark = {"elapsed": 0.0,"duration": clampf(request.get("seconds",15),5,60)}
	update_ui()
