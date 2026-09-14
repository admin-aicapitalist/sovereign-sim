extends RefCounted
static func status(s) -> Dictionary:
	var cottages: int=s.buildings.filter(func(b):return not b.dead and b.type=="house" and b.progress==1).size()
	var target: int=ceili(maxf(0,cottages-s.definitions.sanitation.safeCottages)/s.definitions.sanitation.cottagesPerSewer)
	var active: int=s.buildings.filter(func(b):return not b.dead and b.infestation).size()
	return {"cottages":cottages,"target":target,"active":active,"next_in":ceili(s.definitions.sanitation.incubation-s.sanitation.timer) if target>active else -1}
static func rat(s,origin: Vector2,home: int=0) -> void:
	var u=s.add_unit("rat",s.near_point(origin,3),home); u.infestation=true; u.raider=true
static func spawn(s) -> bool:
	var houses: Array=s.buildings.filter(func(b):return not b.dead and b.type=="house" and b.progress==1)
	var sites: Array=[]
	for t in s.fixture.tiles:
		var point:=Vector2(t.x+1,t.y+1)
		if not houses.any(func(h):return s.pos(h).distance_to(point)>=3 and s.pos(h).distance_to(point)<10): continue
		if s.buildings.any(func(b):return not b.dead and absf(b.x-point.x)<(b.size+2)/2.0+1 and absf(b.y-point.y)<(b.size+2)/2.0+1): continue
		if s.buildings.any(func(b):return not b.dead and b.infestation and s.pos(b).distance_to(point)<8): continue
		if s.units.any(func(u):return not u.dead and absf(u.pos.x-point.x)<1.5 and absf(u.pos.y-point.y)<1.5): continue
		if s.loot.any(func(p):return not p.dead and absf(p.x-point.x)<2 and absf(p.y-point.y)<2): continue
		var ring: Array=[]; var dry: bool=true
		for dy in range(-1,3):
			for dx in range(-1,3):
				var p:=Vector2(t.x+dx,t.y+dy); var tile=s.tile_at(p)
				if tile.is_empty() or tile.kind in ["water","bridge"]: dry=false; continue
				if dx>=0 and dx<2 and dy>=0 and dy<2:
					if tile.kind!="grass": dry=false
				elif s.walkable(p): ring.append(p+Vector2.ONE*0.5)
		if dry and not ring.is_empty():
			var score: float=0
			for h in houses: score+=maxf(0,10-s.pos(h).distance_to(point))
			sites.append({"x":t.x,"y":t.y,"ring":ring,"score":score+s.sanitation_rng.next()*4})
	sites.sort_custom(func(a,b):return a.score>b.score)
	var origin: Vector2=s.near_point(s.pos(s.palace()),4)
	var site=null
	for p in sites:
		if p.ring.any(func(q):return origin.distance_to(q)<1 or not s.find_path(origin,q).is_empty()): site=p; break
	if site==null:
		var state=status(s)
		if state.target<=0 or s.units.filter(func(u):return not u.dead and u.infestation).size()>=state.target*6: return false
		var house=houses[s.sanitation_rng.integer(0,houses.size()-1)]
		rat(s,s.pos(house)); rat(s,s.pos(house)); s.notify("Overcrowded drains spill rats into the neighborhood!","danger"); return true
	for y in range(site.y-1,site.y+3):
		for x in range(site.x-1,site.x+3):
			s.fixture.tiles[y*s.size+x].blocked=false; s.grid.set_point_solid(Vector2i(x,y),false)
	s.fixture.trees=s.fixture.trees.filter(func(t):return not Rect2(Vector2(site.x-1,site.y-1),Vector2(4,4)).has_point(Vector2(t.x,t.y)))
	var b=s.add_building("sewer",Vector2i(site.x,site.y)); b.infestation=true; b.site_name="Overcrowded Sewer"; b.hp=650; b.max_hp=650; b.spawn=s.definitions.sanitation.ratInterval
	rat(s,s.pos(b),b.id); rat(s,s.pos(b),b.id); s.reveal(s.pos(b),3); s.notify("Too many cottages! A rat sewer has opened near your homes.","danger"); return true
static func update(s,dt: float) -> void:
	var state=status(s)
	if state.target>s.sanitation.last_target: s.notify("Overcrowding: %d cottages can sustain %d rat sewers."%[state.cottages,state.target],"danger")
	s.sanitation.last_target=state.target
	if state.target<=state.active: s.sanitation.timer=0; return
	s.sanitation.timer+=dt
	if s.sanitation.timer>=s.definitions.sanitation.incubation: s.sanitation.timer=0; spawn(s)
