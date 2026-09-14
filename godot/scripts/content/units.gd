@tool
extends Resource
## Editable game definition. Runtime uses a copy, so play never mutates the asset.
@export var id: String = ""
@export var name: String = ""
@export var hp: float = 100
@export var damage: float = 10
@export var armor: float = 0
@export var range: float = 1
@export var speed: float = 1
@export var rate: float = 1
@export var sight: float = 7
@export var cost: int = 0
@export var properties: Dictionary = {}
func data() -> Dictionary:
	var out: Dictionary = properties.duplicate(true)
	out["name"] = name
	out["hp"] = hp
	out["damage"] = damage
	out["armor"] = armor
	out["range"] = range
	out["speed"] = speed
	out["rate"] = rate
	out["sight"] = sight
	out["cost"] = cost
	return out
