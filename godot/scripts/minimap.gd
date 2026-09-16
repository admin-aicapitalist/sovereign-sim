extends Control
var main
var draw_ms: float=0
var geography: Image
var texture: ImageTexture
var fog_revision: int=-1
var revision: int=-1
func _ready() -> void:
	custom_minimum_size=Vector2(210,140)
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
func project(p: Vector2) -> Vector2:
	var iso:=Vector2((p.x-p.y)*32,(p.x+p.y)*16)
	return Vector2(size.x*0.5,3)+iso*Vector2(size.x/(main.sim.size*64.0),size.y/(main.sim.size*32.0))
func _draw() -> void:
	if main==null: return
	var began: int=Time.get_ticks_usec()
	var s=main.sim
	draw_rect(Rect2(Vector2.ZERO,size),Color("242920"))
	# Keep thousands of tile polygons out of the per-frame canvas command list.
	# A tiny raster is transformed into the same isometric diamond.
	if geography==null or revision!=s.revision or fog_revision!=s.fog_revision:
		revision=s.revision; fog_revision=s.fog_revision
		geography=Image.create(s.size,s.size,false,Image.FORMAT_RGBA8); geography.fill(Color("1c2c25"))
		for t in s.fixture.tiles:
			if not t.explored: continue
			var color:=Color("7d9065") if t.kind=="grass" else Color("ac9d72") if t.kind=="path" else Color("9b8157") if t.kind=="bridge" else Color("49757c")
			geography.set_pixel(t.x,t.y,color if t.visible else color.darkened(0.45))
	var pixels: Image=geography.duplicate()
	for b in s.buildings:
		if not b.dead and s.is_explored(s.pos(b)): pixels.fill_rect(Rect2i(Vector2i(s.pos(b))-Vector2i.ONE,Vector2i(3,3)),Color("ce8360") if b.hostile else Color("f3dca5"))
	for u in s.units:
		if not u.dead and s.is_visible(u.pos): pixels.set_pixel(floori(u.pos.x),floori(u.pos.y),Color("c45e4b") if u.hostile else Color("dce0b8"))
	if texture==null: texture=ImageTexture.create_from_image(pixels)
	else: texture.update(pixels)
	draw_set_transform_matrix(Transform2D(Vector2(size.x,size.y)/(2*s.size),Vector2(-size.x,size.y)/(2*s.size),Vector2(size.x*0.5,3)))
	draw_texture(texture,Vector2.ZERO)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var border:=PackedVector2Array([Vector2(size.x*.5,3),Vector2(size.x,size.y*.5+3),Vector2(size.x*.5,size.y+3),Vector2(0,size.y*.5+3),Vector2(size.x*.5,3)])
	draw_polyline(border,Color("6a7051"),1,true)
	var compass:=Vector2(17,size.y-19)
	draw_line(compass-Vector2(0,10),compass+Vector2(0,9),Color("b9a778"),1,true)
	draw_line(compass-Vector2(7,0),compass+Vector2(7,0),Color("b9a778"),1,true)
	draw_colored_polygon(PackedVector2Array([compass-Vector2(0,10),compass+Vector2(3,1),compass,compass-Vector2(3,-1)]),Color("c7b27b"))
	draw_string(preload("res://assets/cinzel.ttf"),compass+Vector2(-4,-13),"N",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color("baa57a"))
	var view: Rect2=main.world.visible_rect
	var corners:=PackedVector2Array()
	for p in [view.position,view.position+Vector2(view.size.x,0),view.end,view.position+Vector2(0,view.size.y),view.position]:
		corners.append(Vector2(size.x*0.5,3)+p*Vector2(size.x/(s.size*64.0),size.y/(s.size*32.0)))
	draw_polyline(corners,Color("e3ce94"),1.0,true)
	draw_ms=(Time.get_ticks_usec()-began)/1000.0
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		main.camera=(event.position-Vector2(size.x*0.5,3))/Vector2(size.x/(main.sim.size*64.0),size.y/(main.sim.size*32.0))
		accept_event()
