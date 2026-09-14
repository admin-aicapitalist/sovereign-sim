@tool
extends Resource
## Editable game definition. Runtime uses a copy, so play never mutates the asset.
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var slot: String = "weapon"
@export var damage: float = 0
@export var armor: float = 0
@export var rank: int = 1
@export var properties: Dictionary = {}
func data() -> Dictionary:
	var out: Dictionary = properties.duplicate(true)
	out["name"] = name
	out["description"] = description
	out["slot"] = slot
	out["damage"] = damage
	out["armor"] = armor
	out["rank"] = rank
	return out
