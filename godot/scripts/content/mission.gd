@tool
extends Resource
## Editable game definition. Runtime uses a copy, so play never mutates the asset.
@export var id: String = ""
@export var name: String = "The Ember Crown"
@export var description: String = "Break two lairs, recover the Ashen Monastery, and defeat the Ember Warlord. Clear all eight lairs to secure the realm."
@export var reveal_after: int = 2
@export var boss_hp: float = 2200
@export var boss_damage: float = 46
@export var slam_damage: float = 80
@export var slam_radius: float = 3.2
@export var slam_warning: float = 1.8
@export var slam_cooldown: float = 8
@export var enrage_threshold: float = 0.5
@export var enrage_cooldown: float = 5
@export var arrival_delay: float = 30
@export var encounter_reward: int = 250
@export var properties: Dictionary = {}
func data() -> Dictionary:
	var out: Dictionary = properties.duplicate(true)
	out["name"] = name
	out["description"] = description
	out["reveal_after"] = reveal_after
	out["boss_hp"] = boss_hp
	out["boss_damage"] = boss_damage
	out["slam_damage"] = slam_damage
	out["slam_radius"] = slam_radius
	out["slam_warning"] = slam_warning
	out["slam_cooldown"] = slam_cooldown
	out["enrage_threshold"] = enrage_threshold
	out["enrage_cooldown"] = enrage_cooldown
	out["encounter_reward"] = encounter_reward
	out["arrival_delay"] = arrival_delay
	return out
