extends Node2D
const Simulation = preload("res://scripts/simulation.gd")
var sim: Simulation
var textures: Dictionary = {}
var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
var selected: int = 0
var build_type: String = ""
var cursor: Vector2 = Vector2.ZERO
var visible_rect := Rect2()
var rendered_units: int = 0
var ground: Texture2D = preload("res://assets/ground.png")
var font: Font = preload("res://assets/alegreya.ttf")

static func iso(point: Vector2) -> Vector2:
	return Vector2((point.x-point.y)*32, (point.x+point.y)*16)

static func uniso(point: Vector2) -> Vector2:
	return Vector2(point.x/64 + point.y/32, point.y/32-point.x/64)

func _ready() -> void:
	for key in manifest:
		textures[key] = load(manifest[key].src)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func hit_test(point: Vector2) -> int:
	var best_id: int = 0
	var best_y: float = -INF
	for u in sim.units:
		if not u.dead and point.distance_to(iso(u.pos) + Vector2(0,-16)) < 20:
			return u.id
	for b in sim.buildings:
		if b.dead:
			continue
		var a: Dictionary = manifest[b.type]
		var factor: float = 1.03 if b.type == "palace" else 0.89
		var anchor := Vector2(a.anchor[0],a.anchor[1])
		var p := iso(sim.bpos(b))
		var rect := Rect2(p-anchor*factor,Vector2(a.w,a.h)*factor)
		if rect.has_point(point) and p.y > best_y:
			best_id = b.id
			best_y = p.y
	return best_id

func paint(key: String, at: Vector2, factor: float = 1, frame: int = -1, facing: float = 1, tint: Color = Color.WHITE) -> void:
	var a: Dictionary = manifest[key]
	var anchor := Vector2(a.anchor[0],a.anchor[1])
	var rect := Rect2(-anchor*factor, Vector2(a.w,a.h)*factor)
	draw_set_transform(at, 0, Vector2(facing,1))
	if frame < 0:
		draw_texture_rect(textures[key],rect,false,tint)
	else:
		var f: Array = a.frames[frame].frame
		draw_texture_rect_region(textures[key],rect,Rect2(f[0],f[1],f[2],f[3]),tint)
	draw_set_transform(Vector2.ZERO)

func ring(at: Vector2, radius: float, color: Color) -> void:
	var points := PackedVector2Array()
	for i in 33:
		var angle: float = i * TAU / 32
		points.append(at + Vector2(cos(angle)*radius,sin(angle)*radius*0.5))
	draw_polyline(points,color,1.5,true)

func health(at: Vector2, fraction: float, hostile: bool) -> void:
	draw_rect(Rect2(at,Vector2(38,5)),Color("242d26"))
	draw_rect(Rect2(at+Vector2.ONE,Vector2(36*clampf(fraction,0,1),3)),Color("be7257") if hostile else Color("c2c890"))

func _draw() -> void:
	if sim == null:
		return
	draw_texture(ground,Vector2(-sim.size*32,0))
	var scene: Array[Dictionary] = []
	for tree in sim.fixture.trees:
		var p := iso(Vector2(tree.x,tree.y))
		if visible_rect.grow(150).has_point(p):
			scene.append({"y": p.y, "tree": tree, "at": p})
	for b in sim.buildings:
		var p := iso(sim.bpos(b))
		if not b.dead and visible_rect.grow(250).has_point(p):
			scene.append({"y": p.y + 6, "building": b, "at": p})
	for pile in sim.loot:
		var p := iso(Vector2(pile.x,pile.y))
		draw_circle(p+Vector2(0,-3),4,Color("d9b873"))
	rendered_units = 0
	for u in sim.units:
		var p := iso(u.pos)
		if not u.dead and visible_rect.grow(70).has_point(p):
			scene.append({"y": p.y, "unit": u, "at": p})
			rendered_units += 1
	scene.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.y < b.y)
	for item in scene:
		var p: Vector2 = item.at
		if item.has("tree"):
			paint(item.tree.type,p,item.tree.scale*0.84)
		elif item.has("building"):
			var b: Dictionary = item.building
			if selected == int(b.id):
				ring(p,b.size*24,Color("f0d591"))
			paint(b.type,p,1.03 if b.type == "palace" else 0.89,-1,1,Color(1,1,1,0.4+0.6*b.progress))
			if b.progress < 1:
				health(p+Vector2(-19,-85),b.progress,false)
			elif b.hp < b.max_hp or selected == int(b.id):
				health(p+Vector2(-19,-90),b.hp/b.max_hp,b.hostile)
		else:
			var u: Simulation.Actor = item.unit
			if selected == u.id:
				ring(p,15,Color("f0d591"))
			var frame: int = 0
			if u.attacking > 0 or u.state in ["Building","Repairing"] and u.path_index >= u.path.size():
				frame = 5 + int(sim.time*8 + u.id) % 3
			elif u.path_index < u.path.size():
				frame = 1 + int(u.animation) % 4
			paint("unit_"+u.type,p,1,frame,u.facing)
			if u.hp < u.max_hp or u.id == selected:
				health(p+Vector2(-19,-46),u.hp/u.max_hp,u.hostile)
			if u.attacking > 0:
				ring(p,12+(0.34-u.attacking)*28,Color(0.93,0.75,0.48,u.attacking*2))
	for id in sim.flags:
		var b := sim.building(id)
		if b.is_empty() or b.dead:
			continue
		var p := iso(sim.bpos(b))
		draw_line(p,p+Vector2(0,-76),Color("d1b880"),2)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-76),p+Vector2(28,-72),p+Vector2(24,-55),p+Vector2(0,-58)]),Color("963f33"))
		draw_string(font,p+Vector2(5,-61),str(int(sim.flags[id])),HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("fff0c8"))
	if build_type != "":
		var tile := Vector2i(cursor.floor())
		var d: Dictionary = sim.definitions.buildings[build_type]
		var color := Color(0.65,0.8,0.5,0.45) if sim.can_build(build_type,tile) and sim.gold >= d.cost else Color(0.9,0.25,0.2,0.45)
		for y in range(tile.y,tile.y+int(d.size)):
			for x in range(tile.x,tile.x+int(d.size)):
				draw_colored_polygon(PackedVector2Array([iso(Vector2(x,y)),iso(Vector2(x+1,y)),iso(Vector2(x+1,y+1)),iso(Vector2(x,y+1))]),color)
		paint(build_type,iso(Vector2(tile)+Vector2.ONE*d.size/2.0),0.89,-1,1,Color(1,1,1,0.6))
