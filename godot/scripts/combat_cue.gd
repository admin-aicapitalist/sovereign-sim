@tool
extends Node2D
## An editor-previewable timeline, sampled from simulation time so pause/save are exact.
@export_enum("hit", "death", "upgrade", "relic", "slam") var kind: String="hit"
@export var progress: float=0.0:
	set(value):
		progress=value; queue_redraw()
@export var color: Color=Color("f1d59a")
@export var radius: float=28
func sample(age: float,life: float) -> void:
	$AnimationPlayer.seek(clampf(age/life,0,1),true)
func _ready() -> void:
	$AnimationPlayer.play("cue"); $AnimationPlayer.pause()
func _draw() -> void:
	var t: float=progress; var ink:=Color(color,1-t)
	if kind in ["upgrade","relic","slam"]:
		var points:=PackedVector2Array()
		for i in 65:
			var a: float=i*TAU/64; points.append(Vector2(cos(a),sin(a)*0.5)*radius*(0.3+0.7*t))
		draw_polyline(points,ink,3 if kind=="slam" else 2,true)
	for i in (16 if kind=="death" else 10):
		var angle: float=i*2.39996
		var from:=Vector2(cos(angle),sin(angle)*0.5)*radius*t
		from.y-=sin(t*PI)*(28 if kind=="death" else 12)
		if kind in ["relic","upgrade"]: from.y-=t*55
		var to: Vector2=from+Vector2(cos(angle),sin(angle))*maxf(1,7*(1-t))
		draw_line(from,to,ink,2,true)
