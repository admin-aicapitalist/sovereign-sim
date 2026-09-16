extends RefCounted
## Stateless scenery animation: follows the simulation clock, including pause,
## speed changes and loading. No gameplay RNG, particle nodes or saved state.
var art: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/atmosphere.json"))

static func wind(time: float) -> float:
	return 0.64+0.21*sin(time*0.47)+0.12*sin(time*1.13+1.7)

static func cloth_point(at: Vector2,span: Vector2,height: float,u: float,v: float,time: float,phase: float) -> Vector2:
	var gust: float=wind(time)
	var ripple: float=u*8.2-time*(4.1)+phase
	var lift: float=height*u*((0.19+gust*0.19)*sin(ripple)+0.065*sin(ripple*1.8+v*1.6))
	var taper: float=1.0-0.24*smoothstep(0.72,1.0,u)
	return at+Vector2(span.x*u*(0.83+gust*0.18)+height*0.055*u*sin(ripple+0.8),span.y*u+height*v*taper+lift)

func cloth(canvas: Node2D,at: Vector2,span: Vector2,height: float,time: float,phase: float,field: Color,royal: bool,opacity: float=1.0) -> void:
	var top:=PackedVector2Array(); var bottom:=PackedVector2Array()
	const STRIPS: int=16
	for i in STRIPS+1:
		var u: float=float(i)/STRIPS
		top.append(cloth_point(at,span,height,u,0,time,phase))
		bottom.append(cloth_point(at,span,height,u,1,time,phase))
	for i in STRIPS:
		var u: float=(i+0.5)/STRIPS
		var light: float=0.91+0.18*cos(u*8.2-time*4.1+phase)
		var color: Color=Color("a83e32") if royal and i<3 else field
		color=Color(color.r*light,color.g*light,color.b*light,opacity)
		canvas.draw_colored_polygon(PackedVector2Array([top[i],top[i+1],bottom[i+1],bottom[i]]),color)
	var trim:=Color("ddbb78"); trim.a=opacity*0.85
	canvas.draw_polyline(top,trim,0.55,true)
	canvas.draw_polyline(bottom,trim,0.55,true)
	canvas.draw_line(top[-1],bottom[-1],trim,0.55,true)
	if royal:
		var diamond:=PackedVector2Array()
		for uv in [Vector2(0.46,0.51),Vector2(0.60,0.14),Vector2(0.76,0.51),Vector2(0.60,0.88)]:
			diamond.append(cloth_point(at,span,height,uv.x,uv.y,time,phase))
		canvas.draw_colored_polygon(diamond,Color(0.58,0.15,0.12,opacity))

func chimney(canvas: Node2D,at: Vector2,factor: float,time: float,seed: int) -> void:
	# Overlapping soft billows start inside the chimney mouth and expand slowly.
	# Older smoke bends downwind; a short vertical stem keeps the source readable.
	for i in 10:
		var age: float=fposmod(time/6.8+float(i)/10.0+seed*0.137,1.0)
		var seconds: float=age*6.8
		var breeze: float=wind(time-seconds*0.45)
		var drift: float=pow(age,1.5)*(21.0+19.0*breeze)
		var curl: float=sin(age*9.0-time*0.8+seed)*age*4.0
		var center: Vector2=at+Vector2(drift+curl,-age*64.0)*factor
		var size: float=(9.0+age*36.0)*factor
		var alpha: float=smoothstep(0.0,0.10,age)*(1.0-smoothstep(0.38,1.0,age))*0.58
		var texture: Texture2D=canvas.arcane_textures["smoke-"+str((i+seed)%4)]
		canvas.draw_set_transform(center,sin(i*2.7+seed)*0.55+age*0.45)
		canvas.draw_texture_rect(texture,Rect2(Vector2(-size*0.5,-size*0.57),Vector2(size,size*1.14)),false,Color(1.06,1.06,1.01,alpha))
	canvas.draw_set_transform(Vector2.ZERO)

func building(canvas: Node2D,b: Dictionary,at: Vector2,factor: float) -> void:
	var meta: Dictionary=canvas.manifest[b.type]
	var anchor:=Vector2(meta.anchor[0],meta.anchor[1])
	if b.progress>=1.0:
		for effect in meta.get("effects",[]):
			if effect.type=="smoke":
				chimney(canvas,at+(Vector2(effect.at[0],effect.at[1])-anchor)*factor,factor,canvas.presentation_time,int(b.id))
	var flags: Array=art.get(b.type,{}).get("flags",[])
	for i in flags.size():
		var flag: Dictionary=flags[i]
		cloth(canvas,at+(Vector2(flag.at[0],flag.at[1])-anchor)*factor,Vector2(flag.span[0],flag.span[1])*factor,flag.height*factor,canvas.presentation_time,b.id*0.71+i*1.9,Color("eee0b5"),true,0.4+0.6*b.progress)

func bounty(canvas: Node2D,f: Dictionary,at: Vector2) -> void:
	canvas.draw_line(at+Vector2(1,1),at+Vector2(1,-69),Color("584732"),2.5,true)
	canvas.draw_line(at,at+Vector2(0,-69),Color("cfb278"),1.2,true)
	canvas.draw_circle(at+Vector2(0,-70),1.7,Color("e8ce92"))
	cloth(canvas,at+Vector2(0,-66),Vector2(34,2),19,canvas.presentation_time,f.id*0.71,Color("a44938") if f.type=="attack" else Color("688372"),false)
	# Reward stays crisp while the cloth around it ripples.
	var label: Vector2=cloth_point(at+Vector2(0,-66),Vector2(34,2),19,0.16,0.78,canvas.presentation_time,f.id*0.71)
	canvas.draw_string(canvas.font,label,str(int(f.reward)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0c8"))
