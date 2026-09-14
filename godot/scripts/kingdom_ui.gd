extends CanvasLayer
const Magic=preload("res://scripts/magic.gd")
const Supplies=preload("res://scripts/supplies.gd")
const Sanitation=preload("res://scripts/sanitation.gd")
const MiniMap=preload("res://scripts/minimap.gd")
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

func _ready() -> void:
	root=Control.new(); root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.mouse_filter=Control.MOUSE_FILTER_IGNORE; add_child(root)
	var theme:=Theme.new(); theme.default_font=preload("res://assets/alegreya.ttf"); theme.default_font_size=18
	var style:=StyleBoxFlat.new(); style.bg_color=Color("69372b"); style.border_color=Color("b49458"); style.set_border_width_all(1)
	style.content_margin_left=10; style.content_margin_right=10; style.content_margin_top=6; style.content_margin_bottom=6
	theme.set_stylebox("normal","Button",style)
	var hover=style.duplicate(); hover.bg_color=Color("895039"); theme.set_stylebox("hover","Button",hover); theme.set_stylebox("pressed","Button",hover)
	var disabled=style.duplicate(); disabled.bg_color=Color("645b49"); theme.set_stylebox("disabled","Button",disabled)
	theme.set_color("font_color","Button",Color("f1e0b7")); theme.set_color("font_disabled_color","Button",Color("b8ab8d")); root.theme=theme
	top=panel(root,"28271f"); var top_col:=VBoxContainer.new(); top.add_child(top_col)
	var line:=HBoxContainer.new(); line.add_theme_constant_override("separation",16); top_col.add_child(line)
	title=label("SOVEREIGN",25,"ecd4a0"); title.add_theme_font_override("font",preload("res://assets/cinzel.ttf")); line.add_child(title)
	treasury=label("",21,"ecd4a0"); treasury.size_flags_horizontal=Control.SIZE_EXPAND_FILL; line.add_child(treasury)
	line.add_child(button("pause","Pause",func():main.sim.paused=not main.sim.paused; refresh()))
	controls=HFlowContainer.new(); controls.add_theme_constant_override("h_separation",7); top_col.add_child(controls)
	for n in [1,2,3]: controls.add_child(button("speed_"+str(n),str(n)+"×",func():main.speed=n; main.sim.paused=false; refresh()))
	controls.add_child(button("sound","Sound",func():main.sound.toggle(); refresh()))
	controls.add_child(button("save","Save",main.save_game)); controls.add_child(button("load","Load",main.load_game))
	controls.add_child(button("help","Help",show_help)); controls.add_child(button("new","New",func():main.new_game(); show_welcome()))
	controls.add_child(button("objectives","Objectives",func():objectives_open=not objectives_open; layout(true)))
	controls.add_child(button("map","Map",func():map_open=not map_open; layout(true)))
	controls.add_child(button("center","Palace",main.center)); controls.add_child(button("zoom_out","−",func():main.change_zoom(0.86))); controls.add_child(button("zoom_in","+",func():main.change_zoom(1.16)))
	campaign=panel(root); var campaign_scroll:=ScrollContainer.new(); campaign_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; campaign.add_child(campaign_scroll); var campaign_col:=VBoxContainer.new(); campaign_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; campaign_scroll.add_child(campaign_col)
	campaign_col.add_child(label("THE ROYAL CAMPAIGN",14,"866640")); chapter=label("The Young Kingdom",24); chapter.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; campaign_col.add_child(chapter)
	quest=label("",17); quest.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; campaign_col.add_child(quest)
	encounter_button=button("encounter","Locate encounter",func():
		var m: Dictionary=main.sim.mission; var e=main.sim.entity(m.boss_id if m.boss_id and not m.boss_defeated else m.encounter_id)
		if e!=null: main.center_on(main.sim.pos(e)); main.world.selected=e.id; objectives_open=false; refresh())
	campaign_col.add_child(encounter_button)
	objective_list=VBoxContainer.new(); campaign_col.add_child(objective_list)
	inspector=panel(root); inspector_scroll=ScrollContainer.new(); inspector_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; inspector.add_child(inspector_scroll)
	var inspect_col:=VBoxContainer.new(); inspect_col.size_flags_horizontal=Control.SIZE_EXPAND_FILL; inspector_scroll.add_child(inspect_col)
	var heading:=HBoxContainer.new(); inspect_col.add_child(heading)
	var caption=label("YOUR KINGDOM",14,"866640"); caption.size_flags_horizontal=Control.SIZE_EXPAND_FILL; heading.add_child(caption)
	heading.add_child(button("close_selection","×",func():main.world.selected=0; refresh()))
	portrait=TextureRect.new(); portrait.custom_minimum_size=Vector2(0,95); portrait.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; portrait.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; inspect_col.add_child(portrait)
	details=label("",18); details.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; inspect_col.add_child(details)
	actions=VBoxContainer.new(); inspect_col.add_child(actions); inspect_col.move_child(actions,2)
	map_panel=panel(root,"28271f"); var map_col:=VBoxContainer.new(); map_panel.add_child(map_col)
	map_col.add_child(label("THE BORDERLANDS",13,"c9ad73")); minimap=MiniMap.new(); minimap.main=main; map_col.add_child(minimap)
	deck=panel(root,"28271f"); var deck_col:=VBoxContainer.new(); deck_col.add_theme_constant_override("separation",8); deck.add_child(deck_col)
	var tabs:=HBoxContainer.new(); deck_col.add_child(tabs)
	for entry in [["build","Build"],["recruit","Heroes"],["bounty","Bounties"],["spells","Magic"]]:
		var b=button("tab_"+entry[0],entry[1],func():tab=entry[0]; main.set_mode("",""); update_cards(true))
		b.size_flags_horizontal=Control.SIZE_EXPAND_FILL; tabs.add_child(b)
	var scroll:=ScrollContainer.new(); scroll.vertical_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; scroll.custom_minimum_size.y=96; deck_col.add_child(scroll)
	cards=HBoxContainer.new(); cards.add_theme_constant_override("separation",7); scroll.add_child(cards)
	status=label("",16,"e2cca5"); status.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; deck_col.add_child(status)
	notice=label("",17,"f4e7c6"); notice.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; notice.mouse_filter=Control.MOUSE_FILTER_IGNORE; root.add_child(notice)
	layout(true); refresh()
func label(text: String,font_size: int=18,color: String="453525") -> Label:
	var out:=Label.new(); out.text=text; out.add_theme_font_size_override("font_size",font_size); out.add_theme_color_override("font_color",Color(color)); return out
func panel(parent: Node,color: String="e5d3af") -> PanelContainer:
	var p:=PanelContainer.new(); var style:=StyleBoxFlat.new(); style.bg_color=Color(color); style.border_color=Color("ae8851"); style.set_border_width_all(1); style.set_content_margin_all(12); style.set_corner_radius_all(3); p.add_theme_stylebox_override("panel",style); parent.add_child(p); return p
func button(key: String,text: String,callback: Callable) -> Button:
	var b:=Button.new(); b.text=text; b.custom_minimum_size.y=34; b.focus_mode=Control.FOCUS_NONE; b.mouse_filter=Control.MOUSE_FILTER_PASS; b.pressed.connect(callback)
	if key!="": widgets[key]=b
	return b
func clear(parent: Node) -> void:
	for child in parent.get_children(): parent.remove_child(child); child.queue_free()
func layout(force: bool=false) -> void:
	var s: Vector2=main.get_viewport_rect().size
	if s==last_size and not force: return
	last_size=s; compact=s.x<900
	title.visible=s.x>=620; treasury.add_theme_font_size_override("font_size",18 if compact else 21)
	top.position=Vector2.ZERO; top.size=Vector2(s.x,0)
	var top_height: float=maxf(100,top.get_combined_minimum_size().y)
	deck.position=Vector2(10,s.y-207); deck.size=Vector2(s.x-20,197)
	status.custom_minimum_size.y=38
	campaign.visible=not compact or objectives_open
	campaign.position=Vector2(12,top_height+8); campaign.size=Vector2(minf(270,s.x-24),maxf(120,minf(530,s.y-top_height-240)))
	inspector.position=Vector2(s.x-288,top_height+8) if not compact else Vector2(12,top_height+8)
	inspector.size=Vector2(276 if not compact else minf(345,s.x-24),maxf(120,minf(510,s.y-top_height-240)))
	map_panel.visible=map_open and not inspector.visible and (not compact or not campaign.visible)
	map_panel.position=Vector2(s.x-244,maxf(top_height+8,s.y-395)) if not compact else Vector2(s.x-162,top_height+8)
	minimap.custom_minimum_size=Vector2(210,130) if not compact else Vector2(126,84)
	map_panel.size=Vector2(232,0) if not compact else Vector2(150,0)
	notice.position=Vector2(300 if not compact else 18,top_height+12)
	notice.size=Vector2(maxf(100,s.x-610) if not compact else s.x-36,90)
	if modal!=null: layout_modal()
func update_cards(force: bool=false) -> void:
	var s=main.sim
	var signature: String=tab+str(int(s.gold))+str(s.magic.unlocked)+str(s.alchemy.unlocked)+str(int(s.time))+str(main.world.mode_kind)+main.world.mode_key
	if not force and signature==card_signature: return
	card_signature=signature
	if card_tab!=tab: clear(cards); card_tab=tab
	for key in ["build","recruit","bounty","spells"]: widgets["tab_"+key].modulate=Color("e8ca8a") if key==tab else Color.WHITE
	var keys: Array=["warriors","rangers","wizards","marketplace","temple","tower","house","thieves"] if tab=="build" else ["warrior","ranger","wizard","thief"] if tab=="recruit" else ["attack","explore"] if tab=="bounty" else s.definitions.spells.keys()
	for key in keys:
		var text: String=""; var tooltip: String=""; var icon: Texture2D=null; var disabled: bool=false
		if tab=="build":
			var d=s.definitions.buildings[key]; text="%s\n%d gold"%[d.get("short",d.name),d.cost]; tooltip=d.description; icon=main.world.textures[key]
		elif tab=="recruit":
			var d=s.definitions.units[key]; var guilds=s.operating("").filter(func(b):return s.definition_of(b).get("recruits","")==key)
			text="%s\n%d gold"%[d.name,d.cost]; tooltip="Autonomous hero. Includes 24 gold for supplies."; disabled=guilds.is_empty()
			var atlas:=AtlasTexture.new(); atlas.atlas=main.world.textures["unit_"+key]; var a=main.world.manifest["unit_"+key].frames[0].frame; atlas.region=Rect2(a[0],a[1],a[2],a[3]); icon=atlas
		elif tab=="bounty": text=("Attack bounty" if key=="attack" else "Explore bounty")+"\n100 gold"; tooltip="Heroes choose bounties by reward and danger. Select flags to raise or withdraw them."
		else:
			var d=s.definitions.spells[key]; text=d.name+"\n"+("Learn at Temple" if not Magic.available(s,key) else str(ceili(s.cooldowns[key]))+"s cooldown" if s.cooldowns[key]>0 else str(int(d.cost))+" gold"); tooltip=d.description
		var b=widgets.get("command_"+key)
		if not is_instance_valid(b) or b.get_parent()!=cards:
			b=button("command_"+key,text,func():command(key)); cards.add_child(b)
		b.text=text; b.add_theme_font_size_override("font_size",16); b.modulate=Color.WHITE; b.custom_minimum_size=Vector2(174 if tab in ["build","recruit"] else 154,78); b.tooltip_text=tooltip; b.disabled=disabled
		if icon!=null: b.icon=icon; b.expand_icon=true; b.add_theme_constant_override("icon_max_width",48)
		if main.world.mode_key==key: b.modulate=Color("e9c987")
func command(key: String) -> void:
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
	refresh()
func refresh() -> void:
	if root==null: return
	var began: int=Time.get_ticks_usec()
	var s=main.sim
	treasury.text="%dg   %d heroes   Day %d"%[s.gold,s.units.filter(func(u):return not u.dead and u.hero).size(),1+int(s.time/120)]
	widgets.pause.text="Resume" if s.paused else "Pause"; widgets.sound.text="Mute" if main.sound.enabled else "Sound"
	for n in [1,2,3]: widgets["speed_"+str(n)].modulate=Color("e9c987") if main.speed==n else Color.WHITE
	var sanitation=Sanitation.status(s)
	chapter.text=s.Mission.title(s)
	encounter_button.visible=s.mission.id=="ember_crown" and s.mission.revealed
	encounter_button.text="Locate Warlord" if s.mission.boss_id and not s.mission.boss_defeated else "Locate Monastery"
	quest.text="%d / 8 lairs destroyed\n%s\n\n%s · Seed %d\nCottages: %d / 6 safe%s"%[s.stats.lairs,s.Mission.objective(s),s.fixture.name,s.fixture.seed,sanitation.cottages,"\nRat sewers: %d · next in %ds"%[sanitation.active,sanitation.next_in] if sanitation.next_in>=0 else "\nActive rat sewers: %d"%sanitation.active if sanitation.active>0 else ""]
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
	update_cards(); layout(true); minimap.queue_redraw()
	if s.result!="" and s.result!=last_result: last_result=s.result; show_end()
	refresh_ms=(Time.get_ticks_usec()-began)/1000.0
func inspect(e) -> void:
	var s=main.sim
	var signature: String=str(e.id)+(str(e.progress==1)+str(e.tier) if e.kind=="building" else "")
	if signature!=action_signature: clear(actions); action_signature=signature
	portrait.visible=e.kind in ["unit","building"]
	if e.kind=="building":
		portrait.texture=main.world.textures[e.type]
		var d=s.definition_of(e)
		details.text=e.site_name+"\nHealth: %d / %d\n"%[e.hp,e.max_hp]+("Construction: %d%%"%(e.progress*100) if e.progress<1 else "Operational")+"\n\n"+d.description
		if e.infestation: details.text="Overcrowded Sewer\nHealth: %d / 650\nRats every 18 seconds. No gold, loot or XP. Reduce cottages to prevent recurrence."%e.hp
		if e.hostile: details.text+="\n\nPossible drops: "+loot_description(e); add_action("action","Post attack bounty · 100g",func():var f=s.place_flag("attack",s.pos(e),e.id); main.world.selected=f.get("id",e.id); refresh())
		else:
			details.text+="\n\nTax reserves: %dg"%e.tax
			if d.has("recruits"):
				details.text+="\nGuild tier: %d · Capacity: %d"%[e.tier,s.guild_capacity(e)]
				if e.tier>1: details.text+="\nGuild support: +%d attack, +%d armor\nApplies to this guild’s heroes while it stands."%[d.upgrade_damage,d.upgrade_armor]
				elif d.upgrade_cost>0:
					add_action("upgrade","Training · %ds"%e.upgrade_remaining if e.upgrade_remaining>0 else "Upgrade guild · %dg"%d.upgrade_cost,func():s.upgrade(e.id); refresh(),e.progress<1 or e.upgrade_remaining>0 or s.gold<d.upgrade_cost)
			if d.has("recruits"): add_action("action","Recruit %s · %dg"%[d.recruits,s.definitions.units[d.recruits].cost],func():s.recruit(e.id); refresh(),e.progress<1)
			if e.type=="marketplace" and e.progress==1: details.text+="\n"+research_status("potion"); add_action("research","Potions & research",func():show_research("potion",e.id))
			if e.type=="temple" and e.progress==1: details.text+="\n"+research_status("spell"); add_action("research","Spellbook & research",func():show_research("spell",e.id))
			if e.type=="house": add_action("demolish","Demolish · no refund",func():s.demolish(e.id); refresh())
	elif e.kind=="unit":
		var atlas:=AtlasTexture.new(); atlas.atlas=main.world.textures["unit_"+e.type]; var a=main.world.manifest["unit_"+e.type].frames[0].frame; atlas.region=Rect2(a[0],a[1],a[2],a[3]); portrait.texture=atlas
		details.text=e.name+"\n"+("Level %d %s\n"%[e.level,e.definition.name] if e.hero else "")+e.state+"\n\nHealth: %d / %d\nAttack: %d · Armor: %d"%[e.hp,e.max_hp,Supplies.damage(s,e),Supplies.armor(s,e)]
		if e.id==s.mission.boss_id: details.text+="\n\nGround slam: leave the marked circle.\n"+("Enraged: faster slams." if s.mission.enraged else "Enrages at half health.")
		if e.hero:
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
	if modal!=null: close_modal(false)
	was_paused=main.sim.paused; main.sim.paused=true; modal_kind=kind
	modal=ColorRect.new(); modal.color=Color(0.035,0.05,0.035,0.72); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); root.add_child(modal)
	modal_panel=panel(modal); var scroll:=ScrollContainer.new(); scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; modal_panel.add_child(scroll)
	modal_column=VBoxContainer.new(); modal_column.size_flags_horizontal=Control.SIZE_EXPAND_FILL; modal_column.add_theme_constant_override("separation",12); scroll.add_child(modal_column); layout_modal()
func layout_modal() -> void:
	var s: Vector2=main.get_viewport_rect().size
	modal_panel.size=Vector2(minf(720,s.x-24),minf(740,s.y-32)); modal_panel.position=(s-modal_panel.size)/2
func modal_text(text: String,font_size: int=18) -> void:
	var l=label(text,font_size); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; modal_column.add_child(l)
func close_modal(resume: bool=true) -> void:
	if modal==null: return
	root.remove_child(modal); modal.queue_free(); modal=null; modal_kind=""
	if resume: main.sim.paused=was_paused
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
	open_modal("welcome"); modal_text("A crown. A kingdom.\nA little chaos.",36)
	modal_text("Raise a realm in the untamed borderlands. Build guilds, entice heroes, and let adventure unfold. You wear the crown. They choose the quest.")
	modal_text(main.sim.Mission.title(main.sim)+"\n"+main.sim.fixture.name+" · Seed "+str(main.sim.fixture.seed),17)
	modal_text(main.sim.definitions.mission.description if main.mission_id=="ember_crown" else "The original eight-lair campaign.",17)
	var choices:=HBoxContainer.new(); modal_column.add_child(choices)
	for key in ["ember_crown","classic"]:
		var choice=button("mission_"+key,"The Ember Crown" if key=="ember_crown" else "Classic Kingdom",func():main.mission_id=key; main.new_game(main.sim.fixture.seed); show_welcome())
		choice.size_flags_horizontal=Control.SIZE_EXPAND_FILL; choice.add_theme_font_size_override("font_size",16); choice.modulate=Color("e8ca8a") if main.mission_id==key else Color.WHITE; choices.add_child(choice)
	var seed_edit:=LineEdit.new(); seed_edit.placeholder_text="Optional map seed or name"; widgets.seed_input=seed_edit; modal_column.add_child(seed_edit)
	modal_column.add_child(button("start","Begin your reign",func():
		if seed_edit.text.strip_edges()!="": main.new_game(SimulationSeed(seed_edit.text)); main.pinned_seed=main.sim.fixture.seed
		close_modal(false); main.sim.paused=false; main.started=true; main.sound.enable(); refresh()))
	modal_column.add_child(button("random_map","Choose a fresh map",func():main.pinned_seed=-1; main.new_game(); show_welcome()))
	modal_column.add_child(button("load_welcome","Load saved kingdom",func():main.load_game()))
func SimulationSeed(text: String) -> int: return main.sim.SeedRng.normalize(text)
func show_help() -> void:
	open_modal("help"); modal_text("The art of ruling",30)
	modal_text("Build a guild, then recruit heroes. They choose their own targets; attack and exploration bounties give them reasons to follow your plans. Destroy all eight campaign lairs and keep the Palace standing.")
	modal_text("Build Marketplaces to research potions and Temples to learn spells. Heroes buy supplies using their own gold and collect treasure when ground is safe. Wizards share learned spells and spend regenerating mana.")
	modal_text("Guild upgrades add two beds, 25% building health, and guild support (+4 attack, +2 armor). Select a completed guild to fund training. Heroes automatically equip better relic weapons and armor from safe treasure; equipment drops on death for another hero to recover.")
	modal_text("The Ember Crown: destroy two lairs to reveal the Ashen Monastery. Recover its Runeblade, defeat the Ember Warlord, and destroy all eight lairs. Heroes try to leave his marked ground slam; healing and protective magic help them survive. He enrages at half health.")
	modal_text("Six completed cottages are safe. Each group of four excess cottages sustains another rat sewer after 60 seconds. Demolish cottages without a refund to reduce pressure. Urban rats give no loot or experience.")
	modal_text("Click/tap to select or place. Drag with a finger or right mouse button to pan. Wheel or +/− to zoom. WASD/arrows pan, Space pauses, 1/2/3 changes speed, F centers the Palace, Esc/right-click cancels. Shift-click builds several. Use the minimap to travel.")
	modal_text(main.sim.fixture.name+" · Map seed "+str(main.sim.fixture.seed))
	modal_column.add_child(button("replay","Replay this map",func():var seed:int=main.sim.fixture.seed; close_modal(false); main.new_game(seed); main.started=true; main.sim.paused=false; refresh()))
	modal_column.add_child(button("close_modal","Return to the kingdom",func():close_modal(); refresh()))
func show_end() -> void:
	open_modal("end"); var s=main.sim
	modal_text("Long live the sovereign." if s.result=="victory" else "A kingdom remembered.",32)
	modal_text("The Ember Crown is yours. The Warlord and his lairs have fallen." if s.result=="victory" and s.mission.id=="ember_crown" else "The last lair lies in ruins. Your heroes have brought peace to the kingdom." if s.result=="victory" else "The Palace has fallen. Raise more guilds, protect your roads, and let your next reign be a wiser one.")
	modal_text("Reign: %d:%02d\nLairs: %d / 8\nRecruits: %d\nRecovered: %dg and %d potions\n%s · Seed %d"%[int(s.time/60),int(s.time)%60,s.stats.lairs,s.stats.recruits,s.stats.loot_gold,s.stats.loot_potions,s.fixture.name,s.fixture.seed])
	modal_column.add_child(button("replay","Replay this map",func():var seed:int=s.fixture.seed; close_modal(false); main.new_game(seed); main.started=true; main.sim.paused=false; refresh()))
	modal_column.add_child(button("fresh","A new kingdom",func():close_modal(false); main.pinned_seed=-1; main.new_game(); main.started=true; main.sim.paused=false; refresh()))
func debug_widgets() -> Dictionary:
	var out: Dictionary={}
	for key in widgets:
		var b=widgets[key]
		if is_instance_valid(b) and b.is_inside_tree() and b.is_visible_in_tree():
			var r: Rect2=b.get_global_rect(); out[key]={"point":[r.get_center().x,r.get_center().y],"rect":[r.position.x,r.position.y,r.size.x,r.size.y],"disabled":b.disabled if b is Button else false,"text":b.text if b is Button or b is LineEdit else ""}
	return out
