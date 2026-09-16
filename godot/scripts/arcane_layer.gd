extends Node2D
## Three batched CanvasItem passes: grounded inscriptions, matter, and additive light.
## Every motion is sampled from the presentation clock; no autonomous particle timers
## or random-number calls can drift when pausing, changing speed, or restoring a save.
const COLORS={"heal":"a9e6ae","ward":"9abbef","haste":"edc47b","lightning":"b8ceff","frost":"8de5ee","meteor":"f8a45e","farsight":"c6adef"}
var world
var pass_index: int=0
var glow_texture: GradientTexture2D
var now: float=0
var crowded: bool=false

func _ready() -> void:
	if pass_index==2:
		var blend:=CanvasItemMaterial.new(); blend.blend_mode=CanvasItemMaterial.BLEND_MODE_ADD; material=blend
	var gradient:=Gradient.new()
	gradient.offsets=PackedFloat32Array([0,0.12,0.35,0.65,1])
	gradient.colors=PackedColorArray([Color(1,1,1,0.9),Color(1,1,1,0.6),Color(1,1,1,0.19),Color(1,1,1,0.035),Color(1,1,1,0)])
	glow_texture=GradientTexture2D.new(); glow_texture.gradient=gradient; glow_texture.width=128; glow_texture.height=128
	glow_texture.fill=GradientTexture2D.FILL_RADIAL; glow_texture.fill_from=Vector2(0.5,0.5); glow_texture.fill_to=Vector2(1,0.5)

static func color_for(key: String) -> Color: return Color(COLORS.get(key,"e8bd80"))
static func iso(p: Vector2) -> Vector2: return Vector2((p.x-p.y)*32,(p.x+p.y)*16)
static func ellipse(angle: float,radius: float,height: float=0.5) -> Vector2: return Vector2(cos(angle),sin(angle)*height)*radius
static func noise(n: float) -> float: return fposmod(sin(n*127.1+311.7)*43758.5453,1)
func alpha(c: Color,a: float) -> Color: return Color(c,clampf(a,0,1))
func glow(p: Vector2,r: float,c: Color,a: float=1,flat: float=1) -> void:
	if pass_index==2 and a>0.005:
		draw_texture_rect(glow_texture,Rect2(p-Vector2(r,r*flat),Vector2(r*2,r*flat*2)),false,alpha(c,a))
func stroke(points: PackedVector2Array,c: Color,width: float=1.3,a: float=1) -> void:
	if points.size()<2 or a<0.005: return
	if pass_index==2:
		if not crowded: draw_polyline(points,alpha(c,a*0.12),width+5,true)
		draw_polyline(points,alpha(c,a*(0.3 if crowded else 0.42)),width+1.5,not crowded)
	else: draw_polyline(points,alpha(c,a),width,true)
func arc(p: Vector2,r: float,c: Color,a: float=1,start: float=0,length: float=TAU,height: float=0.5,width: float=1.2) -> void:
	var points:=PackedVector2Array()
	var segments: int=24 if crowded else 48
	for i in segments+1: points.append(p+ellipse(start+length*i/segments,r,height))
	stroke(points,c,width,a)
func mote(p: Vector2,size: float,c: Color,a: float=1) -> void:
	if pass_index==2:
		if not crowded: glow(p,size*5,c,a*0.55)
		return
	draw_colored_polygon(PackedVector2Array([p+Vector2(0,-size*1.7),p+Vector2(size*0.65,0),p+Vector2(0,size*1.7),p-Vector2(size*0.65,0)]),alpha(c,a))
func seal(p: Vector2,r: float,c: Color,a: float,rotation: float=0,ornate: bool=true) -> void:
	arc(p,r,c,a,rotation)
	if crowded: return
	arc(p,r*0.92,c,a*0.42,-rotation)
	for i in 12:
		var angle: float=i*TAU/12+rotation
		stroke(PackedVector2Array([p+ellipse(angle,r*0.99),p+ellipse(angle,r*1.045)]),c,1,a*0.8)
		if not ornate or crowded: continue
		var center: Vector2=p+ellipse(angle,r*0.83)
		var size: float=clampf(r*0.038,2.5,6)
		var rune:=PackedVector2Array()
		for v in [Vector2(-1,-1),Vector2(-1,1),Vector2(0,0.2),Vector2(1,1),Vector2(1,-1)]:
			var point: Vector2=v.rotated(angle+PI/2)*size; rune.append(center+Vector2(point.x,point.y*0.5))
		stroke(rune,c,0.8,a*0.65)
	for i in 4:
		var angle: float=i*PI/2+rotation
		var center: Vector2=p+ellipse(angle,r*1.07)
		mote(center,2.4,c,a)
func crystal(p: Vector2,angle: float,length: float,width: float,c: Color,a: float) -> void:
	var tip:=p+Vector2(sin(angle)*length*0.38,-length)
	var side:=Vector2(width,0).rotated(angle*0.22)
	if pass_index==1:
		draw_colored_polygon(PackedVector2Array([p-side,p+Vector2(0,5),tip]),alpha(c.darkened(0.48),a*0.8))
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,5),p+side,tip]),alpha(c,a*0.85))
	stroke(PackedVector2Array([p-side,tip,p+side]),c.lightened(0.5),0.9,a)
func sprite(key: String,p: Vector2,factor: float=1,opacity: float=1,tint: Color=Color.WHITE,rotation: float=0) -> void:
	var art: Dictionary=world.arcane_art[key]
	draw_set_transform(p,rotation,Vector2.ONE*factor)
	draw_texture_rect(world.arcane_textures[key],Rect2(-Vector2(art.anchor[0],art.anchor[1]),Vector2(art.size[0],art.size[1])),false,alpha(tint,opacity))
	draw_set_transform(Vector2.ZERO)
func ice_field(p: Vector2,age: float,fade: float) -> void:
	for i in 19:
		var angle: float=i*2.399
		var grow: float=clampf(age*5-noise(i)*0.7,0,1)
		var offset: Vector2=ellipse(angle,26+noise(i+7)*87)
		var at:=p+offset
		if pass_index==(0 if offset.y<0 else 1): sprite("ice-"+str(i%4),at,(0.45+noise(i)*0.55)*grow,fade)
		if pass_index==2 and i%3==0: glow(at+Vector2(0,-10),19,color_for("frost"),fade*0.14)
func target_positions(e: Dictionary,follow: bool=true) -> Array[Vector2]:
	var points: Array[Vector2]=[]
	for target in e.get("targets",[]).slice(0,8 if crowded else 16):
		var unit=world.sim.entity(target.id)
		var point: Vector2=world.sim.pos(unit) if follow and unit!=null and not unit.dead else Vector2(target.x,target.y)
		if world.sim.is_visible(point): points.append(iso(point))
	if points.is_empty(): points.append(iso(world.sim.pos(e)))
	return points

func _draw() -> void:
	if world==null or world.sim==null: return
	now=world.presentation_time
	crowded=world.arcane_effects.size()>32
	for effect in world.arcane_effects: draw_effect(effect)
	for u in world.arcane_units:
		if pass_index!=0: draw_buffs(u); draw_cast(u)
		elif u.magic_buffs.ward>0: seal(iso(u.pos),19,color_for("ward"),minf(0.32,u.magic_buffs.ward*0.2),now*0.12,false)
		elif u.magic_buffs.frost>0: seal(iso(u.pos),18,color_for("frost"),minf(0.4,u.magic_buffs.frost*0.3),0,false)
	if pass_index!=0:
		for projectile in world.arcane_projectiles: draw_projectile(projectile)
	if pass_index==0 and world.sim.mission.slam_remaining>0:
		var at:=Vector2(world.sim.mission.slam_x,world.sim.mission.slam_y)
		if world.sim.is_visible(at): seal(iso(at),world.sim.definitions.mission.slam_radius*45,Color("edac72"),0.8,-now*0.1)

func draw_effect(e: Dictionary) -> void:
	var age: float=maxf(0,now-e.started)
	var t: float=clampf(age/e.life,0,1)
	if t>=1: return
	var p:=iso(Vector2(e.x,e.y))
	var key: String=e.type.trim_prefix("spell_")
	var c:=color_for(key)
	var fade: float=pow(1-t,1.4)
	var radius: float=minf(e.get("radius",3)*45.25,200)
	if pass_index==0:
		if key=="frost": ice_field(p,age,fade)
		if e.type.begins_with("spell_"):
			seal(p,radius*(0.92+0.08*minf(age*5,1)),c,fade*0.62,age*0.08*(1 if key in ["heal","haste"] else -1))
			if key in ["frost","lightning"]: arc(p,radius*minf(1,age*4),c,fade*0.8,0,TAU,0.5,2)
			if key=="meteor":
				arc(p,radius*(1-t),c,0.95,0,TAU,0.5,2)
				for i in 3: stroke(PackedVector2Array([p+ellipse(i*TAU/3+PI/6,radius*0.74),p+ellipse((i+1)*TAU/3+PI/6,radius*0.74)]),c,1.2,0.5+t*0.4)
		elif e.type in ["meteor_impact","fire","slam"]:
			var r: float=radius if e.type=="meteor_impact" else e.value*45 if e.type=="slam" else 34
			# Lingering soot has actual opacity; additive black cannot make a scorch.
			var spread: float=r*minf(age*8,1)
			draw_texture_rect(world.arcane_textures["smoke-0"],Rect2(p-Vector2(spread,spread*0.5),Vector2(spread*2,spread)),false,Color(0.20,0.13,0.08,fade*0.9))
			draw_texture_rect(world.arcane_textures["smoke-2"],Rect2(p-Vector2(spread*0.63,spread*0.35),Vector2(spread*1.4,spread*0.7)),false,Color(0.17,0.12,0.08,fade*0.75))
			arc(p,r*sqrt(minf(age*1.7,1.4)),Color("ce9769"),pow(maxf(0,1-age/0.8),2),0,TAU,0.5,4)
			if e.type=="meteor_impact":
				for i in 11:
					var crack:=PackedVector2Array([p+ellipse(i*TAU/11,17)])
					for j in range(1,5): crack.append(p+ellipse(i*TAU/11+(noise(i*7+j)-0.5)*0.26,(j*21+noise(i)*16)*minf(1,age*9)))
					stroke(crack,Color("55402d"),2.2,fade*0.6)
					stroke(crack,Color("efa965"),0.8,maxf(0,1-age/1.1)*0.7)
		return
	match key:
		"heal":
			for at in target_positions(e):
				glow(at+Vector2(0,-25),42,c,fade*0.32)
				for strand in (2 if crowded else 3):
					var ribbon:=PackedVector2Array()
					for j in 25:
						var phase: float=j/24.0
						var a: float=phase*TAU*0.8+age*4+strand*TAU/3
						ribbon.append(at+ellipse(a,16*(1-phase*0.3),0.32)+Vector2(0,-phase*62*minf(1,age*4)))
					stroke(ribbon,c,1.1,fade*0.75)
				for i in 10:
					var progress: float=fposmod(age*0.6+i*0.137,1)
					mote(at+ellipse(i*2.4+age,10+progress*11)+Vector2(0,-progress*65),1.3+sin(progress*PI),Color("e6edbd"),fade*sin(progress*PI))
		"ward":
			for at in target_positions(e):
				glow(at+Vector2(0,-27),49,c,fade*0.4)
				for i in 6:
					var a: float=i*TAU/6+age*1.6
					mote(at+ellipse(a,23+14*(1-minf(age*2,1)),0.8)+Vector2(0,-28),2.7,c,fade)
		"haste":
			for at in target_positions(e):
				for i in 3:
					arc(at+Vector2(0,-10-i*12-age*5),20+i*7,c,fade,age*7+i*2,PI*1.25,0.35,1.4)
				glow(at,42,c,fade*0.3,0.5)
		"lightning":
			var targets:=target_positions(e,false)
			var first: Vector2=targets[0]+Vector2(0,-25)
			var pulse: float=exp(-age*7)+0.5*exp(-absf(age-0.17)*35)+0.24*exp(-absf(age-0.34)*40)
			if age<0.65:
				bolt(first+Vector2(-26,-245),first,c,pulse,31+floorf(age*24))
				bolt(first+Vector2(74,-189),first+Vector2(-8,-87),c,pulse*0.5,83+floorf(age*24))
				for i in range(1,targets.size()): bolt(targets[i-1]+Vector2(0,-25),targets[i]+Vector2(0,-25),c,pulse*0.8,i*17+floorf(age*24))
			for at in targets:
				glow(at+Vector2(0,-23),56,c,pulse*0.6)
				for i in 7:
					var a: float=i*2.399
					mote(at+ellipse(a,8+age*47,0.9)+Vector2(0,-25+age*12),1.3,Color("e8eaff"),fade*0.7)
		"frost":
			ice_field(p,age,fade)
			for at in target_positions(e): glow(at+Vector2(0,-12),37,c,fade*0.3)
			for i in 25:
				var at:=p+ellipse(i*2.399,(15+noise(i)*radius)*minf(age*3,1))+Vector2(0,-age*(10+noise(i+8)*25))
				mote(at,1.3,c.lightened(0.5),fade*0.8)
		"meteor":
			var at:=p+Vector2(145,-330)*pow(1-t,1.1)
			var direction:=Vector2(145,-330).normalized()
			for i in range(5,-1,-1):
				var tail:=at+direction*i*19+Vector2(sin(age*24+i)*i,0)
				if pass_index==1: sprite("smoke-"+str(i%4),tail,0.45+i*0.08,0.32-i*0.035,Color("ca9d7c"))
			if pass_index==1: sprite("meteor-"+str(int(age*18)%8),at,0.94)
			glow(at,39,c,0.55)
			glow(p,radius,c,0.25+t*0.25,0.5)
		"farsight":
			var eye:=p+Vector2(0,-49-minf(age*16,14))
			var opening: float=sin(minf(age*3,PI/2))
			for side in [-1,1]:
				var points:=PackedVector2Array()
				for i in 41:
					var x: float=i/40.0
					points.append(eye+Vector2((x-0.5)*112,sin(x*PI)*side*29*opening))
				stroke(points,c,1.5,fade)
			arc(eye,17,c,fade,age*0.3,TAU,opening)
			arc(eye,9,Color("e6ddff"),fade,-age*0.6,TAU,opening)
			glow(eye,47,c,fade*0.48); mote(eye,5,Color("e9e5ff"),fade)
			for i in (5 if crowded else 9):
				var a: Vector2=p+ellipse(i*TAU/9+0.1,90+noise(i)*40)+Vector2(0,-55)
				var b: Vector2=p+ellipse((i+1)*TAU/9+0.1,90+noise(i+1)*40)+Vector2(0,-55)
				if not crowded: stroke(PackedVector2Array([a,b]),c,0.8,fade*0.35)
				mote(a,2,c,fade)
		"meteor_impact","fire","slam": draw_blast(e,p,age,t)
		"hit": draw_hit(e,p,age,t)
		"swing": draw_swing(e,p,age,t)
		"death":
			for i in 12:
				var at:=p+ellipse(i*2.4,(8+noise(i)*22)*sqrt(t))+Vector2(0,-sin(t*PI)*(4+noise(i+8)*10))
				if pass_index==1: draw_circle(at,2+t*4,Color(0.45,0.40,0.30,(1-t)*0.16))
				elif i%3==0: glow(at,5,Color("c8ac82"),(1-t)*0.12)

func bolt(a: Vector2,b: Vector2,c: Color,opacity: float,seed_value: float) -> void:
	var points:=PackedVector2Array([a]); var side: Vector2=(b-a).orthogonal().normalized()
	var steps: int=clampi(int(a.distance_to(b)/14),4,24)
	for i in range(1,steps): points.append(a.lerp(b,float(i)/steps)+side*(noise(seed_value+i)*2-1)*minf(18,a.distance_to(b)*0.15))
	points.append(b)
	stroke(points,c,1.9,opacity)
	if pass_index==1: draw_polyline(points,alpha(Color("f5f6ff"),opacity),0.9,true)

func draw_blast(e: Dictionary,p: Vector2,age: float,t: float) -> void:
	var major: bool=e.type in ["meteor_impact","slam"]
	var radius: float=e.value*45 if e.type=="slam" else 155 if major else 36
	var c:=Color("efad67")
	var flash: float=exp(-age*9)
	glow(p+Vector2(0,-10),radius,c,flash*0.85,0.7)
	arc(p,radius*sqrt(minf(age*1.9,1.4)),c,maxf(0,1-age/0.85)*0.8,0,TAU,0.5,2)
	for i in (30 if major else 12):
		var seed_value: float=i+e.get("serial",0)*0.1
		var a: float=i*2.399
		var velocity: Vector2=ellipse(a,(50+noise(seed_value)*110) if major else 25+noise(seed_value)*40)
		var fly: float=minf(age,0.8)
		var at:=p+velocity*fly+Vector2(0,-(45+noise(i+7)*65)*fly+78*fly*fly)
		if age<0.9:
			stroke(PackedVector2Array([at-velocity*0.045,at]),c,1.3,(1-t)*0.8)
			mote(at,1.5+noise(i)*1.5,Color("ffe2ac"),(1-t)*0.9)
			if pass_index==1 and major and i%4==0: sprite("meteor-"+str(i%8),at,0.1+noise(i)*0.06,1-t,Color("c9a982"),age*i)
		if pass_index==1 and i%3==0:
			var smoke:=p+velocity*age*0.24+Vector2(0,-age*18-8)
			sprite("smoke-"+str(i%4),smoke,(0.45+age*0.65)*(1 if major else 0.5),sin(t*PI)*0.48,Color("b7a18a"),i*0.71)

func draw_hit(e: Dictionary,p: Vector2,age: float,t: float) -> void:
	var element: String=e.get("element","physical")
	var c: Color=color_for("ward") if e.get("warded",false) else color_for(element) if element not in ["physical","arrow"] else Color("efd3a0") if e.get("armored",false) else Color("c1a280")
	var direction:=Vector2.RIGHT
	if e.has("origin"): direction=(p-iso(Vector2(e.origin[0],e.origin[1]))).normalized()
	var at:=p+Vector2(0,-25)
	if age<0.2 and not crowded: glow(at,27,c,(1-age/0.2)*0.5)
	if e.get("warded",false): arc(at,24+age*13,c,pow(1-t,3),direction.angle()-PI*0.4,PI*0.8,1,2)
	for i in (3 if crowded else 9 if e.get("armored",false) else 6):
		var v: Vector2=direction.rotated((noise(i+e.get("serial",0))-0.5)*2.7)*(35+noise(i+17)*75)
		var end:=at+v*age+Vector2(0,age*age*65)
		if age<0.45: stroke(PackedVector2Array([end-v*0.025,end]),c,1.1,pow(1-t,2))

func draw_swing(e: Dictionary,p: Vector2,age: float,t: float) -> void:
	if not e.has("origin"): return
	var direction: Vector2=(iso(Vector2(e.origin[0],e.origin[1]))-p).normalized()
	var heavy: bool=e.get("weapon","") in ["troll","warlord"]
	var c:=Color("d3b899") if heavy else Color("dfdfc9")
	var points:=PackedVector2Array()
	var radius: float=40 if heavy else 25
	var angle: float=direction.angle()-1.1+t*2
	for i in 17:
		var a: float=angle-float(i)*0.055
		points.append(p+Vector2(0,-24)+Vector2.from_angle(a)*radius*Vector2(1,0.7))
	stroke(points,c,2.6 if heavy else 1.4,pow(1-t,2)*0.7)

func draw_buffs(u) -> void:
	var p:=iso(u.pos)
	var height: float=clampf(-world.manifest["unit_"+u.type].healthOffset,36,79)
	if u.magic_buffs.ward>0:
		var hit: float=maxf(0,1-(now-u.last_hit)/0.35)
		var opacity: float=minf(1,u.magic_buffs.ward)*(0.13+hit*0.6)
		var c:=color_for("ward")
		var points:=PackedVector2Array()
		for i in 9: points.append(p+Vector2(sin(i*TAU/8)*23,-height*0.45-cos(i*TAU/8)*height*0.56))
		stroke(points,c,0.9+hit,opacity)
		if pass_index==1 and hit>0: draw_colored_polygon(points,alpha(c,hit*0.08))
		if hit>0: glow(p+Vector2(0,-height*0.5),42,c,hit*0.3)
		mote(p+Vector2(0,-height-3),2.6,c,minf(1,u.magic_buffs.ward)*0.6)
	if u.magic_buffs.haste>0:
		var direction: Vector2=iso(u.heading).normalized()
		var moving: bool=u.path_index<u.path.size()
		var c:=color_for("haste")
		for i in 3:
			var points:=PackedVector2Array()
			for j in 14:
				var f: float=j/13.0
				points.append(p-direction*(4+f*(32 if moving else 16))+Vector2(0,-7-i*8+sin(f*4+now*7+i)*2))
			stroke(points,c,0.8,minf(1,u.magic_buffs.haste)*(0.3 if moving else 0.14))
	if u.magic_buffs.frost>0:
		for i in 5: crystal(p+ellipse(i*TAU/5+u.id,14),i*2.4,7+sin(i*3)*3,2.5,color_for("frost"),minf(0.6,u.magic_buffs.frost))

func draw_cast(u) -> void:
	if u.type!="wizard": return
	var p:=iso(u.pos)
	var visual: Dictionary=world.wizard_visual(u)
	var sockets: Dictionary=visual.sockets
	var staff:=p+Vector2(sockets.staff[0],sockets.staff[1])
	var hand:=p+Vector2(sockets.hand[0],sockets.hand[1])
	var spell_age: float=now-u.last_spell.get("at",-100)
	var active: bool=spell_age>=0 and spell_age<0.9 or not u.pending_attack.is_empty() or u.attacking>0
	var key: String=u.last_spell.get("key","lightning") if spell_age<0.9 else "meteor" if active else "lightning"
	var c:=color_for(key)
	var strength: float=(maxf(0.12,1-spell_age/0.9) if spell_age<0.9 else 0.8) if active else 0.11
	glow(staff,13+strength*13,c,0.16+strength*0.45)
	mote(staff,1.5+strength,c.lightened(0.55),0.6+strength*0.4)
	if not active: return
	glow(hand,20,c,strength*0.5)
	arc(p,23,c,strength*0.6,now*1.6,TAU*0.8)
	var points:=PackedVector2Array()
	for i in 25:
		var f: float=i/24.0
		points.append(staff.lerp(hand,f)+Vector2(sin(f*TAU+now*9)*3,sin(f*PI)*-7))
	stroke(points,c,0.9,strength*0.7)
	for i in 5:
		var f: float=fposmod(now*1.4+i*0.2,1)
		mote(staff.lerp(hand,f)+Vector2(sin(f*TAU+now*9)*3,-sin(f*PI)*7),1.3,c,strength)
	arc(hand,8+strength*4,c,strength,now*3,TAU*0.8,1)

func draw_projectile(projectile: Dictionary) -> void:
	var target=world.sim.entity(projectile.target)
	if target==null or target.dead: return
	var point:=Vector2(projectile.x,projectile.y)
	var dest: Vector2=world.sim.pos(target)
	# Interpolate only within the unconsumed fixed tick; damage still resolves in simulation.
	point=point.move_toward(dest,projectile.speed*maxf(0,now-world.sim.time))
	var p:=iso(point)+Vector2(0,-25)
	var direction: Vector2=(iso(dest-point)).normalized()
	var distance: float=iso(point-Vector2(projectile.origin[0],projectile.origin[1])).length() if projectile.has("origin") else 50
	if projectile.type=="arrow":
		if pass_index!=1: return
		draw_line(p-direction*17,p,Color("e0c897"),1.3,true)
		for side in [-1,1]: draw_line(p-direction*13,p-direction*18+direction.orthogonal()*3*side,Color("d6d2b5"),1.2,true)
		draw_colored_polygon(PackedVector2Array([p+direction*3,p-direction*3+direction.orthogonal()*2,p-direction*3-direction.orthogonal()*2]),Color("eff0de"))
		return
	var c:=Color("f5a261")
	var length: float=minf(57,distance)
	for i in range(10,-1,-1):
		var f: float=i/10.0
		var at:=p-direction*f*length+direction.orthogonal()*sin(now*29-i)*f*2.2
		glow(at,10+f*7,c,(1-f)*0.5)
		if pass_index==1: draw_circle(at,4*(1-f)+0.7,alpha(Color("e8864c").lerp(Color("fff0b6"),1-f),0.9-f*0.7))
	for i in 3:
		var f: float=fposmod(now*3+i*0.33,1)
		mote(p-direction*f*length+direction.orthogonal()*sin(i*5+now*8)*5*f,1.1,c,(1-f)*0.7)
