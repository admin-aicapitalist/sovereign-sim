extends RefCounted
var root_path: String
var error: String=""
var last_export: String=""
var web: bool=false
var native_runs: Dictionary={}
var indexed: bool=false
func _init(path: String="user://run-logs",database: String="sovereign-run-logs-v1") -> void:
	root_path=path; web=OS.has_feature("web")
	if web:
		JavaScriptBridge.eval(FileAccess.get_file_as_string("res://scripts/run_log_web.js"),true)
		JavaScriptBridge.eval("window.sovereignRunLogs.init("+JSON.stringify(database)+")")
	else:
		var code=DirAccess.make_dir_recursive_absolute(root_path)
		if code!=OK: error="Run logging could not create its local folder. Error "+str(code)
func append(batch: Dictionary) -> bool:
	if batch.is_empty(): return true
	if web:
		return bool(JavaScriptBridge.eval("window.sovereignRunLogs.append("+JSON.stringify(JSON.stringify(batch))+ ")"))
	var path=root_path+"/"+batch.run_id+".jsonl"
	var f=FileAccess.open(path,FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if f==null: error="Run log could not be saved: "+str(FileAccess.get_open_error()); return false
	f.seek_end(); f.store_line(JSON.stringify(batch)); f.flush()
	if f.get_error()!=OK: error="Run log write failed: "+str(f.get_error()); return false
	f.close(); error=""
	var meta: Dictionary=batch.duplicate(); meta.erase("events"); meta.updated=int(Time.get_unix_time_from_system()*1000); native_runs[batch.run_id]=meta
	return true
func status() -> Dictionary:
	if web:
		var value=JSON.parse_string(str(JavaScriptBridge.eval("JSON.stringify(window.sovereignRunLogs.status())")))
		return value if value is Dictionary else {"error":"Run log storage is unavailable.","runs":[]}
	if not indexed and DirAccess.dir_exists_absolute(root_path):
		indexed=true
		for file in DirAccess.get_files_at(root_path):
			if not file.ends_with(".jsonl"): continue
			var id=file.trim_suffix(".jsonl")
			if native_runs.has(id): continue
			var f=FileAccess.open(root_path+"/"+file,FileAccess.READ)
			if f==null: continue
			while not f.eof_reached():
				var batch=JSON.parse_string(f.get_line())
				if batch is Dictionary: batch.erase("events"); batch.updated=FileAccess.get_modified_time(root_path+"/"+file)*1000; native_runs[id]=batch
	var runs: Array=native_runs.values(); runs.sort_custom(func(a,b):return a.updated>b.updated)
	return {"error":error,"runs":runs,"pending":0,"last_export":last_export}

func retry() -> void:
	if web: JavaScriptBridge.eval("window.sovereignRunLogs.retry()")
func export_run(id: String,unsaved: Array=[]) -> void:
	if id.length()!=32 or not id.is_valid_hex_number(): error="Invalid run log identifier."; return
	if web: JavaScriptBridge.eval("window.sovereignRunLogs.download("+JSON.stringify(id)+")"); return
	var path=root_path+"/"+id+".jsonl"
	if not FileAccess.file_exists(path) and not unsaved.any(func(b):return b.run_id==id): error="No run log was found."; return
	var records: Array=[]; var metadata: Dictionary={}; var f=FileAccess.open(path,FileAccess.READ) if FileAccess.file_exists(path) else null
	if FileAccess.file_exists(path) and f==null: error="Run log could not be opened."; return
	while f!=null and not f.eof_reached():
		var line=f.get_line()
		if line.is_empty(): continue
		var batch=JSON.parse_string(line)
		if not batch is Dictionary: error="Run log contains an unreadable batch. Original data preserved."; return
		metadata=batch.duplicate(); metadata.erase("events"); records.append_array(batch.events)
	for batch in unsaved:
		if batch.run_id==id: metadata=batch.duplicate(); metadata.erase("events"); records.append_array(batch.events)
	var output=root_path+"/sovereign-run-"+id+".json"; var result=FileAccess.open(output,FileAccess.WRITE)
	if result==null: error="Export could not be written."; return
	result.store_string(JSON.stringify({"format":1,"game":"Sovereign","run":metadata,"events":records})); result.flush()
	if result.get_error()!=OK: error="Export write failed."; return
	last_export=ProjectSettings.globalize_path(output); error=""
