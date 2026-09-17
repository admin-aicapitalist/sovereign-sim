extends RefCounted
const Journey=preload("res://scripts/journey.gd")
const FILTERS={"all":"All heroes","help":"Needs support","quest":"On a quest","recovery":"Recovering","mastery":"Mastery","fallen":"Fallen"}
static func open(ui) -> void:
	ui.open_modal("journeys"); ui.journey_rows={}; ui.journey_signature=""
	ui.modal_header.visible=true
	ui.HeroUI.text(ui,ui.modal_header,"HERO JOURNEYS",28)
	ui.journey_summary=ui.HeroUI.text(ui,ui.modal_header,"",15)
	var filters:=HFlowContainer.new(); ui.modal_header.add_child(filters)
	for key in FILTERS:
		filters.add_child(ui.button("journey_filter_"+key,FILTERS[key],func():ui.journey_filter=key; refresh(ui)))
	ui.modal_footer.visible=true
	var footer:=HFlowContainer.new(); ui.modal_footer.add_child(footer)
	footer.add_child(ui.button("journey_pause","Pause kingdom",func():ui.main.sim.paused=not ui.main.sim.paused; refresh(ui)))
	footer.add_child(ui.button("heroes_close","Return to kingdom",func():ui.close_modal(); ui.refresh()))
	refresh(ui); ui.layout(true)
static func location(s,u) -> String:
	var places: Array=s.buildings.filter(func(b):return not b.dead and (not b.hostile or s.is_explored(s.pos(b))))
	var nearest=s.nearest(u.pos,places)
	return ("Near " if u.pos.distance_to(s.pos(nearest))<8 else "Outside ")+nearest.site_name if nearest!=null else "On the frontier"
static func act(ui,id: int) -> void:
	var s=ui.main.sim; var hero=s.entity(id)
	if hero==null or hero.dead: return
	var info=Journey.describe(s,hero)
	match info.action:
		"raise":
			var f=Journey.active_flag(s,hero)
			if f!=null: s.raise_bounty(f.id)
			refresh(ui)
		"call":
			var f=Journey.active_flag(s,hero)
			if f!=null: ui.HeroUI.focus(ui,f.id)
		"home": ui.HeroUI.focus(ui,Journey.home(s,hero).id)
		"temple": ui.HeroUI.build_service(ui,"temple")
		"attack","explore": ui.HeroUI.choose_bounty(ui,info.action)
		_: ui.HeroUI.journal(ui,id)
static func refresh(ui) -> void:
	if ui.modal_kind!="journeys": return
	var s=ui.main.sim; var heroes: Array=s.units.filter(func(u):return u.hero and not u.dead)
	var counts={"help":0,"quest":0,"recovery":0,"mastery":0}
	for hero in heroes:
		var category: String=Journey.describe(s,hero).category
		if counts.has(category): counts[category]+=1
	var fallen: Array=s.run.get("heroes",{}).values().filter(func(h):return h.dead)
	ui.journey_summary.text="%d heroes · %d need support · %d on a quest · %d recovering · %d at mastery%s"%[heroes.size(),counts.help,counts.quest,counts.recovery,counts.mastery," · PAUSED" if s.paused else " · LIVE"]
	ui.widgets.journey_pause.text="Resume kingdom" if s.paused else "Pause kingdom"
	for key in FILTERS: ui.Royal.active(ui.widgets["journey_filter_"+key],ui.journey_filter==key)
	var visible: Array=heroes.filter(func(u):return ui.journey_filter=="all" or Journey.describe(s,u).category==ui.journey_filter)
	visible.sort_custom(func(a,b):
		var rank={"shadow":0,"refusal":1,"call":2,"ordinary":3,"ordeal":4,"tests":5,"threshold":6,"return":7,"mastery":8}
		var ar: int=rank.get(a.journey.get("stage",""),9); var br: int=rank.get(b.journey.get("stage",""),9)
		return a.id<b.id if ar==br else ar<br)
	var small: bool=ui.main.get_viewport_rect().size.x<760
	var signature: String=str(visible.map(func(u):return u.id))+str(small)+ui.journey_filter+str(fallen.size())+str(heroes.size())
	if signature!=ui.journey_signature:
		var scroll: int=ui.modal_scroll.scroll_vertical
		ui.clear(ui.modal_column); ui.journey_rows={}; ui.journey_signature=signature
		if heroes.is_empty() and ui.journey_filter!="fallen":
			ui.modal_text("No heroes recruited yet",22); ui.modal_text("Build a guild and recruit heroes. Their calls, hesitation, ordeals and recovery will appear here together.",17)
			ui.modal_column.add_child(ui.button("hero_build_guild","Build a Warriors’ Guild",func():ui.HeroUI.build_service(ui,"warriors")))
		elif visible.is_empty() and ui.journey_filter!="fallen": ui.modal_text("No heroes in this group.",18)
		for hero in visible: make_row(ui,hero,small)
		if ui.journey_filter=="fallen":
			if fallen.is_empty(): ui.modal_text("No fallen heroes in this reign.",18)
			for hero in fallen:
				var journey: Dictionary=hero.get("journey",{})
				ui.modal_text(hero.name+" · "+hero.type.capitalize(),22)
				ui.modal_text("Fell during "+Journey.STAGES.get(journey.get("stage",""),"an earlier unrecorded journey")+" · %d journeys completed"%journey.get("cycles",0),17)
				ui.modal_text(hero.last,16)
		ui.modal_scroll.set_deferred("scroll_vertical",scroll)
	for hero in visible:
		var row: Dictionary=ui.journey_rows[hero.id]; var info=Journey.describe(s,hero)
		row.identity.text=hero.name+"\n"+hero.definition.name+" · "+Journey.ARCHETYPES.get(hero.type,"")+"\nLevel %d · HP %d/%d"%[hero.level,hero.hp,hero.max_hp]
		row.stage.text=info.stage+"\n"+("Recovery branch" if info.key=="shadow" else "Stage %d / 8"%(info.step+1) if info.step>=0 else "Standalone chronicle")+" · %d completed"%info.cycles
		row.stage.add_theme_color_override("font_color",Color("883f2e") if info.key in ["shadow","refusal"] else Color("453525"))
		row.goal.text=location(s,hero)+"\n"+info.objective+"\nNow: "+hero.state
		if small:
			row.identity.text=hero.name+" · "+hero.definition.name+"\nHP %d/%d · %s"%[hero.hp,hero.max_hp,hero.state]
			row.stage.text=info.stage+" · %d journeys completed"%info.cycles
			row.goal.text=location(s,hero)+" · "+info.objective
		row.next.text=info.next
		row.action.text={"raise":"Raise bounty · 50g","call":"View calling bounty","home":"View home","temple":"Build a Temple","attack":"Post attack bounty","explore":"Post explore bounty","journal":"Journal"}[info.action]
		row.action.disabled=s.result!="" or info.action=="raise" and (s.gold<50 or Journey.active_flag(s,hero)==null)
static func make_row(ui,hero,small: bool) -> void:
	var panel=ui.panel(ui.modal_column)
	var across: BoxContainer=VBoxContainer.new() if small else HBoxContainer.new(); across.add_theme_constant_override("separation",6 if small else 14); panel.add_child(across)
	var row: Dictionary={}
	for entry in [["identity","HERO",0.95],["stage","JOURNEY",0.85],["goal","WHERE / CURRENT CALL",1.15],["next","WHAT HELPS NEXT",1.45]]:
		var col:=VBoxContainer.new(); col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; col.size_flags_stretch_ratio=entry[2]; across.add_child(col)
		if not small: ui.HeroUI.text(ui,col,entry[1],11)
		row[entry[0]]=ui.HeroUI.text(ui,col,"",16 if small and entry[0] in ["stage","identity"] else 14 if small else 18 if entry[0]=="stage" else 16)
		if entry[0]=="next":
			row.action=ui.button("journey_action_"+str(hero.id),"",func():act(ui,hero.id)); row.action.add_theme_font_size_override("font_size",14); col.add_child(row.action)
		if entry[0]=="identity":
			var buttons:=HFlowContainer.new(); col.add_child(buttons)
			buttons.add_child(ui.button("journey_find_"+str(hero.id),"Find",func():ui.HeroUI.focus(ui,hero.id)))
			buttons.add_child(ui.button("hero_"+str(hero.id),"Journal",func():ui.HeroUI.journal(ui,hero.id)))
	ui.journey_rows[hero.id]=row
