@tool
extends Resource
## Editable game definition. Runtime uses a copy, so play never mutates the asset.
@export var id: String = ""
@export var name: String = ""
@export var description: String = ""
@export var hp: float = 500
@export var cost: int = 0
@export var size: int = 2
@export var upgrade_cost: int = 0
@export var upgrade_time: float = 30
@export var upgrade_capacity: int = 2
@export var upgrade_armor: float = 2
@export var upgrade_damage: float = 4
@export var properties: Dictionary = {}
func data() -> Dictionary:
	var out: Dictionary = properties.duplicate(true)
	out["name"] = name
	out["description"] = description
	out["hp"] = hp
	out["cost"] = cost
	out["size"] = size
	out["upgrade_cost"] = upgrade_cost
	out["upgrade_time"] = upgrade_time
	out["upgrade_capacity"] = upgrade_capacity
	out["upgrade_armor"] = upgrade_armor
	out["upgrade_damage"] = upgrade_damage
	return out
