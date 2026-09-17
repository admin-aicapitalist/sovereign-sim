extends RefCounted
## Separate active save and profile. A durable receipt bridges completion writes.
const Rules=preload("res://scripts/settlement_rules.gd")
var profile: Dictionary={}
var error: String=""
var root_path: String
var web_prefix: String
var ready: bool=false
func _init(path: String="user://settlement", prefix: String="sovereign-settlement-v1-") -> void:
	root_path=path; web_prefix=prefix
static func empty_profile() -> Dictionary:
	return {"version":1,"renown":0,"spent":0,"unlocks":{"crown":true},"completed":{},"hints":[],"hints_enabled":true}
func initialize() -> bool:
	error=""; ready=false
	var saved=read_slot("profile",empty_profile())
	if not error.is_empty() or not valid_profile(saved):
		if error.is_empty(): error="The settlement profile is incompatible. Its files have been preserved."
		return false
	profile=saved
	if not recover(): return false
	ready=true; return true
static func valid_record(r: Variant) -> bool:
	if not r is Dictionary or not Rules.valid_config(r.get("config")) or r.get("id")!=r.config.id: return false
	if r.get("outcome") not in ["victory","defeat","abandoned"]: return false
	for key in ["time","gold","lairs","losses","recruits","renown"]:
		if not Rules.number(r.get(key)) or r[key]<0: return false
	if not r.get("monastery") is bool or not r.get("boss") is bool or not r.get("final_attack") is String: return false
	if not r.get("heroes") is Array or r.heroes.size()>3 or not r.get("awards") is Array: return false
	var sum: int=0
	for a in r.awards:
		if not a is Dictionary or not a.get("label") is String or not Rules.number(a.get("amount")) or a.amount<0 or a.amount!=floorf(a.amount): return false
		sum+=int(a.amount)
	if sum!=r.renown or sum>17: return false
	for h in r.heroes:
		if not h is Dictionary or not h.get("name") is String or not h.get("type") is String or not h.get("last") is String or not h.get("dead") is bool or not Rules.number(h.get("level")): return false
	return true
static func valid_profile(p: Variant) -> bool:
	if not p is Dictionary or p.get("version")!=1: return false
	for key in ["renown","spent"]:
		if not Rules.number(p.get(key)) or p[key]<0 or p[key]!=floorf(p[key]): return false
	if not p.get("unlocks") is Dictionary or p.unlocks.get("crown")!=true or not p.get("completed") is Dictionary: return false
	if not p.get("hints") is Array or not p.get("hints_enabled") is bool: return false
	var content=Rules.content()
	for key in p.unlocks:
		if not content.charters.has(key) or p.unlocks[key]!=true: return false
	for hint in p.hints:
		if not content.hints.has(hint): return false
	var earned: int=0
	for id in p.completed:
		var r=p.completed[id]
		if not valid_record(r) or id!=r.id: return false
		earned+=int(r.renown)
	return earned==p.renown+p.spent
func recover() -> bool:
	var receipt=read_slot("receipt",{})
	if not error.is_empty(): return false
	if receipt=={}: return true
	if not valid_record(receipt): error="The pending result is incompatible. Its receipt has been preserved."; return false
	if not profile.completed.has(receipt.id):
		var updated=profile.duplicate(true)
		updated.completed[receipt.id]=receipt; updated.renown+=receipt.renown
		if not write_slot("profile",updated): return false
		profile=updated
	# Retain the last receipt: it also repairs a profile restored from its backup.
	return true
func complete(record: Dictionary) -> bool:
	if not ready: return false
	error=""
	if not recover(): return false
	if profile.completed.has(record.get("id")): return true
	if not valid_record(record): error="The settlement result could not be recorded."; return false
	if not write_slot("receipt",record): return false
	return recover()
func purchase(key: String) -> bool:
	if not ready: return false
	error=""
	if not recover(): return false
	var content=Rules.content()
	if not content.charters.has(key) or profile.unlocks.has(key): return false
	var cost: int=content.charters[key].cost
	if profile.renown<cost: error="Not enough Renown."; return false
	var updated=profile.duplicate(true)
	updated.renown-=cost; updated.spent+=cost; updated.unlocks[key]=true
	if not write_slot("profile",updated): return false
	profile=updated; return true
func set_hint(key: String="", enabled: bool=true) -> bool:
	if not ready: return false
	error=""
	var updated=profile.duplicate(true); updated.hints_enabled=enabled
	if key!="" and Rules.content().hints.has(key) and not updated.hints.has(key): updated.hints.append(key)
	if not write_slot("profile",updated): return false
	profile=updated; return true
func save_active(save: Dictionary) -> bool:
	if not ready: return false
	error=""
	return write_slot("active",save)
func load_active() -> Variant:
	error=""
	return read_slot("active",null)
func has_active() -> bool:
	return exists("active") or exists("active.bak")
func exists(slot: String) -> bool:
	if OS.has_feature("web"):
		return bool(JavaScriptBridge.eval("(function(){try{return localStorage.getItem("+JSON.stringify(web_prefix+slot)+")!==null;}catch(e){return false;}})()"))
	return FileAccess.file_exists(root_path+"-"+slot+".json")
func raw_read(slot: String) -> String:
	if OS.has_feature("web"):
		var result=JavaScriptBridge.eval("(function(){try{return localStorage.getItem("+JSON.stringify(web_prefix+slot)+");}catch(e){return null;}})()")
		return str(result) if result!=null else ""
	return FileAccess.get_file_as_string(root_path+"-"+slot+".json") if exists(slot) else ""
static func decode(text: String) -> Variant:
	if text.is_empty(): return null
	var parser:=JSON.new()
	if parser.parse(text)!=OK: return null
	var wrapper=parser.data
	if not wrapper is Dictionary or wrapper.get("format")!=1 or not wrapper.get("payload") is String or wrapper.get("digest")!=wrapper.payload.sha256_text(): return null
	return parser.data if parser.parse(wrapper.payload)==OK else null
func read_slot(slot: String, fallback: Variant) -> Variant:
	for candidate in [slot,slot+".bak"]:
		if not exists(candidate): continue
		var value=decode(raw_read(candidate))
		if value!=null: return value
	if exists(slot) or exists(slot+".bak"): error="Could not read the saved "+slot+". Its files have been preserved."; return null
	return fallback
func write_slot(slot: String, value: Variant) -> bool:
	var payload=JSON.stringify(value,"",true,true)
	var text=JSON.stringify({"format":1,"payload":payload,"digest":payload.sha256_text()})
	if OS.has_feature("web"):
		var previous=raw_read(slot)
		var backup: bool=decode(previous)!=null
		var script="(function(){try{"
		if backup: script+="localStorage.setItem("+JSON.stringify(web_prefix+slot+".bak")+","+JSON.stringify(previous)+");"
		script+="localStorage.setItem("+JSON.stringify(web_prefix+slot)+","+JSON.stringify(text)+");return true;}catch(e){return false;}})()"
		if bool(JavaScriptBridge.eval(script)): return true
	else:
		var path=root_path+"-"+slot+".json"
		var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
		if file!=null:
			file.store_string(text); file.flush()
			var ok: bool=file.get_error()==OK; file=null
			if ok and exists(slot) and decode(raw_read(slot))!=null:
				ok=DirAccess.copy_absolute(path,root_path+"-"+slot+".bak.json")==OK
			if ok and DirAccess.rename_absolute(path+".tmp",path)==OK: return true
	error="Could not save "+slot+". Free some storage or allow site storage, then retry."
	return false
