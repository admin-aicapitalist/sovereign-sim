extends Node
var enabled: bool=false
var sounds: Dictionary={}
var last: Dictionary={}
var ambience_timer: float=0
var chord: int=0
var voices: Array[AudioStreamPlayer]=[]
var music: AudioStreamPlayer
func _ready() -> void:
	for key in ["select","coin","build","hit","bow","fire","flag","level","complete","recruit","spell-lightning","spell-frost","spell-heal","spell-ward","spell-haste","spell-farsight","spell-meteor","meteor-impact","victory","danger","ambience_0","ambience_1","ambience_2","ambience_3"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	for i in 12:
		var voice:=AudioStreamPlayer.new(); add_child(voice); voices.append(voice)
	music=AudioStreamPlayer.new(); add_child(music)
func enable() -> void:
	if not enabled: enabled=true; ambience_timer=0; play("select")
func toggle() -> void:
	if not enabled: enable()
	else:
		enabled=false; music.stop()
		for voice in voices: voice.stop()
func play(key: String) -> void:
	if not enabled or not sounds.has(key): return
	var now: float=Time.get_ticks_msec()/1000.0
	if now-last.get(key,-100)<0.09: return
	last[key]=now
	for voice in voices:
		if not voice.playing: voice.stream=sounds[key]; voice.volume_db=-8 if key in ["hit","bow","fire"] else 0; voice.play(); return
func _process(dt: float) -> void:
	if not enabled: return
	ambience_timer-=dt
	if ambience_timer<=0:
		music.stream=sounds["ambience_"+str(chord%4)]; music.play(); chord+=1; ambience_timer=8
