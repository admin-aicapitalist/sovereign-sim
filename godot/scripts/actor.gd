extends RefCounted
const FIELDS = ["id","kind","type","hp","max_hp","hostile","hero","home","gold","target","goal","loot_target","state","think","cooldown","repath","path_index","facing","animation","attacking","dead","level","xp","name","bravery","carried","potions","buffs","magic_buffs","mana","max_mana","spell_cooldowns","cast_timer","last_spell","last_hit","raider","infestation","equipment","pending_attack"]
var equipment: Dictionary = {}
var journey: Dictionary = {}
var pending_attack: Dictionary = {}
var id: int = 0
var kind: String = "unit"
var type: String = ""
var pos := Vector2.ZERO
var hp: float = 0
var max_hp: float = 0
var hostile: bool = false
var hero: bool = false
var home: int = 0
var gold: float = 0
var target: int = 0
var goal: int = 0
var loot_target: int = 0
var state: String = "Patrolling"
var think: float = 0
var cooldown: float = 0
var repath: float = 0
var destination := Vector2.ZERO
var path: PackedVector2Array = []
var path_index: int = 0
var facing: float = 1
## Presentation only; old saves remain valid and infer heading from their path.
var heading := Vector2.RIGHT
var animation: float = 0
var attacking: float = 0
var dead: bool = false
var level: int = 1
var xp: float = 0
var name: String = ""
var bravery: float = 1
var carried: float = 0
var potions: Dictionary = {"healing":0,"strength":0,"stoneskin":0}
var buffs: Dictionary = {"strength":0.0,"stoneskin":0.0}
var magic_buffs: Dictionary = {"ward":0.0,"haste":0.0,"frost":0.0}
var mana: float = 0
var max_mana: float = 0
var spell_cooldowns: Dictionary = {}
var cast_timer: float = 0
var last_spell: Dictionary = {}
var last_hit: float = -100
var raider: bool = false
var infestation: bool = false
var definition: Dictionary = {}
func save() -> Dictionary:
	var out: Dictionary = {}
	for key in FIELDS:
		var value = get(key)
		out[key] = value.duplicate(true) if value is Dictionary else value
	out.journey=journey.duplicate(true)
	out.pos = [pos.x,pos.y]
	out.heading = [heading.x,heading.y]
	out.destination = [destination.x,destination.y]
	out.path = []
	for p in path: out.path.append([p.x,p.y])
	return out
