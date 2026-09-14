extends SceneTree
const Generator = preload("res://scripts/world_generator.gd")
const Simulation = preload("res://scripts/simulation.gd")
const SeedRng = preload("res://scripts/seed_rng.gd")
func _initialize() -> void:
	var balance = JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	var references = JSON.parse_string(FileAccess.get_file_as_string("res://tests/reference_maps.json"))
	var failures: int = 0
	for reference in references:
		var rng := SeedRng.new(int(reference.seed))
		for expected in reference.rolls:
			if absf(rng.next()-expected)>0.00000000001: failures += 1; push_error("RNG mismatch")
		var map = Generator.new().generate(int(reference.seed),balance.campaign)
		if map.is_empty(): failures += 1; continue
		var normalized = JSON.parse_string(JSON.stringify(map.level))
		var same: bool = map.name==reference.name and normalized.start==reference.start and normalized.lairs==reference.lairs
		var tiles: int = 0
		for i in map.tiles.size():
			if map.tiles[i].kind != reference.kinds[i]: tiles += 1
		print("MAP ",reference.seed," layout=",same," tile differences=",tiles," trees=",map.trees.size()," reference=",reference.trees)
		if not same or tiles > 0 or map.trees.size()!=reference.trees: failures += 1
	if SeedRng.normalize("Alderwick") != int(references[-1].seed): failures += 1
	var scanned: int=0
	for seed in 100:
		var s=Simulation.new(seed)
		var origin=s.near_open(s.pos(s.palace()))
		if s.lairs().size()!=8: failures+=1
		for b in s.buildings:
			for y in range(b.ty,b.ty+b.size):
				for x in range(b.tx,b.tx+b.size):
					if s.tile_at(Vector2(x,y)).kind in ["water","bridge"]: failures+=1
			if b.hostile and s.find_path(origin,s.pos(b)).is_empty(): failures+=1; push_error("Unreachable lair: seed %d"%seed)
		for u in s.units:
			if not s.walkable(u.pos): failures+=1; push_error("Blocked spawn: seed %d"%seed)
		scanned+=1
		if scanned%25==0: print("Checked ",scanned," maps")
	var report={"reference_maps":references.size(),"structural_maps":scanned,"checks":"RNG, geography, tile kinds, lair layout, tree counts, dry foundations, reachable lairs and walkable spawns","failures":failures}
	FileAccess.open("res://reports/full-maps.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print("Map parity failures: ",failures)
	quit(0 if failures==0 else 1)
