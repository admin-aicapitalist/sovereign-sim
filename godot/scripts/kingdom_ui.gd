extends CanvasLayer
const Magic=preload("res://scripts/magic.gd")
const Supplies=preload("res://scripts/supplies.gd")
const Sanitation=preload("res://scripts/sanitation.gd")
const MiniMap=preload("res://scripts/minimap.gd")
const Royal=preload("res://scripts/royal_theme.gd")
const RoyalCard=preload("res://scripts/royal_card.gd")
const RoyalOverlay=preload("res://scripts/royal_overlay.gd")
const SettlementUI=preload("res://scripts/settlement_ui.gd")
const HeroUI=preload("res://scripts/hero_ui.gd")
const RunLogUI=preload("res://scripts/run_log_ui.gd")
const JourneyUI=preload("res://scripts/journey_ui.gd")
var journey_rows: Dictionary={}
var journey_signature: String=""
var journey_filter: String="all"
var journey_summary: Label
var hint_panel: PanelContainer
var hint_label: Label
var hint_key: String=""
var main
var refresh_ms: float=0
var root: Control
var top: PanelContainer
var deck: PanelContainer
var campaign: PanelContainer
var inspector: PanelContainer
var map_panel: PanelContainer
var minimap
var treasury: Label
var status: Label
var notice: Label
var chapter: Label
var encounter_button: Button
var quest: Label
var portrait: TextureRect
var details: Label
var actions: VBoxContainer
var cards: HBoxContainer
var tab: String="build"
var widgets: Dictionary={}
var modal: Control
var modal_panel: PanelContainer
var modal_column: VBoxContainer
var modal_footer: VBoxContainer
var modal_header: VBoxContainer
var modal_scroll: ScrollContainer
var modal_kind: String=""
var was_paused: bool=false
var compact: bool=false
var objectives_open: bool=false
var map_open: bool=true
var last_size:=Vector2.ZERO
var last_selection: int=-1
var card_signature: String=""
var last_result: String=""
var objective_list: VBoxContainer
var inspector_scroll: ScrollContainer
var title: Label
var controls: HFlowContainer
var tip: int=0
var action_signature: String=""
var card_tab: String=""
var objective_ids: Array=[]
var hero_count: Label
var day_count: Label
var campaign_progress: ProgressBar
var menu_overlay: Control
var menu_title: Label
var menu_tagline: Label
var menu_caption: Label

func _ready() -> void:
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	root.theme=Royal.make()
	top=panel(root,"28271f"); var top_col:=VBoxContainer.new(); top.add_child(top_col)
	var line:=HBoxContainer.new(); line.add_theme_constant_override("separation",16); top_col.add_child(line)
	var crest:=TextureRect.new(); crest.texture=Royal.icon("crest"); crest.custom_minimum_size=Vector2(34,36); crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; line.add_child(crest)
	title=label("SOVEREIGN",23,"ecd4a0"); title.add_theme_font_override("font",Royal.DISPLAY); title.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(title)
	treasury=resource_label(line,"coin","ROYAL TREASURY"); hero_count=resource_label(line,"heroes","HEROES"); day_count=resource_label(line,"sun","THE REIGN")
	line.add_child(button("pause","Pause",func():main.sim.paused=not main.sim.paused; refresh()))
	controls=HFlowContainer.new(); controls.add_theme_constant_override("h_separation",7); top_col.add_child(controls)
	for n in [1,2,3]: controls.add_child(button("speed_"+str(n),str(n)+"×",func():main.speed=n; main.sim.paused=false; refresh()))
	controls.add_child(button("heroes","Hero Journeys",func():HeroUI.roster(self)))
	controls.add_child(button("sound","Sound",func():main.sound.toggle(); refresh()))
	controls.add_child(button("save","Save",main.save_game)); controls.add_child(button("load","Load",func():main.load_game(main.sim.run.is_empty())))
	controls.add_child(button("run_logs","Run logs",func():RunLogUI.show(self))); controls.add_child(button("help","Help",show_help)); controls.add_child(button("new","Reign",show_run_menu))
	controls.add_child(button("objectives","Objectives",func():objectives_open=not objectives_open; layout(true)))
	controls.add_child(button("map","Map",func():map_open=not map_open; layout(true)))
	controls.add_child(button("center","Palace",main.center)); controls.add_child(button("zoom_out","−",func():main.change_zoom(0.86))); controls.add_child(button("zoom_in","+",func():main.change_zoom(1.16)))
	campaign=panel(root); var campaign_scroll:=ScrollContainer.new(); campaign_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; campaign.add_child(campaign_scroll); var campaign_col:=VBoxContainer.new(); campaign_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; campaign_scroll.add_child(campaign_col)
	campaign_col.add_child(label("THE ROYAL CHRONICLE",11,"866640")); chapter=label("The Young Kingdom",20); chapter.add_theme_font_override("font",Royal.DISPLAY); chapter.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; campaign_col.add_child(chapter)
	campaign_progress=ProgressBar.new(); campaign_progress.custom_minimum_size.y=5; campaign_progress.show_percentage=false; campaign_progress.max_value=8
	var track:=StyleBoxFlat.new(); track.bg_color=Color("b5a27a"); var fill:=StyleBoxFlat.new(); fill.bg_color=Color("875039"); campaign_progress.add_theme_stylebox_override("background",track); campaign_progress.add_theme_stylebox_override("fill",fill); campaign_col.add_child(campaign_progress)
	quest=label("",16); quest.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; campaign_col.add_child(quest)
	encounter_button=button("encounter","Locate encounter",func():
		var m: Dictionary=main.sim.mission; var e=main.sim.entity(m.boss_id if m.boss_id and not m.boss_defeated else m.encounter_id)
		if e!=null: main.center_on(main.sim.pos(e)); main.world.selected=e.id; objectives_open=false; refresh())
	campaign_col.add_child(encounter_button)
	objective_list=VBoxContainer.new(); campaign_col.add_child(objective_list)
	inspector=panel(root); inspector_scroll=ScrollContainer.new(); inspector_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; inspector.add_child(inspector_scroll)
	var inspect_col:=VBoxContainer.new(); inspect_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; inspector_scroll.add_child(inspect_col)
	var heading:=HBoxContainer.new(); inspect_col.add_child(heading)
	var caption=label("ROYAL LEDGER",12,"866640"); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(caption)
	heading.add_child(button("close_selection","×",func():main.world.selected=0; refresh()))
	portrait=TextureRect.new(); portrait.custom_minimum_size=Vector2(0,95); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; inspect_col.add_child(portrait)
	details=label("",18); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; inspect_col.add_child(details)
	actions=VBoxContainer.new(); inspect_col.add_child(actions); inspect_col.move_child(actions,2)
	map_panel=panel(root,"28271f"); var map_col:=VBoxContainer.new(); map_panel.add_child(map_col)
	map_col.add_child(label("THE BORDERLANDS",11,"c9ad73")); minimap=MiniMap.new(); minimap.main=main; map_col.add_child(minimap)
	deck=panel(root,"28271f"); var deck_col:=VBoxContainer.new(); deck_col.add_theme_constant_override("separation",8); deck.add_child(deck_col)
	var tabs:=HBoxContainer.new(); deck_col.add_child(tabs)
	for entry in [["build","Build"],["recruit","Heroes"],["bounty","Bounties"],["spells","Magic"]]:
		var b=button("tab_"+entry[0],entry[1],func():tab=entry[0]; main.set_mode("",""); update_cards(true))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; b.icon=Royal.icon("heroes" if entry[0]=="recruit" else "attack" if entry[0]=="bounty" else entry[0]); b.expand_icon=true; b.add_theme_constant_override("icon_max_width",18); b.add_theme_font_override("font",Royal.DISPLAY); b.add_theme_font_size_override("font_size",13); tabs.add_child(b)
	var scroll:=ScrollContainer.new(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.custom_minimum_size.y=110; deck_col.add_child(scroll)
	cards=HBoxContainer.new(); cards.add_theme_constant_override("separation",7); scroll.add_child(cards)
	status=label("",14,"c4b799"); status.text_overrun_behavior=TextServer.OVERRUN_TRIM_ELLIPSIS; deck_col.add_child(status)
	notice=label("",17,"f4e7c6"); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(notice)
	hint_panel=panel(root); var hint_col:=VBoxContainer.new(); hint_panel.add_child(hint_col)
	hint_label=label("",16); hint_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; hint_col.add_child(hint_label)
	var hint_actions:=HBoxContainer.new(); hint_col.add_child(hint_actions)
	hint_actions.add_child(button("dismiss_hint","Got it",func():dismiss_hint(true)))
	hint_actions.add_child(button("disable_hints","Turn hints off",func():dismiss_hint(false)))
	hint_panel.visible=false
	layout(true); refresh()
func label(text: String,font_size: int=18,color: String="453525") -> Label:
	var out:=Label.new(); out.text=text; out.add_theme_font_size_override("font_size",font_size); out.add_theme_color_override("font_color",Color(color))
	if font_size<=13 or font_size>=24: out.add_theme_font_override("font",Royal.DISPLAY)
	return out
func resource_label(parent: Node,key: String,caption: String) -> Label:
	var row:=HBoxContainer.new(); row.add_theme_constant_override("separation",8); parent.add_child(row)
	var icon:=TextureRect.new(); icon.texture=Royal.icon(key); icon.custom_minimum_size=Vector2(25,28); icon.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; icon.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; row.add_child(icon)
	var col:=VBoxContainer.new(); col.add_theme_constant_override("separation",-3); row.add_child(col)
	var value:=label("",21,"efdaad"); col.add_child(value); col.add_child(label(caption,9,"b9a785")); return value
func panel(parent: Node,color: String="e5d3af") -> PanelContainer:
	var p:=PanelContainer.new(); p.add_theme_stylebox_override("panel",Royal.box("timber" if color=="28271f" else "parchment",12)); parent.add_child(p); return p
func button(key: String,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size.y=30; b.add_theme_font_size_override("font_size",16); b.focus_mode=Control.FOCUS_NONE; b.mouse_filter=Control.MOUSE_FILTER_PASS; b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND; b.pressed.connect(func():main.record_action(key,text); callback.call(); main.flush_run_log())
	if key!="": widgets[key]=b
	return b
func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()
func layout(force: bool=false) -> void:
	var s: Vector2=main.get_viewport_rect().size
	if s==last_size and not force: return
	last_size=s; compact=s.x<900
	title.visible=s.x>=760; treasury.add_theme_font_size_override("font_size",17 if compact else 21)
	hero_count.add_theme_font_size_override("font_size",17 if compact else 21); day_count.add_theme_font_size_override("font_size",17 if compact else 21)
	for value in [treasury,hero_count,day_count]: value.get_parent().get_child(1).visible=not compact
	top.position=Vector2.ZERO; top.size=Vector2(s.x,0)
	var top_height: float=top.get_combined_minimum_size().y
	deck.position=Vector2(10,s.y-207); deck.size=Vector2(s.x-20 if compact or not map_open else s.x-272,197)
	status.custom_minimum_size.y=18
	campaign.visible=not compact or objectives_open
	objective_list.visible=objectives_open
	campaign.position=Vector2(12,top_height+12); campaign.size=Vector2(minf(250,s.x-24),maxf(120,minf(530 if objectives_open else 270 if encounter_button.visible else 204,s.y-top_height-240)))
	inspector.position=Vector2(s.x-288,top_height+8) if not compact else Vector2(12,top_height+8)
	inspector.size=Vector2(276 if not compact else minf(345,s.x-24),maxf(120,minf(510,s.y-top_height-240)))
	map_panel.visible=map_open and (not compact or not inspector.visible and not campaign.visible)
	map_panel.position=Vector2(s.x-252,s.y-207) if not compact else Vector2(s.x-162,top_height+8)
	minimap.custom_minimum_size=Vector2(218,145) if not compact else Vector2(126,84)
	map_panel.size=Vector2(242,197) if not compact else Vector2(150,0)
	notice.position=Vector2(300 if not compact else 18,top_height+12)
	notice.size=Vector2(maxf(100,s.x-610) if not compact else s.x-36,90)
	if hint_panel!=null:
		hint_panel.size=Vector2(minf(520,s.x-36),0)
		hint_panel.position=Vector2((s.x-hint_panel.size.x)/2,deck.position.y-hint_panel.get_combined_minimum_size().y-10)
	if modal!=null: layout_modal()
	for p in [top,deck,campaign,inspector,map_panel]:
		if modal_kind=="welcome": p.visible=false
func update_cards(force: bool=false) -> void:
	var s=main.sim
	var signature: String=tab+str(int(s.gold))+str(s.magic.unlocked)+str(s.alchemy.unlocked)+str(int(s.time))+str(main.world.mode_kind)+main.world.mode_key
	if not force and signature==card_signature: return
	card_signature=signature
	if card_tab!=tab: clear(cards); card_tab=tab
	for key in ["build","recruit","bounty","spells"]: Royal.active(widgets["tab_"+key],key==tab)
	var keys: Array=["warriors","rangers","wizards","marketplace","temple","tower","house","thieves","inn","brothel"] if tab=="build" else ["warrior","ranger","wizard","thief"] if tab=="recruit" else ["attack","explore"] if tab=="bounty" else s.definitions.spells.keys()
	for key in keys:
		var text: String=""; var tooltip: String=""; var icon: Texture2D=null; var disabled: bool=false
		if tab=="build":
			var d=s.definitions.buildings[key]; text="%s\n%d gold"%[d.get("short",d.name),d.cost]; tooltip=d.description; icon=main.world.textures[key]
		elif tab=="recruit":
			var d=s.definitions.units[key]; var guilds=s.operating("").filter(func(b):return s.definition_of(b).get("recruits","")==key)
			text="%s\n%d gold"%[d.name,d.cost]; tooltip="Autonomous hero. Includes 24 gold for supplies."; disabled=guilds.is_empty()
			icon=main.world.portraits["unit_"+key]
		elif tab=="bounty": text=("Attack bounty" if key=="attack" else "Explore bounty")+"\n100 gold"; tooltip="Heroes choose bounties by reward and danger. Select flags to raise or withdraw them."; icon=Royal.icon(key+"-seal")
		else:
			var d=s.definitions.spells[key]; text=d.name+"\n"+("Learn at Temple" if not Magic.available(s,key) else str(ceili(s.cooldowns[key]))+"s cooldown" if s.cooldowns[key]>0 else str(int(d.cost))+" gold"); tooltip=d.description; icon=Royal.icon(key+"-seal")
		var b=widgets.get("command_"+key)
		if not is_instance_valid(b) or b.get_parent()!=cards:
			b=RoyalCard.new(); b.focus_mode=Control.FOCUS_NONE; b.mouse_filter=Control.MOUSE_FILTER_PASS; b.pressed.connect(func():command(key)); widgets["command_"+key]=b; cards.add_child(b)
		b.custom_minimum_size=Vector2(136 if compact else maxf(120,floorf((deck.size.x-24-49)/8)),104); b.tooltip_text=tooltip
		b.configure(text,icon,main.world.mode_key==key,disabled)
func command(key: String) -> void:
	main.record_action("command_"+key,tab)
	if tab=="recruit":
		var s=main.sim
		var guilds=s.operating("").filter(func(b):return s.definition_of(b).get("recruits","")==key)
		for b in guilds:
			if s.recruit(b.id)!=null: break
	elif tab=="spells" and not Magic.available(main.sim,key):
		var temples=main.sim.operating("temple")
		if temples.is_empty(): main.sim.notify("Build a Temple, then select it to learn spells.")
		else: show_research("spell",temples[0].id)
	else: main.set_mode("" if main.world.mode_key==key else "spell" if tab=="spells" else "bounty" if tab=="bounty" else "build",key)
	main.flush_run_log(); refresh()
func refresh() -> void:
	if root==null: return
	var began: int=Time.get_ticks_usec()
	var s=main.sim
	treasury.text="%d"%s.gold; hero_count.text=str(s.units.filter(func(u):return not u.dead and u.hero).size()); day_count.text="Day %d"%(1+int(s.time/120))
	widgets.pause.text="Resume" if s.paused else "Pause"; widgets.sound.text="Mute" if main.sound.enabled else "Sound"
	for n in [1,2,3]: Royal.active(widgets["speed_"+str(n)],main.speed==n)
	var sanitation=Sanitation.status(s)
	chapter.text=s.Mission.title(s)
	encounter_button.visible=s.mission.id=="ember_crown" and s.mission.revealed
	encounter_button.text="Locate Warlord" if s.mission.boss_id and not s.mission.boss_defeated else "Locate Monastery"
	campaign_progress.max_value=8 if s.run.is_empty() else 4
	campaign_progress.value=s.stats.lairs if s.run.is_empty() else mini(s.stats.lairs,2)+int(s.mission.encounter_cleared)+int(s.mission.boss_defeated)
	quest.text="%d of 8 lairs vanquished\n%s\n\nCottages: %d / 6 safe%s"%[s.stats.lairs,s.Mission.objective(s),sanitation.cottages,"\nRat sewers: %d · next in %ds"%[sanitation.active,sanitation.next_in] if sanitation.next_in>=0 else "\nActive rat sewers: %d"%sanitation.active if sanitation.active>0 else ""]
	if not s.run.is_empty(): quest.text=s.Mission.objective(s)+"\n\n%d lairs cleared · Other lairs optional\nCottages: %d / 6 safe"%[s.stats.lairs,sanitation.cottages]+("\nRat sewers: %d · next in %ds"%[sanitation.active,sanitation.next_in] if sanitation.next_in>=0 else "")
	var ids: Array=s.buildings.filter(func(b):return b.hostile and not b.infestation).map(func(b):return b.id)
	if ids!=objective_ids: clear(objective_list); objective_ids=ids
	for b in s.buildings:
		if not b.hostile or b.infestation: continue
		var entry=widgets.get("lair_"+str(b.id))
		if not is_instance_valid(entry) or entry.get_parent()!=objective_list:
			entry=button("lair_"+str(b.id),"",func():main.center_on(s.pos(b)); main.world.selected=b.id; objectives_open=false; refresh()); objective_list.add_child(entry)
		entry.text=("Done · " if b.dead else "· ")+b.site_name
		entry.add_theme_font_size_override("font_size",15); entry.disabled=b.dead or not s.is_explored(s.pos(b)); entry.tooltip_text="Explore the frontier to discover this lair." if entry.disabled and not b.dead else "Locate this lair"
	var e=s.entity(main.world.selected)
	inspector.visible=e!=null and not e.dead
	if inspector.visible: inspect(e)
	if compact and inspector.visible: campaign.visible=false
	status.text=("PAUSED · " if s.paused else "")+s.message
	if main.world.mode_kind!="": status.text="%s: %s · Esc/right-click cancels"%[main.world.mode_kind.capitalize(),main.world.mode_key]
	notice.text="\n".join(s.notifications.filter(func(n):return s.time-n.at<5).map(func(n):return n.text))
	notice.visible=not compact and modal==null
	if main.log_status.get("error","")!="": status.text="Run log not saved · Open Run logs"
	if modal_kind=="run_logs": RunLogUI.refresh(self)
	refresh_hint()
	update_cards(); layout(true); minimap.queue_redraw()
	if s.result!="" and s.result!=last_result: last_result=s.result; show_end()
	if modal_kind=="journeys": JourneyUI.refresh(self)
	refresh_ms=(Time.get_ticks_usec()-began)/1000.0
func inspect(e) -> void:
	var s=main.sim
	var signature: String=str(e.id)+(str(e.progress==1)+str(e.tier) if e.kind=="building" else "")
	if e.kind=="building": signature+=str(s.Shelter.occupants(s,e.id).map(func(u):return u.id))
	if signature!=action_signature: clear(actions); action_signature=signature
	portrait.visible=e.kind in ["unit","building"]
	if e.kind=="building":
		portrait.texture=main.world.textures[e.type]
		var d=s.definition_of(e)
		details.text=e.site_name+"\nHealth: %d / %d\n"%[e.hp,e.max_hp]+("Construction: %d%%"%(e.progress*100) if e.progress<1 else "Operational")
		if e.infestation: details.text="Overcrowded Sewer\nHealth: %d / 650\nRats every 18 seconds. No gold, loot or XP. Reduce cottages to prevent recurrence."%e.hp
		if e.hostile: details.text+="\n\n"+d.description+"\n\nPossible drops: "+loot_description(e); add_action("action","Post attack bounty · 100g",func():var f=s.place_flag("attack",s.pos(e),e.id); main.world.selected=f.get("id",e.id); refresh())
		else:
			details.text+="\n\nTax reserves: %dg"%e.tax
			var occupants: Array=s.Shelter.occupants(s,e.id)
			if e.type in s.Shelter.TYPES:
				details.text+="\n\nInside: %d"%occupants.size()
				for hero in occupants:
					details.text+="\n"+hero.name+" · "+hero.state+" · HP %d/%d"%[hero.hp,hero.max_hp]
					add_action("occupant_"+str(hero.id),hero.name+" · Journal",func():HeroUI.journal(self,hero.id))
			details.text+="\n\n"+d.description
			if d.has("recruits"):
				details.text+="\nGuild tier: %d · Capacity: %d"%[e.tier,s.guild_capacity(e)]
				if e.tier>1: details.text+="\nGuild support: +%d attack, +%d armor\nApplies to this guild’s heroes while it stands."%[d.upgrade_damage,d.upgrade_armor]
				elif d.upgrade_cost>0:
					add_action("upgrade","Training · %ds"%e.upgrade_remaining if e.upgrade_remaining>0 else "Upgrade guild · %dg"%d.upgrade_cost,func():s.upgrade(e.id); refresh(),e.progress<1 or e.upgrade_remaining>0 or s.gold<d.upgrade_cost)
			if d.has("recruits"): add_action("action","Recruit %s · %dg"%[d.recruits,s.definitions.units[d.recruits].cost],func():s.recruit(e.id); refresh(),e.progress<1)
			if e.type=="marketplace" and e.progress==1: details.text+="\n"+research_status("potion"); add_action("research","Potions & research",func():show_research("potion",e.id))
			if e.type=="temple" and e.progress==1: details.text+="\n"+research_status("spell"); add_action("research","Spellbook & research",func():show_research("spell",e.id))
			if e.type=="thieves" and not s.run.is_empty():
				details.text+="\nGuild bank: %dg · Seizure %s\nThieves keep half; half of each theft enters this bank."%[s.Court.bank(s,e.id),"ready" if s.Court.wait_time(s)==0 else "in %ds"%s.Court.wait_time(s)]
				add_action("confiscate","Confiscate guild bank",func():s.Court.confiscate(s,e.id); refresh(),e.progress<1 or s.Court.wait_time(s)>0 or s.Court.bank(s,e.id)<=0)
			if e.type in ["inn","brothel"]: details.text+="\nVisit: %dg from a hero’s purse. Collectors carry the proceeds.\nPaying patrons inside: %d"%[d.visit_cost,s.units.filter(func(u):return not u.dead and u.journey.get("leisure_place",0)==e.id and u.journey.get("leisure_until",0)>s.time).size()]
			if e.type=="house": add_action("demolish","Demolish · no refund",func():s.demolish(e.id); refresh())
	elif e.kind=="unit":
		var art_key: String="unit_warlord" if e.id==s.mission.boss_id else "unit_"+e.type
		portrait.texture=main.world.portraits[art_key]
		details.text=e.name+"\n"+("Level %d %s\n"%[e.level,e.definition.name] if e.hero else "")+e.state+"\n\nHealth: %d / %d\nAttack: %d · Armor: %d"%[e.hp,e.max_hp,Supplies.damage(s,e),Supplies.armor(s,e)]
		if e.id==s.mission.boss_id: details.text+="\n\nGround slam: leave the marked circle.\n"+("Enraged: faster slams." if s.mission.enraged else "Enrages at half health.")
		if e.hero:
			if e.inside>0: details.text+="\nInside "+s.building(e.inside).site_name
			var progress=HeroUI.Progress.context(s,e)
			details.text+="\n\nNext: level %d · %d XP to go\n%s"%[e.level+1,progress.xp_needed,progress.advice]
			add_action("hero_journal","Journal & next steps",func():HeroUI.journal(self,e.id))
			details.text+="\n\nEquipment"
			if e.equipment.is_empty(): details.text+="\nNo relics equipped. Recover lair treasure."
			for key in e.equipment.values(): details.text+="\n"+s.definitions.items[key].name+" · "+s.definitions.items[key].description
			details.text+="\nPurse: %dg · XP: %d / %d\n"%[e.gold,e.xp,e.level*45]
			for key in s.definitions.potions: details.text+="\n%s: %d / %d"%[s.definitions.potions[key].name,e.potions[key],s.definitions.potions[key].capacity]
			for key in e.buffs:
				if e.buffs[key]>0: details.text+="\n%s: %ds"%[s.definitions.potions[key].name,e.buffs[key]]
		for key in e.magic_buffs:
			if e.magic_buffs[key]>0: details.text+="\n%s: %ds"%[s.definitions.spells[key].name,e.magic_buffs[key]]
		if e.type=="wizard": details.text+="\n\nMana: %d / %d\n+2/s combat · +4/s resting\n%s"%[e.mana,e.max_mana,"Last cast: "+s.definitions.spells[e.last_spell.key].name if not e.last_spell.is_empty() else "Casts learned spells automatically."]
		if e.type=="collector": details.text+="\nCarrying: %dg"%e.carried
		if e.hostile: details.text+="\n\nPossible drops: "+loot_description(e); add_action("action","Post attack bounty · 100g",func():var f=s.place_flag("attack",e.pos,e.id); main.world.selected=f.get("id",e.id); refresh())
	elif e.kind=="flag":
		details.text=e.type.capitalize()+" bounty\nReward: %dg\n%d heroes interested\n\n"%[e.reward,s.units.filter(func(u):return not u.dead and u.goal==e.id).size()]+("Defeat the target to claim the gold." if e.target else "The first hero to reach this spot claims the reward.")
		add_action("action","Raise reward · +50g",func():s.raise_bounty(e.id); refresh()); add_action("withdraw","Withdraw bounty",func():s.cancel_bounty(e.id); refresh())
	else:
		details.text=("Treasure Chest" if e.chest else "Loot Pouch")+"\n"+e.source+"\n\nGold: %dg"%e.gold
		for key in e.potions:
			if e.potions[key]>0: details.text+="\n%s × %d"%[s.definitions.potions[key].name,e.potions[key]]
		for key in e.items: details.text+="\nRelic: "+s.definitions.items[key].name
		details.text+="\n\nHeroes collect treasure when nearby ground is safe. Gold belongs to the collecting hero."
func loot_description(e) -> String:
	var table=Supplies.loot_table(main.sim,e)
	if table.is_empty(): return "No loot from urban infestations."
	var out: String="%d–%d gold"%[table.gold[0],table.gold[1]]
	for p in table.potions: out+=" · %d%% %s"%[p[1]*100,main.sim.definitions.potions[p[0]].name]
	return out
func add_action(key: String,text: String,callback: Callable,disabled: bool=false) -> void:
	var previous=widgets.get(key)
	if is_instance_valid(previous) and previous.get_parent()==actions:
		previous.text=text; previous.disabled=disabled or main.sim.result!=""; return
	var b=button(key,text,callback); b.disabled=disabled or main.sim.result!=""; actions.add_child(b)
func research_status(kind: String) -> String:
	var state=main.sim.alchemy if kind=="potion" else main.sim.magic
	if not state.project.is_empty(): return "Studying: %s · %ds"%[state.project.key,state.project.remaining]
	return "%d learned"%state.unlocked.size()
func open_modal(kind: String) -> void:
	var resume_state: bool=was_paused if modal!=null and modal_kind!="journeys" else main.sim.paused
	if modal!=null: close_modal(false)
	was_paused=resume_state; main.sim.paused=resume_state if kind=="journeys" else true; modal_kind=kind
	modal=ColorRect.new(); modal.color=Color(0.035,0.045,0.04,0.82); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(modal)
	modal_panel=panel(modal); modal_panel.add_theme_stylebox_override("panel",Royal.box("parchment",20))
	var body:=VBoxContainer.new(); modal_panel.add_child(body)
	modal_header=VBoxContainer.new(); modal_header.visible=false; body.add_child(modal_header)
	var scroll:=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.size_flags_vertical=Control.SIZE_EXPAND_FILL; body.add_child(scroll)
	modal_scroll=scroll
	modal_footer=VBoxContainer.new(); modal_footer.visible=false; body.add_child(modal_footer)
	modal_column=VBoxContainer.new(); modal_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; modal_column.add_theme_constant_override("separation",12); scroll.add_child(modal_column); layout_modal()
func layout_modal() -> void:
	var s: Vector2=main.get_viewport_rect().size
	if modal_kind=="welcome":
		var small: bool=s.x<900
		modal_panel.size=Vector2(minf(510,s.x-48),minf(694,s.y-76)); modal_panel.position=Vector2(24 if small else maxf(64,s.x*.075),(s.y-modal_panel.size.y)/2)
		if is_instance_valid(menu_title): menu_title.add_theme_font_size_override("font_size",35 if small else 49)
		if is_instance_valid(menu_tagline): menu_tagline.add_theme_font_size_override("font_size",21 if small else 25)
		if is_instance_valid(menu_caption): menu_caption.visible=not small; menu_caption.position=Vector2(s.x-420,s.y-90); menu_caption.size=Vector2(370,50)
	elif modal_kind=="journeys":
		modal_panel.size=Vector2(minf(1240,s.x-24),minf(920,s.y-32)); modal_panel.position=(s-modal_panel.size)/2
	else:
		modal_panel.size=Vector2(minf(720,s.x-24),minf(740,s.y-32)); modal_panel.position=(s-modal_panel.size)/2
func modal_text(text: String,font_size: int=18) -> void:
	var l=label(text,font_size,"ddcfaf" if modal_kind=="welcome" else "453525"); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; modal_column.add_child(l)
func close_modal(resume: bool=true) -> void:
	if modal==null: return
	if modal_kind=="journeys": was_paused=main.sim.paused
	root.remove_child(modal); modal.queue_free(); modal=null; modal_kind=""
	if resume: main.sim.paused=was_paused
	top.visible=true; deck.visible=true; layout(true)
func show_research(kind: String,id: int) -> void:
	open_modal("research"); modal_text("The royal spellbook" if kind=="spell" else "Prepare them for adventure",30)
	modal_text("Study once for the crown and every wizard. You cast with gold; wizards use mana. One study at a time; losing every Temple pauses study." if kind=="spell" else "You fund recipes. Heroes buy supplies with personal gold. One study at a time; losing every Marketplace pauses research.")
	var s=main.sim; var definitions=s.definitions.spells if kind=="spell" else s.definitions.potions; var state=s.magic if kind=="spell" else s.alchemy
	for key in definitions:
		var d=definitions[key]; var done: bool=Magic.available(s,key) if kind=="spell" else state.unlocked.get(key,false)
		var prerequisite: String=d.get("prerequisite","") if kind=="spell" else d.get("requires","")
		var locked: bool=prerequisite!="" and (not Magic.available(s,prerequisite) if kind=="spell" else not state.unlocked.get(prerequisite,false))
		modal_text(d.name,23); modal_text(d.description,17)
		modal_text("Crown: %dg · Wizard: %d mana · Cooldown: %ds"%[d.cost,d.mana,d.cooldown] if kind=="spell" else "Hero price: %dg · Carry %d"%[d.price,d.capacity],15)
		var caption: String="Known from the start" if d.get("innate",false) else "Learned" if done else "Learn "+prerequisite+" first" if locked else "Study in progress" if not state.project.is_empty() else "Research · %dg / %ds"%[d.research,d.time]
		var b=button("learn_"+key,caption,func():
			var ok: bool=Magic.research(s,key,id) if kind=="spell" else Supplies.research(s,key,id)
			if ok: close_modal(); refresh())
		b.disabled=done or locked or not state.project.is_empty() or s.gold<d.get("research",0); modal_column.add_child(b)
	modal_column.add_child(button("close_modal","Return to the kingdom",func():close_modal(); refresh()))
func show_welcome() -> void:
	if main.settlement_mode: SettlementUI.setup(self); return
	open_modal("welcome"); modal.color=Color.TRANSPARENT
	menu_overlay=RoyalOverlay.new(); menu_overlay.welcome=true; modal.add_child(menu_overlay); modal.move_child(menu_overlay,0)
	modal_panel.add_theme_stylebox_override("panel",StyleBoxEmpty.new()); modal_column.add_theme_constant_override("separation",14)
	var crest:=TextureRect.new(); crest.texture=Royal.icon("crest"); crest.custom_minimum_size=Vector2(68,76); crest.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; crest.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT; crest.size_flags_horizontal=Control.SIZE_SHRINK_BEGIN; modal_column.add_child(crest)
	modal_text("A KINGDOM AWAITS ITS SOVEREIGN",11)
	menu_title=label("SOVEREIGN",49,"efdfb6"); modal_column.add_child(menu_title)
	menu_tagline=label("A crown. A kingdom. A little chaos.",25,"cdb27b"); menu_tagline.add_theme_font_override("font",Royal.ITALIC); menu_tagline.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; modal_column.add_child(menu_tagline)
	var rule:=HSeparator.new(); var line:=StyleBoxLine.new(); line.color=Color("9c824e"); line.thickness=1; rule.add_theme_stylebox_override("separator",line); modal_column.add_child(rule)
	modal_text("Raise a realm in the untamed borderlands. Build guilds, gather heroes, and let adventure unfold.\nYou wear the crown. They choose the quest.",19)
	modal_text("CHOOSE YOUR CHRONICLE",11)
	var choices:=HBoxContainer.new(); modal_column.add_child(choices)
	for key in ["ember_crown","classic"]:
		var choice=button("mission_"+key,"The Ember Crown\nRelics & reckoning" if key=="ember_crown" else "Classic Kingdom\nThe original chronicle",func():main.mission_id=key; main.new_game(main.sim.fixture.seed); show_welcome())
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL; choice.add_theme_font_size_override("font_size",16); choice.custom_minimum_size.y=62; Royal.active(choice,main.mission_id==key); choices.add_child(choice)
	modal_text("Uncover the Ashen Monastery and defeat the Ember Warlord." if main.mission_id=="ember_crown" else "Tame the frontier. Destroy eight lairs and defend your Palace.",16)
	var seed_edit:=LineEdit.new(); seed_edit.placeholder_text="Optional map seed or name"; widgets.seed_input=seed_edit; modal_column.add_child(seed_edit)
	var begin=button("start","Begin your reign     ›",func():
		if seed_edit.text.strip_edges()!="": main.new_game(SimulationSeed(seed_edit.text)); main.pinned_seed=main.sim.fixture.seed
		close_modal(false); main.sim.paused=false; main.started=true; main.sound.enable(); refresh())
	Royal.primary(begin); begin.custom_minimum_size.y=54; modal_column.add_child(begin)
	var secondary:=HBoxContainer.new(); modal_column.add_child(secondary)
	for b in [button("random_map","A fresh map",func():main.pinned_seed=-1; main.new_game(); show_welcome()),button("load_welcome","Load kingdom",func():main.load_game(true))]: b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; secondary.add_child(b)
	modal_column.add_child(button("settlements","The Ashen March · settlement runs",func():main.prepare_settlement(); show_welcome()))
	menu_caption=label(main.sim.fixture.name.to_upper()+"\nMap "+str(main.sim.fixture.seed)+"  ·  The untamed borderlands",14,"d8c89f"); menu_caption.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT; menu_caption.mouse_filter=Control.MOUSE_FILTER_IGNORE; modal.add_child(menu_caption)
	layout(true)
func SimulationSeed(text: String) -> int: return main.sim.SeedRng.normalize(text)
func show_help() -> void:
	open_modal("help"); modal_text("The art of ruling",30)
	modal_text("Build a guild, then recruit heroes. They choose their own targets; attack and exploration bounties give them reasons to follow your plans. "+("Defeat the Warlord and keep the Palace standing. Other lairs are optional." if not main.sim.run.is_empty() else "Destroy all eight campaign lairs and keep the Palace standing."))
	modal_text("Open Hero Journeys to track every hero’s stage, location, current call and next support action together. The overview stays live and has its own pause control. Filter heroes needing support, on quests, recovering or at Mastery. Journals remain available for equipment and history.")
	modal_text("Persona and Shadow can alternate throughout a hero’s life. A crushing defeat below 20% health interrupts any journey, even Mastery. Shadow heroes stop adventuring and withdraw to the castle. Healing alone cannot restore purpose: fund support in Hero Journeys, then protect their 25 seconds of practice at a guild or Temple. Refusing heroes spend their own gold at an Inn or Brothel near the castle. Thieves pick patrons’ pockets and bank half the stolen gold. Confiscate a guild bank once per 120 game seconds through Guild banks & leisure.")
	modal_text("Build Marketplaces to research potions and Temples to learn spells. Heroes buy supplies using their own gold and collect treasure when ground is safe. Wizards share learned spells and spend regenerating mana.")
	modal_text("Guild upgrades add two beds, 25% building health, and guild support (+4 attack, +2 armor). Select a completed guild to fund training. Heroes automatically equip better relic weapons and armor from safe treasure; equipment drops on death for another hero to recover.")
	modal_text("The Ashen March: two lairs reveal the monastery; you can also discover it naturally. Clearing it calls the Warlord in 90 seconds. He guards the ruins until heroes approach. Heroes try to dodge marked slams; healing and protective magic help them survive. He enrages at half health." if not main.sim.run.is_empty() else "The Ember Crown: reveal the monastery, defeat the Warlord and clear all eight lairs.")
	modal_text("Six completed cottages are safe. Each group of four excess cottages sustains another rat sewer after 60 seconds. Demolish cottages without a refund to reduce pressure. Urban rats give no loot or experience.")
	modal_text("Heroes enter guilds, temples, inns and brothels to shelter and rest. Flickering lights and a waving pennant mark occupied buildings. Select a building to see its residents; Hero Journeys lists everyone’s indoor location.")
	modal_text("Click/tap to select or place. Drag with a finger or right mouse button to pan. Wheel or +/− to zoom. WASD/arrows pan, Space pauses, 1/2/3 changes speed, F centers the Palace, Esc/right-click cancels. Shift-click builds several. Use the minimap to travel.")
	modal_text(main.sim.fixture.name+" · Map seed "+str(main.sim.fixture.seed))
	if main.sim.run.is_empty(): modal_column.add_child(button("replay","Replay this map",func():var seed:int=main.sim.fixture.seed; close_modal(false); main.new_game(seed); main.started=true; main.sim.paused=false; refresh()))
	else: modal_column.add_child(button("enable_hints","Enable contextual hints",func():main.settlements.set_hint("",true); close_modal(); refresh()))
	modal_column.add_child(button("close_modal","Return to the kingdom",func():close_modal(); refresh()))
func show_end() -> void:
	if not main.sim.run.is_empty(): SettlementUI.result(self); return
	open_modal("end"); var s=main.sim
	modal_text("Long live the sovereign." if s.result=="victory" else "A kingdom remembered.",32)
	modal_text("The Ember Crown is yours. The Warlord and his lairs have fallen." if s.result=="victory" and s.mission.id=="ember_crown" else "The last lair lies in ruins. Your heroes have brought peace to the kingdom." if s.result=="victory" else "The Palace has fallen. Raise more guilds, protect your roads, and let your next reign be a wiser one.")
	modal_text("Reign: %d:%02d\nLairs: %d / 8\nRecruits: %d\nRecovered: %dg and %d potions\n%s · Seed %d"%[int(s.time/60),int(s.time)%60,s.stats.lairs,s.stats.recruits,s.stats.loot_gold,s.stats.loot_potions,s.fixture.name,s.fixture.seed])
	modal_column.add_child(button("replay","Replay this map",func():var seed:int=s.fixture.seed; close_modal(false); main.new_game(seed); main.started=true; main.sim.paused=false; refresh()))
	modal_column.add_child(button("fresh","A new kingdom",func():close_modal(false); main.pinned_seed=-1; main.new_game(); main.started=true; main.sim.paused=false; refresh()))
func show_run_menu() -> void: SettlementUI.menu(self)
func show_title() -> void: SettlementUI.title(self)
func show_replace_saved() -> void: SettlementUI.replace_saved(self)
func dismiss_hint(enabled: bool) -> void:
	if main.settlements.set_hint(hint_key,enabled): hint_key=""; hint_panel.visible=false
	else: main.sim.notify(main.settlements.error)
func refresh_hint() -> void:
	var s=main.sim; var p: Dictionary=main.settlements.profile
	hint_panel.visible=false
	if s.run.is_empty() or not main.started or modal!=null or s.result!="" or not p.get("hints_enabled",false): return
	if hint_key!="" and p.hints.has(hint_key): hint_key=""
	if hint_key=="":
		var candidates={"recruit":s.operating("").any(func(b):return s.definition_of(b).has("recruits")) and s.stats.recruits==0,"bounty":s.stats.recruits>0 and s.flags.is_empty(),"retreat":s.units.any(func(u):return u.hero and u.state in ["Fleeing","Resting"]),"shopping":s.stats.potions_bought>0}
		for key in candidates:
			if candidates[key] and not p.hints.has(key): hint_key=key; break
	if hint_key!="":
		hint_label.text=s.Settlement.content().hints[hint_key]; hint_panel.visible=not compact or not inspector.visible and not objectives_open
func debug_widgets() -> Dictionary:
	var out: Dictionary={}
	for key in widgets:
		var b=widgets[key]
		if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
			var r: Rect2=b.get_global_rect(); out[key]={"point":[r.get_center().x,r.get_center().y],"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"disabled":b.disabled if b is Button else false,"text":b.text if b is Button or b is LineEdit else ""}
			var ancestor=b.get_parent()
			while ancestor!=null:
				if ancestor is ScrollContainer:
					var clip: Rect2=ancestor.get_global_rect(); out[key].clip_rect=[clip.position.x,clip.position.y,clip.size.x,clip.size.y]; break
				ancestor=ancestor.get_parent()
	return out

func show_court() -> void:
	open_modal("court"); render_court()
func render_court() -> void:
	var s=main.sim; clear(modal_column)
	modal_text("GUILD BANKS & LEISURE",26)
	modal_text("Kingdom paused · return to Hero Journeys to resume time.",15)
	modal_text("Refusing heroes spend their own gold at an Inn or Brothel within 16 tiles of the castle. A visit lasts 18s. Spending does not cure Shadow.",17)
	modal_text("Thieves steal up to 20g from a nearby patron every 20s. They keep half and deposit half in their own guild. Collectors carry venue income as taxes; guild banks require a royal seizure.",17)
	modal_text("Royal seizure ready" if s.Court.wait_time(s)==0 else "Next royal seizure in %ds of kingdom time"%s.Court.wait_time(s),20)
	var guilds: Array=s.operating("thieves")
	if guilds.is_empty(): modal_text("Build a Thieves’ Guild and recruit a thief to start a guild bank.",17)
	for guild in guilds:
		modal_text(guild.site_name+" · %dg banked"%s.Court.bank(s,guild.id),20)
		var seize=button("court_seize_"+str(guild.id),"Confiscate · %dg"%s.Court.bank(s,guild.id),func():s.Court.confiscate(s,guild.id); render_court())
		seize.disabled=s.result!="" or s.Court.wait_time(s)>0 or s.Court.bank(s,guild.id)<=0; modal_column.add_child(seize)
	for type in ["inn","brothel","thieves"]:
		var d=s.definitions.buildings[type]
		modal_text(d.name+" · %d operating"%s.operating(type).size(),20)
		modal_column.add_child(button("court_build_"+type,"Build "+d.name+" · %dg"%d.cost,func():HeroUI.build_service(self,type)))
	modal_column.add_child(button("court_journeys","Back to Hero Journeys",func():JourneyUI.open(self)))
