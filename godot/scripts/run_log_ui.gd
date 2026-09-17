extends RefCounted
static func show(ui) -> void:
	ui.main.flush_run_log()
	var previous: String=ui.modal_kind
	ui.open_modal("run_logs"); ui.modal_text("RUN LOGS",30)
	ui.modal_text("Recorded automatically on this device. Export a run to share its timeline for review. Earlier playthroughs without logging cannot be recovered.",16)
	var status=ui.label("",16); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ui.modal_column.add_child(status); ui.widgets.run_log_status=status
	var rows:=VBoxContainer.new(); ui.modal_column.add_child(rows); ui.widgets.run_log_rows=rows
	rows.set_meta("signature","")
	ui.modal_footer.visible=true
	ui.modal_footer.add_child(ui.button("retry_run_logs","Retry saving logs",func():ui.main.retry_run_logs()))
	ui.modal_footer.add_child(ui.button("close_run_logs","Back",func():
		ui.close_modal()
		match previous:
			"setup": ui.SettlementUI.setup(ui)
			"title": ui.show_title()
			"end": ui.show_end()
			"welcome": ui.show_welcome()
		ui.refresh()))
	refresh(ui); ui.layout(true)
static func refresh(ui) -> void:
	var main=ui.main; var status: Dictionary=main.log_status
	var message: String=status.get("error","")
	if message=="": message="Saved locally." if status.get("pending",0)==0 else "Saving %d events…"%status.pending
	if status.get("last_export","")!="": message+="\nExported: "+status.last_export
	ui.widgets.run_log_status.text=message
	var runs: Array=status.get("runs",[]).duplicate(true)
	var id: String=main.sim.run_log.run_id
	if id!="" and not runs.any(func(r):return r.run_id==id): runs.push_front({"run_id":id,"seed":main.sim.fixture.seed,"outcome":main.sim.result})
	for batch in main.unwritten_batches:
		if not runs.any(func(r):return r.run_id==batch.run_id): runs.append({"run_id":batch.run_id,"seed":batch.seed,"outcome":batch.outcome})
	var signature: String=JSON.stringify(runs.map(func(r):return [r.run_id,r.get("outcome","")]))
	var rows=ui.widgets.run_log_rows
	if rows.get_meta("signature")==signature: return
	rows.set_meta("signature",signature); ui.clear(rows)
	if runs.is_empty(): rows.add_child(ui.label("Your next run will appear here.",16))
	for r in runs:
		var description: String="Seed %s · %s · %s"%[str(int(r.seed)),r.get("outcome","").capitalize() if r.get("outcome","")!="" else "In progress",r.run_id.left(8)]
		if r.has("updated"): description+="\n"+Time.get_datetime_string_from_unix_time(int(r.updated/1000)).replace("T"," ")+" UTC"
		var caption=ui.label(description,16); caption.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; rows.add_child(caption)
		rows.add_child(ui.button("export_log_"+r.run_id,"Export run log"+(" · Current" if r.run_id==id else ""),func():main.export_run_log(r.run_id)))
