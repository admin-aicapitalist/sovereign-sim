extends RefCounted
## Engine-independent game state: the renderer never advances gameplay.
## Coordinates are in square map tiles; isometric projection is presentation only.

class Actor extends RefCounted:
	var id: int
	var type: String
	var pos: Vector2
	var hp: float
	var max_hp: float
	var hostile: bool
	var hero: bool
	var home: int = 0
	var gold: float = 0
	var target: int = 0
	var state: String = "Patrolling"
	var think: float = 0
	var cooldown: float = 0
	var repath: float = 0
	var destination: Vector2
	var path: PackedVector2Array = []
	var path_index: int = 0
	var facing: float = 1
	var animation: float = 0
	var attacking: float = 0
	var dead: bool = false
	var definition: Dictionary
	func save() -> Dictionary:
		var result: Dictionary = {}
		for key in ["id", "type", "hp", "max_hp", "hostile", "hero", "home", "gold", "target", "state", "think", "cooldown", "repath", "path_index", "facing", "animation", "attacking", "dead"]:
			result[key] = get(key)
		result.pos = [pos.x, pos.y]
		result.destination = [destination.x, destination.y]
		result.path = []
		for point in path:
			result.path.append([point.x, point.y])
		return result

var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world.json"))
var definitions: Dictionary = fixture.definitions
var size: int = fixture.size
var units: Array[Actor] = []
var buildings: Array[Dictionary] = []
var flags: Dictionary = {}
var loot: Array[Dictionary] = []
var actors: Dictionary = {}
var buckets: Dictionary = {}
var grid := AStarGrid2D.new()
var rng := RandomNumberGenerator.new()
var next_id: int = 1
var gold: float = 1500
var time: float = 0
var economy: float = 0
var paused: bool = false
var result: String = ""
var message: String = "Build a Warriors’ Guild, then recruit heroes."
var stats: Dictionary = {}
var paths_this_tick: int = 0
var stress: bool = false
var revision: int = 0

func _init() -> void:
	reset()

func reset() -> void:
	units.clear()
	buildings.clear()
	actors.clear()
	buckets.clear()
	flags.clear()
	loot.clear()
	next_id = 1
	gold = 1500
	time = 0
	economy = 0
	paused = false
	stress = false
	result = ""
	rng.seed = int(fixture.seed)
	stats = {"hits": 0, "kills": 0, "paths": 0, "decisions": 0, "moves": 0, "taxes": 0, "built": 0, "recruits": 0, "loot": 0, "path_deferrals": 0}
	for item in fixture.buildings:
		add_building(item.type, Vector2i(item.x, item.y), true)
	rebuild_grid()
	for item in fixture.units:
		var home_id: int = palace().id
		if definitions.units[item.type].get("hostile", false):
			home_id = lairs()[0].id
		add_unit(item.type, Vector2(item.x, item.y), home_id)
	message = "Build a Warriors’ Guild, then recruit heroes."
	revision += 1

func rebuild_grid() -> void:
	grid.region = Rect2i(0, 0, size, size)
	grid.cell_size = Vector2.ONE
	grid.offset = Vector2(0.5, 0.5)
	grid.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	grid.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	grid.update()
	# Fixture solids contain the original surviving foundations and trees.
	for i in fixture.tiles.size():
		var tile: Dictionary = fixture.tiles[i]
		grid.set_point_solid(Vector2i(i % size, i / size), tile.blocked or tile.kind == "water")
	# Clear saved foundations, then reapply only surviving buildings.
	for b in buildings:
		set_foundation(b, not b.dead)

func set_foundation(b: Dictionary, solid: bool) -> void:
	if grid.is_dirty():
		return
	for y in range(int(b.ty), int(b.ty + b.size)):
		for x in range(int(b.tx), int(b.tx + b.size)):
			grid.set_point_solid(Vector2i(x, y), solid)

func walkable(pos: Vector2) -> bool:
	var tile := Vector2i(floori(pos.x), floori(pos.y))
	return grid.is_in_boundsv(tile) and not grid.is_point_solid(tile)

func palace() -> Dictionary:
	return buildings[0]

func lairs() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for b in buildings:
		if b.hostile and not b.dead:
			found.append(b)
	return found

func building(id: int) -> Dictionary:
	for b in buildings:
		if b.id == id:
			return b
	return {}

func bpos(b: Dictionary) -> Vector2:
	return Vector2(b.x, b.y)

func add_building(type: String, tile: Vector2i, built: bool) -> Dictionary:
	var d: Dictionary = definitions.buildings[type]
	var b: Dictionary = {"id": next_id, "type": type, "tx": tile.x, "ty": tile.y, "size": d.size,
		"x": tile.x + d.size / 2.0, "y": tile.y + d.size / 2.0, "hp": d.hp if built else d.hp * 0.2,
		"max_hp": d.hp, "progress": 1.0 if built else 0.0, "hostile": d.get("hostile", false),
		"dead": false, "tax": 0.0, "spawn": d.get("interval", 52.0)}
	next_id += 1
	buildings.append(b)
	return b

func add_unit(type: String, pos: Vector2, home: int = 0) -> Actor:
	var u := Actor.new()
	u.id = next_id
	next_id += 1
	u.type = type
	u.pos = pos
	u.destination = pos
	u.definition = definitions.units[type]
	u.hp = u.definition.hp
	u.max_hp = u.hp
	u.hostile = u.definition.get("hostile", false)
	u.hero = u.definition.get("hero", false)
	u.home = home
	u.think = rng.randf_range(0, 0.7)
	units.append(u)
	actors[u.id] = u
	return u

func near_open(pos: Vector2, radius: int = 5) -> Vector2:
	for r in range(1, radius + 1):
		for offset in [Vector2(r, 0), Vector2(0, r), Vector2(-r, 0), Vector2(0, -r), Vector2(r, r), Vector2(-r, -r)]:
			var point: Vector2 = (pos + offset).floor() + Vector2(0.5, 0.5)
			if walkable(point):
				return point
	return pos

func can_build(type: String, tile: Vector2i) -> bool:
	if not type in ["warriors", "rangers", "house", "marketplace", "tower"] or result != "":
		return false
	var d: Dictionary = definitions.buildings[type]
	var center: Vector2 = Vector2(tile) + Vector2.ONE * d.size / 2.0
	if center.distance_to(bpos(palace())) > 14:
		return false
	for y in range(tile.y, tile.y + int(d.size)):
		for x in range(tile.x, tile.x + int(d.size)):
			if not walkable(Vector2(x, y)) or fixture.tiles[y * size + x].kind == "bridge":
				return false
	for b in buildings:
		if not b.dead and absf(b.x - center.x) < (b.size + d.size) / 2.0 + 0.35 and absf(b.y - center.y) < (b.size + d.size) / 2.0 + 0.35:
			return false
	var rect := Rect2(Vector2(tile), Vector2.ONE * d.size)
	for u in units:
		if not u.dead and rect.has_point(u.pos):
			return false
	for pile in loot:
		if rect.has_point(Vector2(pile.x, pile.y)):
			return false
	return true

func find_site(type: String) -> Vector2i:
	var origin := Vector2i(palace().tx, palace().ty)
	for r in range(2, 13):
		for y in range(origin.y-r, origin.y+r+1):
			for x in range(origin.x-r, origin.x+r+1):
				if can_build(type, Vector2i(x,y)):
					return Vector2i(x,y)
	return Vector2i(-1,-1)

func build(type: String, tile: Vector2i) -> Dictionary:
	if not can_build(type, tile):
		message = "Choose clear ground within 14 tiles of the Palace."
		return {}
	var cost: float = definitions.buildings[type].cost
	if gold < cost:
		message = "The treasury needs more gold."
		return {}
	gold -= cost
	var b := add_building(type, tile, false)
	set_foundation(b, true)
	for u in units:
		if u.type == "peasant":
			u.think = 0
	message = "Construction ordered: " + definitions.buildings[type].name
	revision += 1
	return b

func recruit(guild_id: int) -> Actor:
	var b := building(guild_id)
	if b.is_empty() or b.dead or b.progress < 1 or result != "":
		return null
	var d: Dictionary = definitions.buildings[b.type]
	if not d.has("recruits"):
		return null
	var count: int = 0
	for u in units:
		if not u.dead and u.home == guild_id and u.hero:
			count += 1
	var cost: float = definitions.units[d.recruits].cost
	if count >= int(d.capacity) or gold < cost:
		message = "Guild full or insufficient gold."
		return null
	gold -= cost
	var u := add_unit(d.recruits, near_open(bpos(b)), guild_id)
	u.gold = 24
	stats.recruits += 1
	message = "A " + u.type + " has joined your kingdom."
	return u

func bounty(id: int, reward: float = 100) -> bool:
	var b := building(id)
	if result != "" or b.is_empty() or b.dead or not b.hostile or reward <= 0 or gold < reward:
		return false
	gold -= reward
	flags[id] = flags.get(id, 0.0) + reward
	message = "Attack bounty: %d gold." % flags[id]
	for u in units:
		if u.hero:
			u.think = 0
	return true

func cancel_bounty(id: int) -> void:
	if flags.has(id):
		gold += flags[id]
		flags.erase(id)

func rebuild_buckets() -> void:
	buckets.clear()
	for u in units:
		if u.dead:
			continue
		var key := Vector2i(floori(u.pos.x / 6), floori(u.pos.y / 6))
		if not buckets.has(key):
			buckets[key] = []
		buckets[key].append(u)

func nearest_enemy(u: Actor, radius: float) -> Actor:
	var best: Actor = null
	var distance: float = radius * radius
	var base := Vector2i(floori(u.pos.x / 6), floori(u.pos.y / 6))
	var reach: int = ceili(radius / 6)
	for y in range(base.y - reach, base.y + reach + 1):
		for x in range(base.x - reach, base.x + reach + 1):
			for other: Actor in buckets.get(Vector2i(x, y), []):
				if other.dead or other.hostile == u.hostile:
					continue
				var dist: float = u.pos.distance_squared_to(other.pos)
				if dist < distance:
					distance = dist
					best = other
	return best

func decide(u: Actor) -> void:
	stats.decisions += 1
	u.target = 0
	if u.hero and u.hp < u.max_hp * (0.85 if u.state in ["Fleeing", "Resting"] else 0.3):
		u.destination = near_open(bpos(palace()))
		u.state = "Resting" if u.pos.distance_to(bpos(palace())) < 3.5 else "Fleeing"
		return
	if u.type not in ["peasant", "collector"]:
		var foe := nearest_enemy(u, float(u.definition.get("range", 1)) + 3)
		if foe != null:
			u.target = foe.id
			u.state = "Fighting"
			return
	if u.type == "peasant":
		var nearest: Dictionary = {}
		var best: float = INF
		for b in buildings:
			if not b.dead and not b.hostile and (b.progress < 1 or b.hp < b.max_hp):
				var dist: float = u.pos.distance_to(bpos(b))
				if dist < best:
					best = dist
					nearest = b
		if not nearest.is_empty():
			u.target = nearest.id
			u.state = "Building" if nearest.progress < 1 else "Repairing"
			return
	if u.type == "collector":
		if u.gold > 0:
			u.target = palace().id
			u.state = "Delivering taxes"
			return
		for b in buildings:
			if not b.dead and not b.hostile and b.tax >= 10:
				u.target = b.id
				u.state = "Collecting taxes"
				return
	if u.hero:
		for i in range(loot.size()-1, -1, -1):
			var pile: Dictionary = loot[i]
			var point := Vector2(pile.x, pile.y)
			if u.pos.distance_to(point) < 1:
				u.gold += pile.gold
				stats.loot += pile.gold
				loot.remove_at(i)
			elif u.pos.distance_to(point) < 7:
				u.destination = point
				u.state = "Recovering treasure"
				return
		var score: float = 0
		for id in flags:
			var b := building(id)
			if b.is_empty() or b.dead:
				continue
			var utility: float = flags[id] * float(u.definition.get("bravery", 1)) / (1 + u.pos.distance_to(bpos(b)) * 0.08)
			if utility > score:
				score = utility
				u.target = int(id)
		if u.target != 0:
			u.state = "Answering a bounty"
			return
	if u.hostile and (time > 110 or stress):
		u.target = palace().id
		u.state = "Raiding"
		return
	if u.path_index >= u.path.size():
		var home := building(u.home)
		var origin: Vector2 = bpos(home) if not home.is_empty() and not home.dead else bpos(palace())
		u.destination = near_open(origin + Vector2(rng.randf_range(-5,5),rng.randf_range(-5,5)))
		u.state = "Patrolling"

func navigate(u: Actor, destination: Vector2, dt: float) -> void:
	# Failed or exhausted paths also respect the retry interval. Otherwise actors
	# beside blocked targets can consume the whole path budget every frame.
	if u.repath <= 0:
		if paths_this_tick >= 24:
			stats.path_deferrals += 1
		else:
			paths_this_tick += 1
			stats.paths += 1
			var end: Vector2 = destination if walkable(destination) else near_open(destination)
			if walkable(u.pos) and walkable(end):
				u.path = grid.get_point_path(Vector2i(u.pos.floor()), Vector2i(end.floor()))
				u.path_index = 1 if u.path.size() > 1 else u.path.size()
			u.repath = 2.5 + float(u.id % 7) * 0.1
	var remaining: float = u.definition.speed * dt * (1.25 if u.state == "Fleeing" else 1.0)
	while remaining > 0 and u.path_index < u.path.size():
		var point := u.path[u.path_index]
		if not walkable(point):
			u.path = []
			u.repath = 0
			break
		var delta := point - u.pos
		var distance := delta.length()
		if distance > 0.0001:
			u.pos += delta / distance * minf(distance, remaining)
			u.facing = 1 if delta.x - delta.y >= 0 else -1
			u.animation += dt * 7
			stats.moves += 1
		remaining -= distance
		if u.pos.distance_to(point) < 0.001:
			u.path_index += 1
		else:
			break

func hurt_unit(u: Actor, damage: float) -> void:
	if u.dead:
		return
	u.hp -= maxf(1, damage - float(u.definition.get("armor", 0)))
	stats.hits += 1
	if u.hp <= 0:
		u.dead = true
		u.hp = 0
		stats.kills += 1
		if u.hostile and not stress:
			loot.append({"x": u.pos.x, "y": u.pos.y, "gold": rng.randi_range(12,24)})

func hurt_building(b: Dictionary, damage: float) -> void:
	if b.dead:
		return
	b.hp -= damage
	stats.hits += 1
	if b.hp <= 0:
		b.hp = 0
		b.dead = true
		set_foundation(b, false)
		revision += 1
		if b.hostile:
			gold += definitions.buildings[b.type].get("reward", 0)
			loot.append({"x": b.x, "y": b.y, "gold": 60})
		if flags.has(int(b.id)):
			var claimants: Array[Actor] = []
			for u in units:
				if u.hero and not u.dead and u.pos.distance_to(bpos(b)) < 12:
					claimants.append(u)
			if claimants.is_empty():
				gold += flags[int(b.id)]
			else:
				for u in claimants:
					u.gold += flags[int(b.id)] / claimants.size()
			flags.erase(int(b.id))

func tick(dt: float) -> void:
	if paused or result != "":
		return
	time += dt
	paths_this_tick = 0
	rebuild_buckets()
	for u in units:
		if u.dead:
			continue
		u.think -= dt
		u.cooldown -= dt
		u.repath -= dt
		u.attacking = maxf(0, u.attacking - dt)
		if u.think <= 0:
			decide(u)
			u.think = 0.65 + float(u.id % 11) * 0.017
		if u.state == "Resting":
			u.hp = minf(u.max_hp, u.hp + 10 * dt)
			continue
		var target_unit: Actor = actors.get(u.target)
		var target_building: Dictionary = building(u.target) if u.target and target_unit == null else {}
		var destination := u.destination
		var active_target: bool = target_unit != null and not target_unit.dead or not target_building.is_empty() and not target_building.dead
		if active_target:
			destination = target_unit.pos if target_unit != null else bpos(target_building)
			var reach: float = float(u.definition.get("range", 1))
			if not target_building.is_empty():
				reach += target_building.size * 0.45
				if u.type in ["peasant", "collector"]:
					reach = target_building.size * 0.7 + 1.4
			if u.pos.distance_to(destination) <= reach:
				u.path = []
				u.path_index = 0
				if u.type == "peasant":
					if target_building.progress < 1:
						target_building.progress = minf(1, target_building.progress + dt / float(definitions.buildings[target_building.type].buildTime))
						target_building.hp = maxf(target_building.hp, target_building.max_hp * (0.2 + 0.8 * target_building.progress))
						if target_building.progress == 1:
							stats.built += 1
							message = definitions.buildings[target_building.type].name + " is ready. Select it to recruit."
					else:
						target_building.hp = minf(target_building.max_hp, target_building.hp + dt * 9)
				elif u.type == "collector":
					if u.gold > 0:
						gold += u.gold
						stats.taxes += u.gold
						u.gold = 0
					else:
						u.gold += target_building.tax
						target_building.tax = 0
					u.think = 0
				elif u.cooldown <= 0:
					u.cooldown = u.definition.rate
					u.attacking = 0.34
					if target_unit != null:
						hurt_unit(target_unit, u.definition.damage)
					else:
						hurt_building(target_building, u.definition.damage)
				continue
		navigate(u, destination, dt)
	for b in buildings:
		if b.dead or b.progress < 1:
			continue
		if b.hostile and not stress:
			b.spawn -= dt
			if b.spawn <= 0:
				b.spawn = definitions.buildings[b.type].get("interval", 52)
				var count: int = 0
				for u in units:
					if not u.dead and u.home == int(b.id):
						count += 1
				if count < 6:
					add_unit(definitions.buildings[b.type].spawn, near_open(bpos(b)), b.id)
		if b.type == "tower":
			b.spawn -= dt
			if b.spawn <= 0:
				for u in units:
					if not u.dead and u.hostile and u.pos.distance_to(bpos(b)) < 7:
						hurt_unit(u, 21)
						b.spawn = 1.4
						break
	economy += dt
	if economy >= 10:
		economy -= 10
		for b in buildings:
			if not b.dead and not b.hostile and b.progress == 1:
				var tax: float = definitions.buildings[b.type].get("tax", 0)
				if b.type == "palace":
					gold += tax
					stats.taxes += tax
				else:
					b.tax += tax
	if not stress:
		if palace().dead:
			result = "defeat"
		elif lairs().is_empty():
			result = "victory"

func setup_stress(count: int) -> void:
	reset()
	stress = true
	units.clear()
	actors.clear()
	flags[int(lairs()[0].id)] = 500
	var open: Array[Vector2] = []
	for i in fixture.tiles.size():
		var point := Vector2(i % size + 0.5, i / size + 0.5)
		if walkable(point):
			open.append(point)
	for i in count:
		var point: Vector2 = open[rng.randi_range(0, open.size()-1)]
		var u := add_unit("goblin" if i % 3 == 0 else "warrior", point, palace().id)
		# Long-lived actors keep the test load constant; damage/pathfinding still run.
		u.hp = 1000000
		u.max_hp = u.hp
	for b in buildings:
		b.hp = 1000000000
		b.max_hp = b.hp
	message = "Stress scenario: %d active agents" % count

func snapshot() -> Dictionary:
	var serialized: Array = []
	for u in units:
		serialized.append(u.save())
	var saved_flags: Array = []
	for id in flags:
		saved_flags.append([id, flags[id]])
	return {"version": 1, "seed": fixture.seed, "next_id": next_id, "time": time, "gold": gold,
		"economy": economy, "rng": str(rng.state), "buildings": buildings.duplicate(true),
		"units": serialized, "flags": saved_flags, "loot": loot.duplicate(true), "stats": stats.duplicate(true),
		"paused": paused, "result": result, "stress": stress}

func restore(data: Dictionary) -> bool:
	if data.get("version", 0) != 1 or data.get("seed", -1) != fixture.seed:
		return false
	# Validate the envelope before replacing any active state.
	for key in ["units", "buildings", "flags", "loot"]:
		if not data.get(key) is Array:
			return false
	for key in ["next_id", "time", "gold", "economy", "rng", "stats", "paused", "result", "stress"]:
		if not data.has(key):
			return false
	for key in ["next_id", "time", "gold", "economy"]:
		if not finite_number(data[key]) or data[key] < 0:
			return false
	if not data.rng is String or not data.rng.is_valid_int() or not same_shape(data.stats, stats):
		return false
	if not data.paused is bool or not data.stress is bool or data.result not in ["", "victory", "defeat"]:
		return false
	var ids: Dictionary = {}
	var actor_shape: Dictionary = Actor.new().save()
	for item in data.units:
		if not same_shape(item, actor_shape) or not definitions.units.has(item.type):
			return false
		if not valid_point(item.pos) or not valid_point(item.destination) or item.path_index < 0 or item.path_index > item.path.size():
			return false
		for point in item.path:
			if not valid_point(point):
				return false
		if item.id <= 0 or item.id >= data.next_id or ids.has(int(item.id)):
			return false
		ids[int(item.id)] = true
	if data.buildings.is_empty():
		return false
	for b in data.buildings:
		if not same_shape(b, palace()) or not definitions.buildings.has(b.type):
			return false
		if b.size != definitions.buildings[b.type].size or b.tx < 0 or b.ty < 0 or b.tx+b.size > size or b.ty+b.size > size:
			return false
		if b.id <= 0 or b.id >= data.next_id or ids.has(int(b.id)):
			return false
		ids[int(b.id)] = true
	if data.buildings[0].type != "palace":
		return false
	for pair in data.flags:
		if not pair is Array or pair.size() != 2 or not finite_number(pair[0]) or not finite_number(pair[1]) or pair[1] < 0 or not ids.has(int(pair[0])):
			return false
	for pile in data.loot:
		if not same_shape(pile, {"x":0.0,"y":0.0,"gold":0.0}):
			return false
	units.clear()
	actors.clear()
	buildings.assign(data.buildings.duplicate(true))
	flags.clear()
	for pair in data.flags:
		flags[int(pair[0])] = pair[1]
	loot.assign(data.loot.duplicate(true))
	next_id = int(data.next_id)
	time = data.time
	gold = data.gold
	economy = data.economy
	rng.state = int(data.rng)
	stats = data.stats.duplicate(true)
	paused = data.paused
	result = data.result
	stress = data.stress
	for item in data.units:
		var u := Actor.new()
		for key in item:
			if key not in ["pos", "destination", "path"]:
				u.set(key, item[key])
		u.pos = Vector2(item.pos[0],item.pos[1])
		u.destination = Vector2(item.destination[0],item.destination[1])
		for point in item.path:
			u.path.append(Vector2(point[0],point[1]))
		u.definition = definitions.units[u.type]
		units.append(u)
		actors[u.id] = u
	rebuild_grid()
	rebuild_buckets()
	revision += 1
	message = "Kingdom restored."
	return true

func finite_number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(value)

func valid_point(value: Variant) -> bool:
	return value is Array and value.size() == 2 and finite_number(value[0]) and finite_number(value[1]) and value[0] >= 0 and value[1] >= 0 and value[0] < size and value[1] < size

func same_shape(value: Variant, sample: Variant) -> bool:
	if sample is Dictionary:
		if not value is Dictionary or value.size() != sample.size():
			return false
		for key in sample:
			if not value.has(key) or not same_shape(value[key], sample[key]):
				return false
		return true
	if sample is int or sample is float:
		return finite_number(value)
	return typeof(value) == typeof(sample)
