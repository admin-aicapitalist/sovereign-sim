extends Node2D
const Simulation=preload("res://scripts/simulation.gd")
const Magic=preload("res://scripts/magic.gd")
const Cue=preload("res://scenes/combat_cue.tscn")
var cues: Dictionary={}
var cue_revision: int=-1
var sim: Simulation
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
var textures: Dictionary={}
var effect_textures: Dictionary={}
var hit_images: Dictionary={}
var selected: int=0
var hovered: int=0
var build_type: String=""
var mode_kind: String=""
var mode_key: String=""
var cursor:=Vector2.ZERO
var visible_rect:=Rect2()
var rendered_units: int=0
var font: Font=preload("res://assets/alegreya.ttf")
var terrain_material: ShaderMaterial
var fog_material: ShaderMaterial
var geography: ImageTexture
var vision: ImageTexture
var revision: int=-1
var fog_revision: int=-1
var draw_ms: float=0
var refresh_ms: float=0
var scenery: Array=[]
var rails: Array=[]

static func iso(p: Vector2) -> Vector2: return Vector2((p.x-p.y)*32,(p.x+p.y)*16)
static func uniso(p: Vector2) -> Vector2: return Vector2(p.x/64+p.y/32,p.y/32-p.x/64)
func _ready() -> void:
	for key in manifest: textures[key]=load(manifest[key].src)
	for key in sim.definitions.spells: effect_textures[key]=load("res://assets/effects/"+key+".png")
	for key in ["ward","haste","frost","loot_chest","loot_pouch"]:
		var name: String="aura_"+key if key in ["ward","haste","frost"] else key
		effect_textures[name]=load("res://assets/effects/"+name+".png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	terrain_material=ShaderMaterial.new(); terrain_material.shader=preload("res://scripts/terrain.gdshader")
	for key in ["grass","road","dirt","water","paving"]: terrain_material.set_shader_parameter(key,textures["terrain-"+key])
	fog_material=ShaderMaterial.new(); fog_material.shader=preload("res://scripts/fog.gdshader")
	make_plane(terrain_material,-10); make_plane(fog_material,100)
	refresh()
func make_plane(material: ShaderMaterial,z: int) -> void:
	var white:=Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	var sprite:=Sprite2D.new(); sprite.texture=ImageTexture.create_from_image(white); sprite.centered=false
	sprite.position=Vector2(-sim.size*32,0); sprite.scale=Vector2(sim.size*64,sim.size*32+32); sprite.material=material; sprite.z_index=z; add_child(sprite)
func refresh() -> void:
	if not is_node_ready(): return
	var began: int=Time.get_ticks_usec()
	if revision!=sim.revision:
		revision=sim.revision
		var data:=Image.create(sim.size,sim.size,false,Image.FORMAT_RGBA8)
		for t in sim.fixture.tiles: data.set_pixel(t.x,t.y,Color(1 if t.kind in ["water","bridge"] else 0,1 if t.kind=="path" else 0,1 if t.kind=="bridge" else 0,1))
		if geography==null: geography=ImageTexture.create_from_image(data)
		else: geography.update(data)
		prepare_scenery()
		terrain_material.set_shader_parameter("geography",geography); terrain_material.set_shader_parameter("palace_tile",sim.pos(sim.palace()))
	if fog_revision!=sim.fog_revision:
		fog_revision=sim.fog_revision
		var data:=Image.create(sim.size,sim.size,false,Image.FORMAT_RGBA8)
		for t in sim.fixture.tiles: data.set_pixel(t.x,t.y,Color(1 if t.explored else 0,1 if t.visible else 0,0,1))
		if vision==null: vision=ImageTexture.create_from_image(data)
		else: vision.update(data)
		fog_material.set_shader_parameter("vision",vision)
	terrain_material.set_shader_parameter("clock",sim.time)
	sync_cues(); queue_redraw(); refresh_ms=(Time.get_ticks_usec()-began)/1000.0
func sync_cues() -> void:
	if cue_revision!=sim.revision:
		for node in cues.values(): node.queue_free()
		cues.clear(); cue_revision=sim.revision
	var alive: Dictionary={}
	for e in sim.effects:
		if e.type not in ["hit","death","upgrade","relic","slam"] or not sim.is_visible(sim.pos(e)): continue
		var at:=iso(sim.pos(e))
		if not visible_rect.grow(150).has_point(at): continue
		var key: String=str(e.started)+"/"+str(e.x)+"/"+str(e.y)+"/"+e.type
		alive[key]=true
		if not cues.has(key):
			if cues.size()>=80: continue
			var cue=Cue.instantiate(); cue.kind=e.type; cue.position=at+Vector2(0,-15 if e.type=="hit" else 0)
			cue.color=Color("c77546") if e.type=="slam" else Color("e5c57c")
			cue.radius=e.value*45 if e.type=="slam" else 60 if e.type=="upgrade" else 27
			cue.z_index=102; add_child(cue); cues[key]=cue
		cues[key].sample(sim.time-e.started,e.life)
	for key in cues.keys():
		if not alive.has(key): cues[key].queue_free(); cues.erase(key)
static func terrain_hash(x: int,y: int) -> int:
	var n: int=(((x+731)*374761393)&0xffffffff)^(((y+919)*668265263)&0xffffffff)
	n=((n^(n>>13))*1274126177)&0xffffffff
	return (n^(n>>16))&0xffffffff
func prepare_scenery() -> void:
	scenery.clear(); rails.clear()
	for d in sim.fixture.decor:
		var n: int=terrain_hash(floori(d.x*13),floori(d.y*13))
		var key: String="rock"+str(n%4) if d.type=="rock" else "shrub"+str(n%3) if n%7==0 else "grass"+str(n%2) if n%3==0 else "flowers"+str(n%2)
		scenery.append({"at":iso(Vector2(d.x,d.y)),"key":key,"scale":0.62 if d.type=="rock" else 0.76})
	for i in range(0,sim.fixture.trees.size(),43):
		var t=sim.fixture.trees[i]; scenery.append({"at":iso(Vector2(t.x+0.42,t.y+0.18)),"key":"log" if i%2 else "stump","scale":0.77})
	for t in sim.fixture.tiles:
		var tile:=Vector2(t.x,t.y)
		if t.kind=="grass" and terrain_hash(t.x,t.y)%3!=0:
			for offset in [Vector2.UP,Vector2.RIGHT,Vector2.DOWN,Vector2.LEFT]:
				if sim.tile_at(tile+offset).get("kind","")=="water":
					var n: int=terrain_hash(t.x,t.y)
					scenery.append({"at":iso(tile+Vector2.ONE*0.5+offset*0.32),"key":"rock1" if n%5==0 else "reeds"+str(n%2),"scale":0.75}); break
		elif t.kind=="bridge":
			var along_y: bool=t.bridgeAxis=="y"
			for offset in ([Vector2.LEFT,Vector2.RIGHT] if along_y else [Vector2.UP,Vector2.DOWN]):
				if sim.tile_at(tile+offset).get("kind","")!="bridge": rails.append({"at":iso(tile+Vector2.ONE*0.5+offset*0.5),"flip":-1 if along_y else 1})
func hit_test(point: Vector2) -> int:
	for f in sim.flags.values():
		if not f.dead and Rect2(iso(sim.pos(f))+Vector2(-10,-75),Vector2(44,75)).has_point(point): return f.id
	var best: int=0; var distance: float=INF
	for u in sim.units:
		if u.dead or u.hostile and not sim.is_visible(u.pos): continue
		var a: Dictionary=manifest["unit_"+u.type]
		var d: float=point.distance_to(iso(u.pos)+Vector2(a.selection[0]*u.facing,a.selection[1]))
		if d<a.selectionRadius and d<distance: best=u.id; distance=d
	if best: return best
	var depth: float=-INF
	for b in sim.buildings:
		if b.dead or b.hostile and not sim.is_explored(sim.pos(b)): continue
		var a: Dictionary=manifest[b.type]; var factor: float=1.03 if b.type=="palace" else 0.89
		var origin: Vector2=iso(sim.pos(b))-Vector2(a.anchor[0],a.anchor[1])*factor
		var local: Vector2=(point-origin)/factor
		if local.x<0 or local.y<0 or local.x>=a.w or local.y>=a.h: continue
		if not hit_images.has(b.type): hit_images[b.type]=textures[b.type].get_image()
		var bitmap: Image=hit_images[b.type]
		if bitmap.get_pixel(mini(bitmap.get_width()-1,int(local.x/a.w*bitmap.get_width())),mini(bitmap.get_height()-1,int(local.y/a.h*bitmap.get_height()))).a<0.1: continue
		if iso(sim.pos(b)).y>depth: best=b.id; depth=iso(sim.pos(b)).y
	if best: return best
	for p in sim.loot:
		if not p.dead and sim.is_visible(sim.pos(p)) and Rect2(iso(sim.pos(p))+Vector2(-24,-30),Vector2(48,40)).has_point(point): return p.id
	return 0
func paint(key: String,at: Vector2,factor: float=1,frame: int=-1,facing: float=1,tint: Color=Color.WHITE) -> void:
	var a: Dictionary=manifest[key]
	var rect:=Rect2(-Vector2(a.anchor[0],a.anchor[1])*factor,Vector2(a.w,a.h)*factor)
	draw_set_transform(at,0,Vector2(facing,1))
	if frame<0: draw_texture_rect(textures[key],rect,false,tint)
	else:
		var f: Array=a.frames[frame].frame
		draw_texture_rect_region(textures[key],rect,Rect2(f[0],f[1],f[2],f[3]),tint)
	draw_set_transform(Vector2.ZERO)
func ring(at: Vector2,radius: float,color: Color,width: float=1.5) -> void:
	var points:=PackedVector2Array()
	for i in 49: points.append(at+Vector2(cos(i*TAU/48)*radius,sin(i*TAU/48)*radius*0.5))
	draw_polyline(points,color,width,true)
func health(at: Vector2,fraction: float,hostile: bool) -> void:
	draw_rect(Rect2(at,Vector2(38,5)),Color("242d26")); draw_rect(Rect2(at+Vector2.ONE,Vector2(36*clampf(fraction,0,1),3)),Color("be7257") if hostile else Color("c2c890"))
func aura(u,point: Vector2) -> void:
	for key in u.magic_buffs:
		if u.magic_buffs[key]<=0: continue
		var frame: int=int(sim.time*6)%12
		draw_texture_rect_region(effect_textures["aura_"+key],Rect2(point+Vector2(-32,-70),Vector2(64,96)),Rect2(frame%4*96,int(frame/4)*144,96,144),Color(1,1,1,minf(1,u.magic_buffs[key])))
func _draw() -> void:
	if sim==null or textures.is_empty(): return
	var began: int=Time.get_ticks_usec()
	var scene: Array=[]
	for t in sim.fixture.level.bridges:
		var p:=iso(Vector2(t.x,t.y))
		if visible_rect.grow(60).has_point(p): paint("bridge-deck",p,1,-1,-1 if t.axis=="y" else 1)
	for item in scenery:
		var p: Vector2=item.at
		if visible_rect.grow(60).has_point(p): paint(item.key,p,item.scale)
	for rail in rails:
		if visible_rect.grow(60).has_point(rail.at): scene.append({"y":rail.at.y,"rail":rail,"at":rail.at})
	for ruin in sim.ruins:
		var p:=iso(Vector2(ruin.x,ruin.y))
		if visible_rect.grow(100).has_point(p):
			for i in 8: paint("rock"+str(i%4),p+Vector2(sin(i*7.1)*ruin.size*15,cos(i*5.2)*ruin.size*7),0.6)
	for tree in sim.fixture.trees:
		var p:=iso(Vector2(tree.x,tree.y))
		if visible_rect.grow(150).has_point(p): scene.append({"y":p.y,"tree":tree,"at":p})
	for b in sim.buildings:
		var p:=iso(sim.pos(b))
		if not b.dead and (not b.hostile or sim.is_explored(sim.pos(b))) and visible_rect.grow(250).has_point(p): scene.append({"y":p.y+6,"building":b,"at":p})
	for pile in sim.loot:
		var p:=iso(sim.pos(pile))
		if not pile.dead and sim.is_visible(sim.pos(pile)) and visible_rect.grow(60).has_point(p): scene.append({"y":p.y,"loot":pile,"at":p})
	rendered_units=0
	for u in sim.units:
		var p:=iso(u.pos)
		if not u.dead and (not u.hostile or sim.is_visible(u.pos)) and visible_rect.grow(70).has_point(p): scene.append({"y":p.y,"unit":u,"at":p}); rendered_units+=1
	scene.sort_custom(func(a,b):return a.y<b.y)
	for item in scene:
		var p: Vector2=item.at
		if item.has("rail"):
			paint("bridge-rail",p,1,-1,item.rail.flip)
		elif item.has("tree"):
			paint(item.tree.type,p+Vector2(sin(sim.time*0.6+item.tree.x)*0.65,0),item.tree.scale*0.84)
		elif item.has("building"):
			var b=item.building; var factor: float=1.03 if b.type=="palace" else 0.89
			if selected==int(b.id) or hovered==int(b.id): ring(p,b.size*24,Color("f0d591"))
			paint(b.type,p,factor,-1,1,Color(1,1,1,0.4+0.6*b.progress))
			if b.get("tier",1)>1:
				ring(p,b.size*20,Color("a99758"),2); draw_string(font,p+Vector2(-6,-100),"II",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f1d598"))
			if b.get("upgrade_remaining",0)>0: health(p+Vector2(-19,-100),1-b.upgrade_remaining/sim.definition_of(b).upgrade_time,false)
			if b.progress<1: health(p+Vector2(-19,-85),b.progress,false)
			elif sim.time-b.last_hit<3 or selected==int(b.id): health(p+Vector2(-19,-90),b.hp/b.max_hp,b.hostile)
			var a: Dictionary=manifest[b.type]
			for effect in a.get("effects",[]):
				var at: Vector2=p+(Vector2(effect.at[0],effect.at[1])-Vector2(a.anchor[0],a.anchor[1]))*factor
				if effect.type=="smoke":
					for i in 3:
						var t: float=fmod(sim.time*0.14+i*0.33+b.id*0.11,1)
						draw_circle(at+Vector2(sin(t*7+b.id)*5,-t*31),2+t*5,Color(0.83,0.84,0.72,(1-t)*0.13))
				elif effect.type=="fire": draw_circle(at,4+sin(sim.time*10+b.id),Color(0.92,0.61,0.26,0.4))
		elif item.has("loot"):
			var pile=item.loot
			if selected==int(pile.id): ring(p,20,Color("e0c985"))
			if not pile.get("items",[]).is_empty(): ring(p,22+sin(sim.time*3)*2,Color("d8b56d"),2)
			var texture: Texture2D=effect_textures[pile.type]
			draw_texture_rect(texture,Rect2(p+Vector2(-26,-34),Vector2(52,48)),false)
		else:
			var u=item.unit; aura(u,p)
			if selected==u.id or hovered==u.id: ring(p,15,Color("f0d591"))
			var frame: int=0
			if u.attacking>0 or (u.state.begins_with("Building") or u.state.begins_with("Repairing")) and u.path_index>=u.path.size(): frame=5+int(sim.time*8+u.id)%3
			elif u.path_index<u.path.size(): frame=1+int(u.animation)%4
			var boss: bool=u.id==sim.mission.boss_id
			var offset_at:=Vector2.ZERO
			if not u.pending_attack.is_empty():
				var preparing: float=1-u.pending_attack.remaining/u.pending_attack.duration
				offset_at=Vector2(-u.facing*4*sin(preparing*PI),-2*sin(preparing*PI)); frame=5+mini(2,int(preparing*3))
			var tint:=Color(1.45,1.2,0.95) if sim.time-u.last_hit<0.13 else Color("d9b18a") if boss else Color.WHITE
			paint("unit_"+u.type,p+offset_at,1.3 if boss else 1,frame,u.facing,tint)
			if boss:
				ring(p,27,Color("cd7447"),2)
				draw_string(font,p+Vector2(-57,-103),"EMBER WARLORD",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1c083"))
				health(p+Vector2(-19,-95),u.hp/u.max_hp,true)
			if not u.equipment.is_empty(): draw_circle(p+Vector2(12,-30),2.5,Color("e5bc67"))
			var offset: float=manifest["unit_"+u.type].healthOffset
			if sim.time-u.last_hit<3 or u.id==selected: health(p+Vector2(-19,offset),u.hp/u.max_hp,u.hostile)
			if u.hero and u.level>1: draw_string(font,p+Vector2(-9,offset-4),"★ %d"%u.level,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e0ca86"))
			if u.type=="collector" and u.carried>0: draw_circle(p+Vector2(7,-17),2,Color("e2bf66"))
	for f in sim.flags.values():
		if f.dead: continue
		var p:=iso(sim.pos(f)); var wave: float=sin(sim.time*3+f.id)*2
		if selected==int(f.id): ring(p,22,Color("f0d591"))
		draw_line(p,p+Vector2(0,-65),Color("d1b880"),2)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-65),p+Vector2(28,-61+wave),p+Vector2(24,-44+wave),p+Vector2(0,-47)]),Color("963f33") if f.type=="attack" else Color("627c69"))
		draw_string(font,p+Vector2(4,-50),str(int(f.reward)),HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("fff0c8"))
	for projectile in sim.projectiles:
		if not sim.is_visible(sim.pos(projectile)): continue
		var target=sim.entity(projectile.target)
		if target==null: continue
		var a:=iso(sim.pos(projectile))+Vector2(0,-19); var b:=iso(sim.pos(target))+Vector2(0,-19)
		var direction: Vector2=(b-a).normalized()
		if projectile.type=="arrow": draw_line(a-direction*9,a,Color("e1d8b0"),1.3,true)
		else:
			for i in range(5,-1,-1): draw_circle(a-direction*i*4,3+i*0.6,Color(0.9,0.53,0.23,0.5-i*0.07))
			draw_circle(a,3.2,Color("f1d6a1"))
	if sim.mission.slam_remaining>0:
		var at:=Vector2(sim.mission.slam_x,sim.mission.slam_y)
		if sim.is_visible(at):
			var p:=iso(at); var radius: float=sim.definitions.mission.slam_radius*45
			var points:=PackedVector2Array()
			for i in 64: points.append(p+Vector2(cos(i*TAU/64)*radius,sin(i*TAU/64)*radius*0.5))
			draw_colored_polygon(points,Color(0.9,0.25,0.08,0.2)); ring(p,radius,Color("eeaa62"),3)
			ring(p,radius*(1-sim.mission.slam_remaining/sim.definitions.mission.slam_warning),Color("f8d390"),2)
			draw_string(font,p+Vector2(-38,12),"GROUND SLAM",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffe6bb"))
	draw_effects()
	draw_preview(); draw_ms=(Time.get_ticks_usec()-began)/1000.0
func draw_effects() -> void:
	for e in sim.effects:
		var at:=Vector2(e.x,e.y)
		if e.type!="spell_farsight" and not sim.is_visible(at): continue
		var p:=iso(at); var age: float=sim.time-e.started; var t: float=age/e.life
		if t<0 or t>=1 or not visible_rect.grow(500).has_point(p): continue
		if e.type.begins_with("spell_"):
			var key: String=e.type.trim_prefix("spell_"); var frame: int=clampi(int(t*16),0,15)
			draw_texture_rect_region(effect_textures[key],Rect2(p+Vector2(-256,-480),Vector2(512,640)),Rect2(frame%4*384,int(frame/4)*480,384,480))
		elif e.type in ["heal","level"]:
			ring(p,12+t*40,Color(0.82,0.83,0.57,1-t))
			for i in 8: draw_circle(p+Vector2(cos(i*0.785)*(8+t*15),-t*40+sin(i*0.785)*5),1.6,Color(0.9,0.85,0.63,1-t))
		elif e.type in ["death","upgrade","relic","slam"]: pass
		elif e.type=="gold": draw_string(font,p+Vector2(-10,-25-t*25),"+%d"%e.value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.96,0.87,0.62,1-t))
		else:
			for i in (24 if e.type=="collapse" else 7):
				var spread: float=(42 if e.type=="collapse" else 16)*fmod(i*0.371+0.1,1)
				draw_circle(p+Vector2(cos(i*1.91)*spread*t,-12+sin(i*1.91)*spread*t-t*15),1+fmod(i*0.61,2),Color(0.82,0.73,0.54,1-t))
			if e.type=="hit": draw_string(font,p+Vector2(-5,-30-t*17),str(ceili(e.value)),HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(0.91,0.82,0.63,1-t))
func draw_preview() -> void:
	if mode_kind=="build":
		var tile:=Vector2i(cursor.floor()); var d: Dictionary=sim.definitions.buildings[mode_key]
		var color:=Color(0.65,0.8,0.5,0.45) if sim.can_build(mode_key,tile) and sim.gold>=d.cost else Color(0.9,0.25,0.2,0.45)
		for y in range(tile.y,tile.y+int(d.size)):
			for x in range(tile.x,tile.x+int(d.size)): draw_colored_polygon(PackedVector2Array([iso(Vector2(x,y)),iso(Vector2(x+1,y)),iso(Vector2(x+1,y+1)),iso(Vector2(x,y+1))]),color)
		paint(mode_key,iso(Vector2(tile)+Vector2.ONE*d.size/2),0.89,-1,1,Color(1,1,1,0.6))
	elif mode_kind=="spell":
		var hit=sim.entity(hit_test(iso(cursor))); var point: Vector2=Magic.target_point(sim,mode_key,cursor,hit)
		var d: Dictionary=sim.definitions.spells[mode_key]
		var valid: bool=Magic.available(sim,mode_key) and sim.gold>=d.cost and sim.cooldowns[mode_key]<=0 and (mode_key=="farsight" or sim.is_visible(point) and not Magic.targets(sim,mode_key,point).is_empty())
		ring(iso(point),d.radius*sqrt(2)*32,Color(d.color) if valid else Color("b27464"))
	elif mode_kind=="bounty": ring(iso(cursor),20,Color("ecce8b"))
