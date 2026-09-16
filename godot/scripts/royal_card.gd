extends Button
const Royal=preload("res://scripts/royal_theme.gd")
var artwork: TextureRect
var heading: Label
var price: Label
var column: VBoxContainer

func _ready() -> void:
	mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled"]:
		add_theme_stylebox_override(state,Royal.box("card-hover" if state=="hover" else "card-selected" if state=="pressed" else "card",8))
	column=VBoxContainer.new(); column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); column.offset_left=7; column.offset_right=-7; column.offset_top=5; column.offset_bottom=-5; column.add_theme_constant_override("separation",0); column.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(column)
	artwork=TextureRect.new(); artwork.custom_minimum_size=Vector2(0,48); artwork.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; artwork.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; artwork.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(artwork)
	heading=Label.new(); heading.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; heading.add_theme_font_size_override("font_size",15); heading.add_theme_color_override("font_color",Royal.INK); heading.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(heading)
	price=Label.new(); price.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; price.add_theme_font_size_override("font_size",14); price.add_theme_color_override("font_color",Color("796039")); price.mouse_filter=Control.MOUSE_FILTER_IGNORE; column.add_child(price)

func configure(caption: String,texture: Texture2D,chosen: bool,locked: bool) -> void:
	var lines:=caption.split("\n"); heading.text=lines[0]; price.text=lines[1] if lines.size()>1 else ""
	artwork.texture=texture; disabled=locked
	artwork.modulate=Color(0.65,0.65,0.59,0.66) if locked else Color.WHITE
	column.modulate=Color(1,1,1,0.65) if locked else Color.WHITE
	add_theme_stylebox_override("normal",Royal.box("card-selected" if chosen else "card",8))
