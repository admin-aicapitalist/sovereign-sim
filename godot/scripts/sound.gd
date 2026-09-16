extends Node
var enabled: bool=false
var sounds: Dictionary={}
var last: Dictionary={}
var ambience_timer: float=0
var chord: int=0
var voices: Array[AudioStreamPlayer]=[]
var music: AudioStreamPlayer
var variation: Dictionary={}
func _ready() -> void:
	for key in ["select","coin","build","hit","bow","fire","flag","level","complete","recruit","spell-lightning","spell-frost","spell-heal","spell-ward","spell-haste","spell-farsight","spell-meteor","meteor-impact","victory","danger","ambience_0","ambience_1","ambience_2","ambience_3"]:
		sounds[key]=load("res://assets/audio/"+key+".wav")
	for key in ["spell-lightning","spell-frost","spell-heal","spell-ward","spell-haste","spell-farsight","spell-meteor","meteor-impact","fire","fire-impact","bow","shield-hit"]:
		sounds[key]=load("res://assets/audio/arcane/"+key+".wav")
	for key in ["combat-metal","combat-body"]:
		for i in 3: sounds[key+"-"+str(i)]=load("res://assets/audio/arcane/"+key+"-"+str(i)+".wav")
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
	if not enabled: return
	var now: float=Time.get_ticks_msec()/1000.0
	if now-last.get(key,-100)<0.09: return
	last[key]=now
	variation[key]=int(variation.get(key,0))+1
	var clip: String=key+"-"+str(int(variation[key])%3) if key in ["combat-metal","combat-body"] else key
	if not sounds.has(clip): return
	var chosen: AudioStreamPlayer=null
	for voice in voices:
		if not voice.playing: chosen=voice; break
	# A major spell can replace a short combat voice, never another spell's tail.
	if chosen==null and (key.begins_with("spell-") or key=="meteor-impact"):
		for voice in voices:
			if voice.get_meta("combat",false): chosen=voice; break
	if chosen==null: return
	var combat: bool=key in ["hit","bow","fire","fire-impact","combat-metal","combat-body","shield-hit"]
	chosen.set_meta("combat",combat); chosen.stream=sounds[clip]; chosen.volume_db=-10 if combat else -4 if key.begins_with("spell-") or key=="meteor-impact" else 0
	chosen.pitch_scale=1+(int(variation[key])%5-2)*0.018 if combat else 1
	chosen.play()
func _process(dt: float) -> void:
	if not enabled: return
	ambience_timer-=dt
	if ambience_timer<=0:
		music.stream=sounds["ambience_"+str(chord%4)]; music.play(); chord+=1; ambience_timer=8
