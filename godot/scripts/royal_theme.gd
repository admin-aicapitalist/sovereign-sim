extends RefCounted
## Shared typography and tactile nine-slice materials for all native Controls.
const DISPLAY=preload("res://assets/cinzel.ttf")
const BODY=preload("res://assets/alegreya.ttf")
const ITALIC=preload("res://assets/alegreya-italic.ttf")
const GOLD=Color("dac08a")
const INK=Color("423929")
static var boxes: Dictionary={}

static func box(kind: String,margin: float=12) -> StyleBoxTexture:
	var key:=kind+str(margin)
	if boxes.has(key): return boxes[key]
	var out:=StyleBoxTexture.new(); out.texture=load("res://assets/ui/"+kind+".png")
	out.texture_margin_left=16; out.texture_margin_right=16; out.texture_margin_top=16; out.texture_margin_bottom=16
	out.axis_stretch_horizontal=StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	out.axis_stretch_vertical=StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	out.set_content_margin_all(margin); boxes[key]=out
	if kind.begins_with("button"):
		out.content_margin_top=5; out.content_margin_bottom=5
	return out

static func icon(key: String) -> Texture2D:
	return load("res://assets/ui/"+key+".svg")

static func make() -> Theme:
	var t:=Theme.new(); t.default_font=BODY; t.default_font_size=18
	for state in ["normal","hover","pressed","disabled"]:
		t.set_stylebox(state,"Button",box("button" if state=="normal" else "button-"+state,9))
	t.set_color("font_color","Button",Color("e9d9b3")); t.set_color("font_hover_color","Button",Color("fff0cb"))
	t.set_color("font_pressed_color","Button",Color("fff0cb")); t.set_color("font_disabled_color","Button",Color("a49c84"))
	t.set_stylebox("focus","Button",box("button-hover",9))
	t.set_stylebox("normal","LineEdit",box("button",12)); t.set_stylebox("focus","LineEdit",box("button-hover",12))
	t.set_color("font_color","LineEdit",Color("f2e4c6")); t.set_color("font_placeholder_color","LineEdit",Color("b6ab92"))
	t.set_color("caret_color","LineEdit",GOLD); t.set_color("selection_color","LineEdit",Color("714c34"))
	t.set_stylebox("panel","TooltipPanel",box("timber",14)); t.set_color("font_color","TooltipLabel",Color("f0e1be"))
	t.set_font_size("font_size","TooltipLabel",17)
	for type in ["HScrollBar","VScrollBar"]:
		var track:=StyleBoxFlat.new(); track.bg_color=Color("26251f"); track.set_content_margin_all(3)
		var grab:=StyleBoxFlat.new(); grab.bg_color=Color("a58e5f"); grab.set_content_margin_all(3)
		t.set_stylebox("scroll",type,track)
		for state in ["grabber","grabber_highlight","grabber_pressed"]: t.set_stylebox(state,type,grab)
		var pixel:=Image.create(1,1,false,Image.FORMAT_RGBA8); pixel.fill(Color.TRANSPARENT)
		for empty in ["increment","increment_highlight","increment_pressed","decrement","decrement_highlight","decrement_pressed"]: t.set_icon(empty,type,ImageTexture.create_from_image(pixel))
	return t

static func primary(button: Button) -> void:
	button.add_theme_stylebox_override("normal",box("gold",14)); button.add_theme_stylebox_override("hover",box("gold-hover",14)); button.add_theme_stylebox_override("pressed",box("gold",14))
	for state in ["font_color","font_hover_color","font_pressed_color"]: button.add_theme_color_override(state,INK)
	button.add_theme_font_override("font",DISPLAY); button.add_theme_font_size_override("font_size",16)

static func active(button: Button,on: bool) -> void:
	button.add_theme_stylebox_override("normal",box("button-pressed" if on else "button",9))
