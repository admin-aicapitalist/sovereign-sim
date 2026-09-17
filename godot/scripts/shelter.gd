extends RefCounted
## Indoor occupancy is simulation state. Buildings protect their occupants until lost.
const TYPES=["palace","warriors","rangers","wizards","thieves","temple","inn","brothel"]
static func usable(b) -> bool:
	return b!=null and b is Dictionary and b.get("kind")=="building" and b.type in TYPES and not b.dead and not b.hostile and b.progress>=1
static func occupants(s,id: int) -> Array:
	return s.units.filter(func(u):return u.hero and not u.dead and u.inside==id)
static func door(s,b) -> Vector2:
	var p:=Vector2(b.x,b.ty+b.size+0.5)
	return p if s.walkable(p) else s.near_open(p)
static func enter(s,u,b,state: String) -> bool:
	if not u.hero or u.dead or not usable(b): return false
	if u.inside==b.id: u.state=state; return true
	if u.pos.distance_to(door(s,b))>1.0: return false
	leave(s,u); u.inside=b.id; u.pos=s.pos(b); u.target=0; u.goal=0; u.pending_attack={}; s.stop(u); u.state=state
	return true
static func seek(s,u,b,travel: String,state: String) -> bool:
	if not usable(b): return false
	if enter(s,u,b,state): return true
	s.go(u,door(s,b),travel); return false
static func leave(s,u) -> void:
	if u.inside==0: return
	var b=s.building(u.inside)
	if not u.journey.is_empty() and u.journey.get("leisure_place",0)==u.inside:
		u.journey.leisure_until=0; u.journey.leisure_place=0
	u.inside=0; u.pos=door(s,b) if not b.is_empty() else s.near_open(u.pos); s.stop(u); u.repath=0
static func evict(s,b) -> void:
	for u in occupants(s,b.id):
		leave(s,u); u.state="Escaping a destroyed shelter"; u.think=0
static func valid(value: Variant,item: Dictionary,data: Dictionary) -> bool:
	if typeof(value) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(value)) or value<0 or value!=floorf(value): return false
	if value==0: return true
	if not item.hero or item.dead or value>=data.next_id or not item.path.is_empty() or item.target!=0 or not item.pending_attack.is_empty(): return false
	if not item.pos is Array or item.pos.size()!=2: return false
	for n in item.pos:
		if typeof(n) not in [TYPE_INT,TYPE_FLOAT] or not is_finite(float(n)): return false
	for b in data.buildings:
		if b.id==value: return usable(b) and Vector2(item.pos[0],item.pos[1]).distance_to(Vector2(b.x,b.y))<0.01
	return false
