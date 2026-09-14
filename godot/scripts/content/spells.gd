@tool
extends Resource
## Editable game definition. Runtime uses a copy, so play never mutates the asset.
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var cost: int = 0
@export var mana: float = 0
@export var cooldown: float = 10
@export var radius: float = 3
@export var research: int = 0
@export var time: float = 20
@export var properties: Dictionary = {}
func data() -> Dictionary:
	var out: Dictionary = properties.duplicate(true)
	out["name"] = name
	out["description"] = description
	out["cost"] = cost
	out["mana"] = mana
	out["cooldown"] = cooldown
	out["radius"] = radius
	out["research"] = research
	out["time"] = time
	return out
