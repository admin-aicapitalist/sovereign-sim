extends RefCounted
const SeedRng = preload("res://scripts/seed_rng.gd")
const N: int = 88
var random: SeedRng
var candidates: Array = []
var occupied: Array = []
var home := Vector2.ZERO
var water := PackedByteArray()
var road := PackedByteArray()
var noise := PackedFloat64Array()

class Heap:
	var items: Array = []
	func push(n: Dictionary) -> void:
		items.append(n)
		var i: int = items.size()-1
		while i > 0:
			var p: int = (i-1) >> 1
			if items[p].f <= n.f: break
			items[i] = items[p]
			i = p
		items[i] = n
	func pop() -> Dictionary:
		var root: Dictionary = items[0]
		var last: Dictionary = items.pop_back()
		if not items.is_empty():
			var i: int = 0
			while true:
				var c: int = i*2+1
				if c >= items.size(): break
				if c+1 < items.size() and items[c+1].f < items[c].f: c += 1
				if items[c].f >= last.f: break
				items[i] = items[c]
				i = c
			items[i] = last
		return root

func position(p: Dictionary) -> Vector2:
	return Vector2(p.x,p.y)
func site(minimum: float, maximum: float, separation: float, target: float) -> Dictionary:
	var best: Dictionary = {}
	var best_score: float = INF
	for p in candidates:
		var distance: float = position(p).distance_to(home)
		if distance < minimum or distance > maximum: continue
		var nearest: float = INF
		for q in occupied:
			nearest = minf(nearest,position(p).distance_to(position(q)))
		if nearest <= separation: continue
		var score: float = absf(distance-target)*0.22-p.roll*6-nearest*0.25
		if score < best_score:
			best_score = score
			best = p
	return best

func route(a: Vector2, b: Vector2) -> Array:
	var origin: int = floori(a.y)*N+floori(a.x)
	var goal: int = floori(b.y)*N+floori(b.x)
	var cost := PackedFloat64Array(); cost.resize(N*N); cost.fill(INF)
	var parent := PackedInt32Array(); parent.resize(N*N); parent.fill(-1)
	var open := Heap.new()
	cost[origin] = 0
	open.push({"key":origin,"g":0.0,"f":0.0})
	while not open.items.is_empty():
		var p: Dictionary = open.pop()
		if p.g != cost[p.key]: continue
		if p.key == goal: break
		var x: int = p.key % N
		var y: int = int(p.key / N)
		for offset in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]:
			var xx: int = x+offset.x
			var yy: int = y+offset.y
			var key: int = yy*N+xx
			if xx < 1 or yy < 1 or xx >= N-1 or yy >= N-1: continue
			var next_cost: float = p.g+(0.7 if road[key] else 9.0 if water[key] else 1.3+noise[key])
			if next_cost >= cost[key]: continue
			cost[key] = next_cost
			parent[key] = p.key
			open.push({"key":key,"g":next_cost,"f":next_cost+sqrt(pow(xx-b.x,2)+pow(yy-b.y,2))*0.7})
	var points: Array = []
	var k: int = goal
	while k != -1:
		points.push_front([k % N,int(k/N)])
		if k == origin: break
		k = parent[k]
	return points

func generate(seed_value: int, campaign: Array) -> Dictionary:
	random = SeedRng.new(seed_value ^ 0xa511e9b3)
	candidates.clear(); occupied.clear()
	var kind: int = random.integer(0,2)
	var rotation: int = random.integer(0,3)
	var phase: float = random.between(0,TAU)
	var center: float = random.between(35,53)
	var bend: float = random.between(7,13)
	var frequency: float = random.between(0.045,0.085)
	var river_width: float = random.between(2.4,4.2)
	var lake: Dictionary = {"x":random.between(33,55),"y":random.between(33,55),"rx":random.between(15,23),"ry":random.between(12,20)}
	var coast: float = random.between(19,30)
	var bay: float = random.between(5,12)
	var ponds: Array = []
	for i in random.integer(2,4):
		ponds.append({"x":random.between(12,76),"y":random.between(12,76),"rx":random.between(3,7),"ry":random.between(3,6)})
	water.resize(N*N); water.fill(0)
	road.resize(N*N); road.fill(0)
	var clearance := PackedInt32Array(); clearance.resize(N*N); clearance.fill(255)
	var queue: Array[int] = []
	for y in N:
		for x in N:
			var u: float = x
			var v: float = y
			match rotation:
				1: u = y; v = N-1-x
				2: u = N-1-x; v = N-1-y
				3: u = N-1-y; v = x
			var wave: float = sin(v*frequency+phase)*bend+sin(v*0.17+phase)*2
			var wet: bool = false
			match kind:
				0: wet = absf(u-center-wave) < river_width
				1:
					wet = pow((u-lake.x)/lake.rx,2)+pow((v-lake.y)/lake.ry,2) < 1+0.16*sin(u*0.22+v*0.19+phase)
					if v > lake.y: wet = wet or absf(u-lake.x-sin(v*0.075+phase)*4) < 2.1
				2: wet = u < coast+sin(v*0.075+phase)*bay+sin(v*0.19)*2.5
			for p in ponds:
				if pow((u-p.x)/p.rx,2)+pow((v-p.y)/p.ry,2) < 1+0.12*sin(u*0.4+v*0.3+phase): wet = true
			if wet:
				water[y*N+x] = 1; clearance[y*N+x] = 0; queue.append(y*N+x)
	var cursor: int = 0
	while cursor < queue.size():
		var key: int = queue[cursor]; cursor += 1
		for dy in range(-1,2):
			for dx in range(-1,2):
				var xx: int = key % N+dx
				var yy: int = int(key/N)+dy
				var k: int = yy*N+xx
				if xx < 0 or yy < 0 or xx >= N or yy >= N or clearance[k] <= clearance[key]+1: continue
				clearance[k] = clearance[key]+1; queue.append(k)
	for y in range(8,N-8,2):
		for x in range(8,N-8,2):
			if clearance[y*N+x] >= 6:
				candidates.append({"x":x+0.5,"y":y+0.5,"clearance":clearance[y*N+x],"roll":random.next()})
	var starts: Array = candidates.filter(func(p): return p.x >= 15 and p.y >= 15 and p.x <= N-15 and p.y <= N-15 and p.clearance >= 9)
	starts.sort_custom(func(a,b): return absf(a.clearance-11)+a.roll*8 < absf(b.clearance-11)+b.roll*8)
	if starts.is_empty():
		starts = candidates.duplicate(); starts.sort_custom(func(a,b): return a.clearance > b.clearance)
	if starts.is_empty(): return {}
	home = position(starts[0])
	occupied.append({"x":home.x,"y":home.y,"radius":8.5})
	var lairs: Array = []
	var clearings: Array = []
	for definition in campaign:
		var frontier: bool = definition.get("frontier",false)
		var target: float = random.between(38,65) if frontier else random.between(17,26)
		var p: Dictionary = site(32 if frontier else 16,120 if frontier else 30,13 if frontier else 10,target)
		if p.is_empty(): p = site(16,120,8,target)
		if p.is_empty(): return {}
		var entry: Dictionary = definition.duplicate()
		entry.x = floori(p.x)-1; entry.y = floori(p.y)-1
		lairs.append(entry)
		occupied.append({"x":p.x,"y":p.y,"radius":6})
	for i in 4:
		var p: Dictionary = site(16,120,10,random.between(25,65))
		if p.is_empty(): p = site(14,120,7,35)
		if not p.is_empty():
			clearings.append([floori(p.x),floori(p.y),6]); occupied.append({"x":p.x,"y":p.y,"radius":6})
	var troll: Dictionary = site(18,30,7,22)
	if troll.is_empty():
		var choices: Array = candidates.filter(func(p): return position(p).distance_to(home)>16)
		choices.sort_custom(func(a,b): return a.roll < b.roll); troll = choices[0]
	var troll_entry: Dictionary = {"x":troll.x,"y":troll.y}
	occupied.append({"x":troll.x,"y":troll.y,"radius":6})
	var cottages: Array = []
	var angle: float = random.between(0,TAU)
	for i in 3:
		var a: float = angle+i*TAU/3+random.between(-0.2,0.2)
		var radius: float = random.between(4.4,5.5)
		cottages.append({"x":floori(home.x+cos(a)*radius),"y":floori(home.y+sin(a)*radius)})
	var level: Dictionary = {"name":["River Marches","Great Lake","Coastal Realm"][kind],"kind":kind,"rotation":rotation,
		"start":{"x":floori(home.x)-1,"y":floori(home.y)-1},"cottages":cottages,"lairs":lairs,"clearings":clearings,"trollEntry":troll_entry,"roads":[],"bridges":[]}
	var details := SeedRng.new(seed_value ^ 0x68bc21eb)
	var tiles: Array = []
	for y in N:
		for x in N:
			tiles.append({"x":x,"y":y,"kind":"water" if water[y*N+x] else "grass","noise":details.next(),"blocked":false,"clearing":false,"visible":false,"explored":false,"bridgeAxis":"x"})
	noise.resize(N*N)
	for i in N*N: noise[i] = random.between(0,0.7)
	var nodes: Array[Vector2] = [home]
	for p in lairs: nodes.append(Vector2(p.x+1,p.y+1))
	for p in clearings: nodes.append(Vector2(p[0],p[1]))
	nodes.append(position(troll_entry))
	var connected: Array[Vector2] = [nodes.pop_front()]
	while not nodes.is_empty():
		var best_distance: float = INF
		var best_index: int = 0
		var from := Vector2.ZERO
		for i in nodes.size():
			for q in connected:
				var d: float = q.distance_to(nodes[i])
				if d < best_distance: best_distance = d; best_index = i; from = q
		var to: Vector2 = nodes.pop_at(best_index)
		var points: Array = route(from,to)
		level.roads.append(points); connected.append(to)
		for i in points.size():
			var x: int = points[i][0]; var y: int = points[i][1]
			road[y*N+x] = 1
			var before: Array = points[maxi(0,i-1)]; var after: Array = points[mini(points.size()-1,i+1)]
			var axis: String = "x" if abs(after[0]-before[0]) >= abs(after[1]-before[1]) else "y"
			for dy in range(-2,3):
				for dx in range(-2,3):
					if x+dx < 0 or y+dy < 0 or x+dx >= N or y+dy >= N: continue
					var t: Dictionary = tiles[(y+dy)*N+x+dx]
					t.clearing = true
					if abs(dx)>1 or abs(dy)>1: continue
					if t.kind == "water" and water[y*N+x]: t.kind = "bridge"; t.bridgeAxis = axis
					elif t.kind == "grass": t.kind = "path"
	for t in tiles:
		for p in occupied:
			if Vector2(t.x+0.5,t.y+0.5).distance_to(position(p)) < p.radius: t.clearing = true; break
		if t.kind == "bridge": level.bridges.append({"x":t.x,"y":t.y,"axis":t.bridgeAxis})
	var pine_chance: float = random.between(0.25,0.85)
	var phases: Array = [random.between(0,6.28),random.between(0,6.28),random.between(0,6.28)]
	var trees: Array = []; var decor: Array = []
	for y in range(1,N-1):
		for x in range(1,N-1):
			var t: Dictionary = tiles[y*N+x]
			var forest: float = (sin(x*0.16+phases[0])+cos(y*0.14+phases[1])+sin((x+y)*0.075+phases[2]))/3
			var density: float = 0.66 if forest>0.2 else 0.34 if forest> -0.2 else 0.1
			if t.kind == "grass" and not t.clearing and details.next() < density:
				trees.append({"x":x+0.25+details.next()*0.5,"y":y+0.25+details.next()*0.5,"type":("pine" if details.next()<pine_chance else "oak")+str(int(details.next()*6)),"scale":0.7+details.next()*0.52})
				t.blocked = true
			elif t.kind == "grass" and details.next() < 0.22:
				decor.append({"x":x+details.next(),"y":y+details.next(),"type":"rock" if details.next()<0.52 else "flowers","seed":details.next()})
	return {"seed":seed_value,"size":N,"name":level.name,"level":level,"tiles":tiles,"trees":trees,"decor":decor}
