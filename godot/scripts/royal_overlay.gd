extends Control
## Lightweight, resolution-independent heraldic border and title-screen lighting.
var welcome: bool=false
var clock: float=0
func _ready() -> void:
	mouse_filter=Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
func _process(dt: float) -> void:
	if welcome: clock+=dt; queue_redraw()
func _draw() -> void:
	if welcome:
		# Wide scrim keeps type readable while letting the live kingdom fill the right.
		var dark:=Color(0.064,0.075,0.067,0.96)
		var light:=Color(0.064,0.075,0.067,0.1)
		if size.x<900:
			draw_rect(Rect2(Vector2.ZERO,size),Color(0.064,0.075,0.067,0.91))
		else:
			var a: float=size.x*.29; var b: float=size.x*.9
			draw_rect(Rect2(0,0,a,size.y),dark)
			draw_polygon(PackedVector2Array([Vector2(a,0),Vector2(b,0),Vector2(b,size.y),Vector2(a,size.y)]),PackedColorArray([dark,light,light,dark]))
			draw_rect(Rect2(b,0,size.x-b,size.y),light)
		for i in 24:
			var x: float=fmod(i*117.7+sin(clock*.14+i)*24,size.x)
			var y: float=fmod(i*79.1-clock*(3+i%4)+size.y*10,size.y)
			draw_circle(Vector2(x,y),1.0 if i%3 else 1.5,Color(0.94,0.78,0.44,0.16+sin(clock*.5+i)*.07))
		var inset: float=18 if size.x>700 else 8
		draw_rect(Rect2(Vector2.ONE*inset,size-Vector2.ONE*inset*2),Color("8e7950"),false,1)
		for p in [Vector2(inset,inset),Vector2(size.x-inset,inset),Vector2(inset,size.y-inset),size-Vector2.ONE*inset]:
			draw_circle(p,3,Color("cbb17a"))
