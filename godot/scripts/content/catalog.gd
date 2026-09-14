@tool
extends Resource
## Drag definitions into these lists to register content with the game.
@export var units: Array[Resource] = []
@export var buildings: Array[Resource] = []
@export var spells: Array[Resource] = []
@export var items: Array[Resource] = []
@export var mission: Resource
func definitions() -> Dictionary:
	var out: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/balance.json"))
	for kind in ["units","buildings","spells","items"]:
		out[kind]={}
		for entry in get(kind):
			assert(entry!=null and not entry.id.is_empty() and not out[kind].has(entry.id),"Missing or duplicate content id")
			out[kind][entry.id]=entry.data()
	out.mission=mission.data()
	return out
