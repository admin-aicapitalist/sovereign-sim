extends RefCounted
## Mulberry32 and UTF-16 FNV-1a, matching the browser's named/numeric seeds.
var state: int = 0
func _init(seed_value: int = 0) -> void:
	state = seed_value & 0xffffffff
func next() -> float:
	state = (state + 0x6d2b79f5) & 0xffffffff
	var t: int = ((state ^ (state >> 15)) * (1 | state)) & 0xffffffff
	t = ((t + (((t ^ (t >> 7)) * (61 | t)) & 0xffffffff)) ^ t) & 0xffffffff
	return float((t ^ (t >> 14)) & 0xffffffff) / 4294967296.0
func between(a: float, b: float) -> float:
	return a + (b-a)*next()
func integer(a: int, b: int) -> int:
	return a + int(next()*(b-a+1))
static func normalize(value: Variant) -> int:
	var text: String = str(value).strip_edges()
	if text.is_valid_int() and not text.begins_with("-") and not text.begins_with("+") and int(text) <= 0xffffffff:
		return int(text)
	var hash: int = 2166136261
	for i in text.length():
		var ch: int = text.unicode_at(i)
		if ch > 0xffff:
			ch -= 0x10000
			hash = ((hash ^ (0xd800 + (ch >> 10)))*16777619) & 0xffffffff
			ch = 0xdc00 + (ch & 1023)
		hash = ((hash ^ ch)*16777619) & 0xffffffff
	return hash
