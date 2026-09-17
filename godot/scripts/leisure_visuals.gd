extends RefCounted
## Shared scenery atlases and occupied-building signals, sampled from game time.
var catalog: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/leisure_cast.json"))
var textures: Dictionary={}
func prepare() -> void:
	for key in catalog: textures[key]=load(catalog[key].src)
func performers(world,b: Dictionary,at: Vector2) -> Array:
	if b.dead or b.progress<1: return []
	var meta: Dictionary=world.manifest[b.type]; var result: Array=[]
	for visitor in meta.get("visitors",[]):
		var p: Vector2=at+(Vector2(visitor.at[0],visitor.at[1])-Vector2(meta.anchor[0],meta.anchor[1]))*0.89
		result.append({"y":p.y,"at":p,"performer":visitor,"building_id":b.id})
	return result
func frame(kind: String,time: float,phase: float) -> int:
	var info: Dictionary=catalog[kind]
	return posmod(floori(time*info.fps+phase*info.frames.size()),info.frames.size())
func draw_performer(world,item: Dictionary) -> void:
	var actor: Dictionary=item.performer; var info: Dictionary=catalog[actor.actor]
	var index: int=frame(actor.actor,world.presentation_time,actor.phase+item.building_id*0.017)
	var cell: Array=info.frames[index]; var size:=Vector2(info.size[0],info.size[1])*0.89
	var origin: Vector2=item.at-Vector2(info.anchor[0],info.anchor[1])*0.89
	world.draw_texture_rect_region(textures[actor.actor],Rect2(origin,size),Rect2(cell[0],cell[1],cell[2],cell[3]))
func occupied(world,b: Dictionary,at: Vector2,factor: float,occupants: Array) -> void:
	if occupants.is_empty() or b.dead or b.progress<1: return
	var meta: Dictionary=world.manifest[b.type]; var anchor:=Vector2(meta.anchor[0],meta.anchor[1])
	var time: float=world.presentation_time
	var glow: float=0.78+0.14*sin(time*3.1+b.id)+0.08*sin(time*7.3+b.id)
	var lamps: Array=meta.get("lanterns",[{"at":[anchor.x-7,anchor.y-23],"color":"efb468"},{"at":[anchor.x+25,anchor.y-38],"color":"efb468"}])
	for lamp in lamps:
		var p: Vector2=at+(Vector2(lamp.at[0],lamp.at[1])-anchor)*factor; var color:=Color(lamp.color)
		for i in range(4,0,-1):
			color.a=(0.022 if i>1 else 0.23)*glow; world.draw_circle(p,(2+i*2.0)*factor,color)
	# A second, warm pennant is an occupancy signal, separate from the civic standards.
	var top: float=meta.bounds[1]-anchor.y
	var mast: Vector2=at+Vector2(14,top-6)*factor
	world.draw_line(mast+Vector2(0,18)*factor,mast+Vector2(0,-17)*factor,Color("a78058"),1.3,true)
	var shadow: bool=occupants.any(func(u):return world.sim.Journey.is_shadow(u))
	world.atmosphere.cloth(world,mast+Vector2(0,-16)*factor,Vector2(24,1)*factor,12*factor,time,b.id*0.7,Color("a52646") if shadow else Color("b99143"),false)
	world.draw_string(world.font,mast+Vector2(-9,-22)*factor,"%d inside"%occupants.size(),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("f4ddae"))
