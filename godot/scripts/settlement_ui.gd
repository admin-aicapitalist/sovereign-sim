extends RefCounted
## Run setup and results share the existing royal theme and modal layout.
const Rules=preload("res://scripts/settlement_rules.gd")
const MiniMap=preload("res://scripts/minimap.gd")
static func setup(ui) -> void:
	var main=ui.main; var s=main.sim; var content=Rules.content()
	ui.open_modal("setup")
	ui.modal_text("THE ASHEN MARCH",30)
	ui.modal_column.add_child(ui.button("saved_run_logs","Run logs",func():ui.RunLogUI.show(ui)))
	ui.modal_text("A crown. A kingdom. A little chaos.",20)
	ui.modal_text(content.scenario.description,17)
	ui.modal_text("Replayable province · Autonomous heroes · Protect the Palace",14)
	var preview:=MiniMap.new(); preview.main=main; preview.preview=true; ui.modal_column.add_child(preview)
	preview.custom_minimum_size=Vector2(260,130); preview.size_flags_horizontal=Control.SIZE_SHRINK_CENTER
	ui.modal_text(s.fixture.name+" · Seed "+str(s.fixture.seed),18)
	var seed_row:=HBoxContainer.new(); ui.modal_column.add_child(seed_row)
	var seed_edit:=LineEdit.new(); seed_edit.text=str(s.fixture.seed); seed_edit.placeholder_text="Map seed or name"; seed_edit.size_flags_horizontal=Control.SIZE_EXPAND_FILL; ui.widgets.seed_input=seed_edit; seed_row.add_child(seed_edit)
	seed_row.add_child(ui.button("apply_seed","Use seed",func():main.prepare_settlement(ui.SimulationSeed(seed_edit.text),s.run.config.charter); setup(ui)))
	seed_row.add_child(ui.button("random_map","Reroll",func():main.prepare_settlement(-1,s.run.config.charter); setup(ui)))
	ui.modal_text("PROVINCE CONDITION",12)
	var conditions:=HFlowContainer.new(); ui.modal_column.add_child(conditions)
	for key in content.conditions:
		var b=ui.button("condition_"+key,content.conditions[key].name,func():main.prepare_settlement(s.fixture.seed,s.run.config.charter,key); setup(ui))
		ui.Royal.active(b,s.run.config.condition==key); conditions.add_child(b)
	ui.modal_text(s.run.config.rules.condition.description,16)
	ui.modal_text("ROYAL CHARTER · %d RENOWN"%main.settlements.profile.get("renown",0),12)
	var charters:=HFlowContainer.new(); ui.modal_column.add_child(charters)
	for key in content.charters:
		var unlocked: bool=main.settlements.profile.get("unlocks",{}).has(key)
		var d: Dictionary=content.charters[key]
		var b=ui.button("charter_"+key,d.name if unlocked else "%s · %d Renown"%[d.name,d.cost],func():
			if not main.settlements.ready: return
			if not main.settlements.profile.unlocks.has(key):
				if not main.settlements.purchase(key): main.storage_message=main.settlements.error; setup(ui); return
			main.prepare_settlement(s.fixture.seed,key,s.run.config.condition); setup(ui))
		b.disabled=not unlocked and main.settlements.profile.get("renown",0)<d.cost
		b.tooltip_text=d.description; ui.Royal.active(b,s.run.config.charter==key); charters.add_child(b)
	ui.modal_text(s.run.config.rules.charter.description,16)
	if not main.settlements.profile.get("unlocks",{}).has("guild_compact"): ui.modal_text("Unlock Guild Compact for 10 Renown: cheaper guild construction, lower recurring taxes.",15)
	ui.modal_text("Starting gold: 1,500 · Guilds: Warrior %dg / Ranger %dg / Wizard %dg / Thief %dg\nPeriodic tax per 10s: Palace %.1fg / cottage %.1fg / Marketplace %.1fg"%[s.definitions.buildings.warriors.cost,s.definitions.buildings.rangers.cost,s.definitions.buildings.wizards.cost,s.definitions.buildings.thieves.cost,s.definitions.buildings.palace.tax,s.definitions.buildings.house.tax,s.definitions.buildings.marketplace.tax],15)
	var begin=ui.button("start","Found this settlement",func():
		if not main.begin_settlement() and ui.modal_kind!="replace_saved": setup(ui))
	ui.Royal.primary(begin); begin.custom_minimum_size.y=46; ui.modal_footer.visible=true
	var selection=ui.label(s.run.config.rules.charter.name+" · "+s.run.config.rules.condition.name,14); selection.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ui.modal_footer.add_child(selection)
	ui.modal_footer.add_child(begin)
	var pause_tip=ui.label("Starts immediately · Space pauses",14); pause_tip.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; ui.modal_footer.add_child(pause_tip)
	if main.settlements.has_active(): ui.modal_column.add_child(ui.button("load_welcome","Resume saved settlement",func():main.load_game(); if_failed(ui)))
	ui.modal_column.add_child(ui.button("legacy","Standalone chronicles / older saves",func():main.settlement_mode=false; main.mission_id="ember_crown"; main.new_game(s.fixture.seed); ui.show_welcome()))
	if main.storage_message!="": ui.modal_text(main.storage_message,16)
	if not main.settlements.ready:
		ui.modal_text(main.settlements.error,16)
		ui.modal_column.add_child(ui.button("retry_profile","Retry profile storage",func():main.settlements.initialize(); setup(ui)))
	ui.layout(true)
static func if_failed(ui) -> void:
	if ui.main.storage_message!="": ui.modal_text(ui.main.storage_message,16)
static func replace_saved(ui) -> void:
	ui.open_modal("replace_saved"); ui.modal_text("A settlement is already in progress",28)
	ui.modal_text("Resume it, or abandon it to found the province you selected. Abandonment records only completed accomplishments before replacing the active save.")
	ui.modal_column.add_child(ui.button("resume_existing","Resume saved settlement",func():ui.main.load_game(); if_failed(ui)))
	ui.modal_column.add_child(ui.button("replace_existing","Abandon saved settlement and found this one",func():
		if not ui.main.begin_settlement(true): ui.modal_text(ui.main.storage_message)))
	ui.modal_column.add_child(ui.button("cancel_replace","Back to province setup",func():setup(ui)))
static func menu(ui) -> void:
	if ui.main.sim.run.is_empty(): ui.main.new_game(); ui.show_welcome(); return
	ui.open_modal("run_menu"); ui.modal_text("Your settlement",30)
	ui.modal_text("Save and leave to continue this reign later. Abandoning ends it and records the accomplishments already earned.")
	ui.modal_column.add_child(ui.button("resume","Return to the kingdom",func():ui.close_modal(); ui.refresh()))
	ui.modal_column.add_child(ui.button("save_leave","Save and leave",func():ui.main.save_and_leave(); if_failed(ui)))
	ui.modal_column.add_child(ui.button("abandon","Abandon this settlement",func():ui.main.abandon_settlement()))
static func title(ui) -> void:
	ui.open_modal("title"); ui.modal_text("SOVEREIGN",38)
	ui.modal_text("A crown. A kingdom. A little chaos.",22)
	ui.modal_text("Renown: %d · Recorded settlements: %d"%[ui.main.settlements.profile.get("renown",0),ui.main.settlements.profile.get("completed",{}).size()])
	ui.modal_column.add_child(ui.button("saved_run_logs","Run logs",func():ui.RunLogUI.show(ui)))
	if ui.main.settlements.has_active(): ui.modal_column.add_child(ui.button("load_welcome","Resume saved settlement",func():ui.main.load_game(); if_failed(ui)))
	ui.modal_column.add_child(ui.button("fresh","Choose a new province",func():ui.main.prepare_settlement(); setup(ui)))
static func result(ui) -> void:
	var main=ui.main; var s=main.sim
	ui.open_modal("end")
	var r: Dictionary=main.settlements.profile.get("completed",{}).get(s.run.config.id,Rules.record(s))
	ui.modal_text("The march is yours." if r.outcome=="victory" else "A kingdom remembered." if r.outcome=="defeat" else "A reign relinquished.",30)
	var defeat_text="The Palace fell." if r.final_attack=="" or r.final_attack=="The Palace was destroyed" else "The Palace fell. Final attack: "+r.final_attack+"."
	ui.modal_text("The Ember Warlord is defeated and the Palace stands." if r.outcome=="victory" else defeat_text if r.outcome=="defeat" else "You abandoned this settlement. Completed accomplishments still count.",18)
	ui.modal_text("%d:%02d · %d lairs cleared · %d recruits · %d losses (people and buildings)\nMonastery: %s · Warlord: %s · Treasury: %dg\n%s · Seed %d"%[int(r.time/60),int(r.time)%60,r.lairs,r.recruits,r.losses,"recovered" if r.monastery else "unrecovered","defeated" if r.boss else "undefeated",r.gold,r.config.rules.scenario.name,r.config.seed],16)
	ui.modal_text(r.config.rules.charter.name+" · "+r.config.rules.condition.name,15)
	ui.modal_text("RENOWN · +%d"%r.renown,23)
	ui.modal_column.add_child(ui.button("saved_run_logs","Run logs",func():ui.RunLogUI.show(ui)))
	for a in r.awards: ui.modal_text("+%d  %s"%[a.amount,a.label],16)
	if r.awards.is_empty(): ui.modal_text("No accomplishments completed. Starting or waiting alone earns no Renown.",16)
	ui.modal_text("Balance: %d Renown"%main.settlements.profile.get("renown",0),18)
	if not r.heroes.is_empty(): ui.modal_text("HEROES OF THIS REIGN",12)
	for h in r.heroes: ui.modal_text("%s · %s · Level %d%s\n%s"%[h.name,h.type.capitalize(),h.level," · Fallen" if h.dead else "",h.last],16)
	if not main.completion_saved:
		ui.modal_text("Progress has not been saved. "+main.storage_message,17)
		ui.modal_column.add_child(ui.button("retry_result","Retry saving this result",func():main.finish_settlement(true); result(ui)))
	else:
		ui.modal_text("Renown added to your profile." if r.renown>0 else "Result saved to your profile.",14)
		if main.storage_message!="": ui.modal_text(main.storage_message+" Your Renown and result are saved.",15)
		if not main.settlements.profile.unlocks.has("guild_compact"):
			ui.modal_text("Guild Compact: guild construction −15%, periodic taxes −10%.",16)
			var buy=ui.button("unlock_compact","Unlock Guild Compact · 10 Renown",func():
				main.settlements.purchase("guild_compact"); main.storage_message=main.settlements.error; result(ui))
			buy.disabled=main.settlements.profile.renown<10; ui.modal_column.add_child(buy)
		var fresh=ui.button("fresh","Found another settlement",func():main.prepare_settlement(); setup(ui))
		ui.Royal.primary(fresh); ui.modal_footer.visible=true; ui.modal_footer.add_child(fresh)
		ui.modal_column.add_child(ui.button("replay","Replay these conditions",func():main.prepare_settlement(int(r.config.seed),r.config.charter,r.config.condition); setup(ui)))
		ui.modal_column.add_child(ui.button("title","Return to title",func():main.started=false; title(ui)))
	ui.layout(true)
