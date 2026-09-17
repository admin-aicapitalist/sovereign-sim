extends Node2D
const Simulation=preload("res://scripts/simulation.gd")
const Magic=preload("res://scripts/magic.gd")
const CharacterAnimation=preload("res://scripts/character_animation.gd")
const Cue=preload("res://scenes/combat_cue.tscn")
const Arcane=preload("res://scripts/arcane_layer.gd")
const Leisure=preload("res://scripts/leisure_visuals.gd")
var leisure:=Leisure.new()
const Atmosphere=preload("res://scripts/atmosphere.gd")
var atmosphere:=Atmosphere.new()
var arcane_layers: Array=[]
var arcane_effects: Array=[]
var arcane_units: Array=[]
var arcane_projectiles: Array=[]
var arcane_art: Dictionary={}
var arcane_textures: Dictionary={}
var plumes: Dictionary={}
var plume_texture: ImageTexture
var hit_reactions: Dictionary={}
var presentation_time: float=0
var camera_impulse:=Vector2.ZERO
var cues: Dictionary={}
var cue_revision: int=-1
var sim: Simulation
var manifest: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/assets.json"))
var textures: Dictionary={}
var portraits: Dictionary={}
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
	leisure.prepare()
	manifest.unit_wizard_cast=JSON.parse_string(FileAccess.get_file_as_string("res://data/casting.json"))
	arcane_art=JSON.parse_string(FileAccess.get_file_as_string("res://data/arcane_art.json"))
	for key in arcane_art: arcane_textures[key]=load(arcane_art[key].src)
	var white:=Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE); plume_texture=ImageTexture.create_from_image(white)
	for key in manifest: textures[key]=load(manifest[key].src)
	for key in atmosphere.art: textures[key]=load(atmosphere.art[key].src)
	for key in manifest:
		if manifest[key].has("portrait"): portraits[key]=load(manifest[key].portrait)
	for key in ["loot_chest","loot_pouch"]: effect_textures[key]=load("res://assets/effects/"+key+".png")
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	terrain_material=ShaderMaterial.new(); terrain_material.shader=preload("res://scripts/terrain.gdshader")
	for key in ["grass","road","dirt","water","paving"]: terrain_material.set_shader_parameter(key,textures["terrain-"+key])
	fog_material=ShaderMaterial.new(); fog_material.shader=preload("res://scripts/fog.gdshader")
	make_plane(terrain_material,-10); make_plane(fog_material,100)
	for i in 3:
		var layer:=Arcane.new(); layer.world=self; layer.pass_index=i; layer.z_index=-1 if i==0 else i
		add_child(layer); arcane_layers.append(layer)
	refresh()
func make_plane(material: ShaderMaterial,z: int) -> void:
	var white:=Image.create(1,1,false,Image.FORMAT_RGBA8); white.fill(Color.WHITE)
	var sprite:=Sprite2D.new(); sprite.texture=ImageTexture.create_from_image(white); sprite.centered=false
	sprite.position=Vector2(-sim.size*32,0); sprite.scale=Vector2(sim.size*64,sim.size*32+32); sprite.material=material; sprite.z_index=z; add_child(sprite)
func refresh() -> void:
	if not is_node_ready(): return
	var began: int=Time.get_ticks_usec()
	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS if scale.x<0.85 else CanvasItem.TEXTURE_FILTER_LINEAR
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
	sync_arcane(); sync_cues(); queue_redraw(); refresh_ms=(Time.get_ticks_usec()-began)/1000.0
func sync_arcane() -> void:
	arcane_effects.clear(); arcane_units.clear(); arcane_projectiles.clear(); hit_reactions.clear(); camera_impulse=Vector2.ZERO
	var spell_count: int=0; var impact_count: int=0
	for i in range(sim.effects.size()-1,-1,-1):
		var e: Dictionary=sim.effects[i]
		if not (e.type.begins_with("spell_") or e.type in ["meteor_impact","fire","slam","hit","swing","death"]): continue
		var p:=iso(sim.pos(e))
		if not sim.is_visible(sim.pos(e)) or not visible_rect.grow(320).has_point(p): continue
		if e.type.begins_with("spell_") or e.type=="meteor_impact":
			if spell_count>=24: continue
			spell_count+=1
		else:
			if impact_count>=80: continue
			impact_count+=1
		arcane_effects.push_front(e)
		if e.type=="hit" and e.has("target") and not hit_reactions.has(int(e.target)): hit_reactions[int(e.target)]=e
		var age: float=presentation_time-e.started
		if e.type in ["meteor_impact","slam"] and age>=0 and age<0.45 and visible_rect.has_point(p):
			var strength: float=3.5*pow(1-age/0.45,2)
			camera_impulse+=Vector2(sin(age*83),sin(age*67+1))*strength
	camera_impulse=camera_impulse.limit_length(4)
	for u in sim.units:
		if arcane_units.size()>=192: break
		if u.type!="wizard" and u.magic_buffs.ward<=0 and u.magic_buffs.haste<=0 and u.magic_buffs.frost<=0: continue
		if u.dead or u.inside>0 or not sim.is_visible(u.pos) or not visible_rect.grow(90).has_point(iso(u.pos)): continue
		arcane_units.append(u)
	for p in sim.projectiles:
		if arcane_projectiles.size()>=128: break
		if sim.is_visible(sim.pos(p)) and visible_rect.grow(90).has_point(iso(sim.pos(p))): arcane_projectiles.append(p)
	for layer in arcane_layers: layer.queue_redraw()
	sync_plumes()
func sync_plumes() -> void:
	var active: Dictionary={}
	for e in arcane_effects:
		if e.type not in ["spell_meteor","meteor_impact","fire"]: continue
		var age: float=presentation_time-e.started; var t: float=clampf(age/e.life,0,1)
		var falling: bool=e.type=="spell_meteor"; var major: bool=e.type=="meteor_impact"
		var duration: float=0.75 if major else 0.4
		if not falling and age>=duration: continue
		for i in (5 if major else 1):
			if active.size()>=32: break
			var key: String=str(e.get("serial",0))+"/"+str(e.started)+"/"+str(i)
			active[key]=true
			if not plumes.has(key):
				var sprite:=Sprite2D.new(); sprite.texture=plume_texture; sprite.centered=false; sprite.offset=Vector2(-0.5,-1)
				var shader:=ShaderMaterial.new(); shader.shader=preload("res://scripts/arcane_plume.gdshader"); sprite.material=shader
				sprite.z_index=3; add_child(sprite); plumes[key]=sprite
			var sprite: Sprite2D=plumes[key]
			if falling:
				sprite.position=iso(sim.pos(e))+Vector2(145,-330)*pow(1-t,1.1)
				sprite.rotation=Vector2(145,-330).angle()+PI/2; sprite.scale=Vector2(69,165)
			else:
				sprite.position=iso(sim.pos(e))+Arcane.ellipse(i*TAU/5,18+age*75) if major else iso(sim.pos(e))+Vector2(0,-10)
				sprite.rotation=(i-2)*0.22 if major else 0
				sprite.scale=Vector2(62+age*58,78+sin(age/duration*PI)*60) if major else Vector2(37,51)
			sprite.material.set_shader_parameter("age",age+i*0.17)
			sprite.material.set_shader_parameter("power",0.85 if falling else pow(1-age/duration,1.3)*0.85)
	for key in plumes.keys():
		if not active.has(key): plumes[key].queue_free(); plumes.erase(key)
func wizard_visual(u) -> Dictionary:
	var direction: int=CharacterAnimation.direction(u.heading)
	var pose: int=-1
	var spell_age: float=presentation_time-u.last_spell.get("at",-100)
	if u.path_index>=u.path.size():
		if spell_age>=0 and spell_age<0.9: pose=8+clampi(int(spell_age/0.9*8),0,7)
		elif not u.pending_attack.is_empty(): pose=clampi(int((1-u.pending_attack.remaining/u.pending_attack.duration)*9),0,8)
		elif u.attacking>0:
			var recovery: float=0.2 if sim.mission.id=="ember_crown" else 0.34
			pose=8+clampi(int((1-u.attacking/recovery)*8),0,7)
	var cast_frame: Dictionary=manifest.unit_wizard_cast.frames[maxi(0,pose)*8+direction]
	return {"key":"unit_wizard_cast" if pose>=0 else "unit_wizard","frame":pose*8+direction if pose>=0 else CharacterAnimation.frame(u,sim,manifest.unit_wizard),"sockets":cast_frame.sockets}
func sync_cues() -> void:
	if cue_revision!=sim.revision:
		for node in cues.values(): node.queue_free()
		cues.clear(); cue_revision=sim.revision
	var alive: Dictionary={}
	for e in sim.effects:
		if e.type not in ["upgrade","relic"] or not sim.is_visible(sim.pos(e)): continue
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
		if u.dead or u.inside>0 or u.hostile and not sim.is_visible(u.pos): continue
		var boss: bool=u.id==sim.mission.boss_id
		var a: Dictionary=manifest["unit_warlord" if boss else "unit_"+u.type]
		var factor: float=1.15 if boss else 1
		var d: float=point.distance_to(iso(u.pos)+Vector2(a.selection[0],a.selection[1])*factor)
		if d<a.selectionRadius*factor and d<distance: best=u.id; distance=d
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
	if frame>=0 and a.frames[frame].has("size"):
		var cell: Dictionary=a.frames[frame]
		rect=Rect2(-Vector2(cell.anchor[0],cell.anchor[1])*factor,Vector2(cell["size"][0],cell["size"][1])*factor)
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
	if u.magic_buffs.haste>0: ring(point,16,Color(0.85,0.69,0.42,0.25),1)
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
		if not b.dead and (not b.hostile or sim.is_explored(sim.pos(b))) and visible_rect.grow(250).has_point(p):
			scene.append({"y":p.y+6,"building":b,"at":p})
			scene.append_array(leisure.performers(self,b,p))
	for pile in sim.loot:
		var p:=iso(sim.pos(pile))
		if not pile.dead and sim.is_visible(sim.pos(pile)) and visible_rect.grow(60).has_point(p): scene.append({"y":p.y,"loot":pile,"at":p})
	rendered_units=0
	for u in sim.units:
		var p:=iso(u.pos)
		if not u.dead and u.inside==0 and (not u.hostile or sim.is_visible(u.pos)) and visible_rect.grow(70).has_point(p): scene.append({"y":p.y,"unit":u,"at":p}); rendered_units+=1
	scene.sort_custom(func(a,b):return a.y<b.y)
	for item in scene:
		var p: Vector2=item.at
		if item.has("performer"):
			leisure.draw_performer(self,item)
		elif item.has("rail"):
			paint("bridge-rail",p,1,-1,item.rail.flip)
		elif item.has("tree"):
			paint(item.tree.type,p+Vector2(sin(sim.time*0.6+item.tree.x)*0.65,0),item.tree.scale*0.84)
		elif item.has("building"):
			var b=item.building; var factor: float=1.03 if b.type=="palace" else 0.89
			if selected==int(b.id) or hovered==int(b.id): ring(p,b.size*24,Color("f0d591"))
			paint(b.type,p,factor,-1,1,Color(1,1,1,0.4+0.6*b.progress))
			atmosphere.building(self,b,p,factor)
			leisure.occupied(self,b,p,factor,sim.Shelter.occupants(sim,b.id))
			if b.get("tier",1)>1:
				ring(p,b.size*20,Color("a99758"),2); draw_string(font,p+Vector2(-6,-100),"II",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("f1d598"))
			if b.get("upgrade_remaining",0)>0: health(p+Vector2(-19,-100),1-b.upgrade_remaining/sim.definition_of(b).upgrade_time,false)
			if b.progress<1: health(p+Vector2(-19,-85),b.progress,false)
			elif sim.time-b.last_hit<3 or selected==int(b.id): health(p+Vector2(-19,-90),b.hp/b.max_hp,b.hostile)
			var a: Dictionary=manifest[b.type]
			for effect in a.get("effects",[]):
				var at: Vector2=p+(Vector2(effect.at[0],effect.at[1])-Vector2(a.anchor[0],a.anchor[1]))*factor
				if effect.type=="fire": draw_circle(at,4+sin(sim.time*10+b.id),Color(0.92,0.61,0.26,0.4))
		elif item.has("loot"):
			var pile=item.loot
			if selected==int(pile.id): ring(p,20,Color("e0c985"))
			if not pile.get("items",[]).is_empty(): ring(p,22+sin(sim.time*3)*2,Color("d8b56d"),2)
			var texture: Texture2D=effect_textures[pile.type]
			draw_texture_rect(texture,Rect2(p+Vector2(-26,-34),Vector2(52,48)),false)
		else:
			var u=item.unit; aura(u,p)
			if selected==u.id or hovered==u.id: ring(p,15,Color("f0d591"))
			var boss: bool=u.id==sim.mission.boss_id
			var art_key: String="unit_warlord" if boss else "unit_"+u.type
			var frame: int=CharacterAnimation.frame(u,sim,manifest[art_key])
			if u.type=="wizard":
				var visual:=wizard_visual(u); art_key=visual.key; frame=visual.frame
			var hit_age: float=presentation_time-u.last_hit
			var recoil:=Vector2.ZERO
			var tint:=Color(1.22,1.14,0.98) if hit_age<0.12 else Color.WHITE
			if hit_reactions.has(u.id) and hit_age>=0 and hit_age<0.24:
				var impact: Dictionary=hit_reactions[u.id]
				if impact.has("origin"): recoil=(p-iso(Vector2(impact.origin[0],impact.origin[1]))).normalized()*sin(hit_age/0.24*PI)*2.7
				if impact.get("element","")=="frost": tint=Color(0.8,1.12,1.2)
			paint(art_key,p+recoil,1.15 if boss else 1,frame,1,tint)
			if boss:
				ring(p,27,Color("cd7447"),2)
				var boss_offset: float=manifest.unit_warlord.healthOffset*1.15
				draw_string(font,p+Vector2(-57,boss_offset-10),"EMBER WARLORD",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("f1c083"))
				health(p+Vector2(-19,boss_offset),u.hp/u.max_hp,true)
			if not u.equipment.is_empty(): draw_circle(p+Vector2(12,-30),2.5,Color("e5bc67"))
			var offset: float=manifest["unit_"+u.type].healthOffset
			if not boss and (sim.time-u.last_hit<3 or u.id==selected): health(p+Vector2(-19,offset),u.hp/u.max_hp,u.hostile)
			if u.hero and u.level>1: draw_string(font,p+Vector2(-9,offset-4),"★ %d"%u.level,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color("e0ca86"))
			if u.type=="collector" and u.carried>0: draw_circle(p+Vector2(7,-17),2,Color("e2bf66"))
	for f in sim.flags.values():
		if f.dead: continue
		var p:=iso(sim.pos(f))
		if not visible_rect.grow(100).has_point(p): continue
		if selected==int(f.id): ring(p,22,Color("f0d591"))
		atmosphere.bounty(self,f,p)
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
	var labels: int=0
	for e in sim.effects:
		var at:=Vector2(e.x,e.y)
		if e.type!="spell_farsight" and not sim.is_visible(at): continue
		var p:=iso(at); var age: float=sim.time-e.started; var t: float=age/e.life
		if t<0 or t>=1 or not visible_rect.grow(500).has_point(p): continue
		if e.type=="hit":
			if labels>=24 or e.has("target") and hit_reactions.get(int(e.target),{})!=e: continue
			labels+=1
		if e.type.begins_with("spell_") or e.type in ["meteor_impact","fire","swing"]: continue
		elif e.type in ["heal","level"]:
			ring(p,12+t*40,Color(0.82,0.83,0.57,1-t))
			for i in 8: draw_circle(p+Vector2(cos(i*0.785)*(8+t*15),-t*40+sin(i*0.785)*5),1.6,Color(0.9,0.85,0.63,1-t))
		elif e.type in ["death","upgrade","relic","slam"]: pass
		elif e.type=="gold": draw_string(font,p+Vector2(-10,-25-t*25),"+%d"%e.value,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.96,0.87,0.62,1-t))
		else:
			for i in (24 if e.type=="collapse" else 7):
				if e.type=="hit": break
				var spread: float=(42 if e.type=="collapse" else 16)*fmod(i*0.371+0.1,1)
				draw_circle(p+Vector2(cos(i*1.91)*spread*t,-12+sin(i*1.91)*spread*t-t*15),1+fmod(i*0.61,2),Color(0.82,0.73,0.54,1-t))
			if e.type=="hit":
				var label: String=str(ceili(e.value))
				var offset:=Vector2(-5+sin(e.get("serial",0)*2.4)*9,-33-t*27)
				draw_string_outline(font,p+offset,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,3,Color(0.10,0.12,0.11,1-t))
				draw_string(font,p+offset,label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(0.98,0.9,0.7,1-t))
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
		var color: Color=Arcane.color_for(mode_key) if valid else Color("b27464")
		var at:=iso(point); var radius: float=d.radius*sqrt(2)*32
		ring(at,radius,color,1.6); ring(at,radius-4,Color(color,0.25),1)
		for i in 8:
			var a: float=i*PI/4
			draw_line(at+Arcane.ellipse(a,radius+4),at+Arcane.ellipse(a,radius+10),color,1.8,true)
		for target in Magic.targets(sim,mode_key,point).slice(0,32):
			var p:=iso(sim.pos(target))
			if sim.is_visible(sim.pos(target)): ring(p,13,Color(color,0.65),1.5)
	elif mode_kind=="bounty": ring(iso(cursor),20,Color("ecce8b"))
