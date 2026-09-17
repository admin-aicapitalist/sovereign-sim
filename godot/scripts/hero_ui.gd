extends RefCounted
const Progress=preload("res://scripts/hero_progress.gd")
static func text(ui,parent: Node,value: String,size: int=16) -> Label:
	var label=ui.label(value,size,"453525"); label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; parent.add_child(label); return label
static func meter(ui,parent: Node,value: float,maximum: float,color: String) -> void:
	var bar:=ProgressBar.new(); bar.custom_minimum_size.y=8; bar.show_percentage=false; bar.max_value=maxf(1,maximum); bar.value=value
	var track:=StyleBoxFlat.new(); track.bg_color=Color("b5a27a")
	var fill:=StyleBoxFlat.new(); fill.bg_color=Color(color)
	bar.add_theme_stylebox_override("background",track); bar.add_theme_stylebox_override("fill",fill); parent.add_child(bar)
static func focus(ui,id: int) -> void:
	var e=ui.main.sim.entity(id)
	if e==null or e.dead: return
	ui.close_modal(); ui.main.set_mode("",""); ui.main.world.selected=id; ui.main.center_on(ui.main.sim.pos(e)); ui.objectives_open=false; ui.inspector_scroll.scroll_vertical=0; ui.refresh()
static func choose_bounty(ui,type: String) -> void:
	ui.close_modal(); ui.tab="bounty"; ui.main.set_mode("bounty",type); ui.refresh()
static func build_service(ui,type: String) -> void:
	ui.close_modal(); ui.tab="build"; ui.main.world.selected=0; ui.main.center(); ui.main.set_mode("build",type); ui.refresh()
static func service(ui,type: String,heading: String,description: String) -> void:
	var s=ui.main.sim
	text(ui,ui.modal_column,heading,18); text(ui,ui.modal_column,description)
	var candidates=s.buildings.filter(func(b):return not b.dead and not b.hostile and b.type==type)
	var ready=s.operating(type)
	var building=ready[0] if not ready.is_empty() else candidates[0] if not candidates.is_empty() else null
	if building!=null:
		if building.progress<1: text(ui,ui.modal_column,"Construction: %d%%"%(building.progress*100),15)
		ui.modal_column.add_child(ui.button("hero_service_"+type,"View "+building.site_name,func():focus(ui,building.id)))
	else:
		ui.modal_column.add_child(ui.button("hero_service_"+type,"Build "+s.definitions.buildings[type].name+" · %dg"%s.definitions.buildings[type].cost,func():build_service(ui,type)))
static func roster(ui) -> void:
	ui.JourneyUI.open(ui)
static func journal(ui,id: int) -> void:
	var s=ui.main.sim; var hero=s.entity(id)
	if hero==null or hero.kind!="unit" or not hero.hero or hero.dead: roster(ui); return
	ui.open_modal("hero_journal")
	var info=Progress.context(s,hero)
	ui.modal_text(hero.name,30)
	ui.modal_text("Level %d %s · %dg personal gold"%[hero.level,hero.definition.name,hero.gold],18)
	if not hero.journey.is_empty():
		var journey=s.Journey.describe(s,hero)
		ui.modal_text("JOURNEY · "+journey.stage,22); ui.modal_text(journey.next,17)
		ui.modal_text("%d journeys completed · +%d attack from experience on the road"%[journey.cycles,mini(journey.cycles,10)*2],15)
	ui.modal_text("NOW · "+info.activity,16); ui.modal_text(info.goal,20); ui.modal_text(info.advice,17)
	ui.modal_text("Health %d / %d"%[hero.hp,hero.max_hp],15); meter(ui,ui.modal_column,hero.hp,hero.max_hp,"668459")
	if info.focus>0: ui.modal_column.add_child(ui.button("hero_goal",info.focus_label,func():focus(ui,info.focus)))
	ui.modal_text("NEXT LEVEL · %d"%(hero.level+1),20)
	ui.modal_text("%d / %d XP · %d XP remaining"%[hero.xp,hero.level*45,info.xp_needed],17); meter(ui,ui.modal_column,hero.xp,hero.level*45,"a67c37")
	ui.modal_text("Leveling adds 4 attack and 22 maximum health. Earn XP from finishing enemies and lairs or claiming exploration bounties (+20 XP). Urban rats and sewers grant no XP.",16)
	var offers:=HFlowContainer.new(); ui.modal_column.add_child(offers)
	for type in ["attack","explore"]: offers.add_child(ui.button("hero_bounty_"+type,"Choose "+type+" bounty",func():choose_bounty(ui,type)))
	ui.modal_text("You place offers; heroes choose whether to answer. Raising rewards can attract interest. Resting and shopping take priority.",15)
	ui.modal_text("HELP THEM PREPARE",20)
	var guild=s.building(hero.home)
	if not guild.is_empty() and not guild.dead and s.definition_of(guild).has("recruits"):
		var guild_text="Training is complete: this guild gives its heroes +4 attack and +2 armor." if guild.tier>1 else "Guild training gives its heroes +4 attack and +2 armor. It strengthens them without changing their level."
		if guild.upgrade_remaining>0: guild_text="Guild training is underway · %ds remaining."%guild.upgrade_remaining
		ui.modal_text(guild_text,16)
		ui.modal_column.add_child(ui.button("hero_guild","View home guild",func():focus(ui,guild.id)))
	var healing=s.definitions.potions.healing
	var potion_text="Healing potions: %d / %d. Your treasury pays for research; heroes buy potions with personal gold (%dg each)."%[hero.potions.healing,healing.capacity,healing.price]
	if not s.alchemy.unlocked.get("healing",false):
		potion_text+=" Healing research costs %dg at a completed Marketplace."%healing.research
		if not s.alchemy.project.is_empty(): potion_text+=" Current research: "+s.definitions.potions[s.alchemy.project.key].name+" · %ds left."%s.alchemy.project.remaining
	elif hero.potions.healing<healing.capacity and hero.gold<healing.price: potion_text+=" Their purse cannot cover another bottle yet. Claimed bounties and collected treasure fund purchases."
	else: potion_text+=" Healing is researched. Heroes visit an operating Marketplace to replenish affordable supplies."
	service(ui,"marketplace","Potions for the road",potion_text)
	service(ui,"temple","Recovery and magic","Heroes rest for free at their guild or the Palace. A Temple restores health faster."+(" Research spells there; this wizard casts learned spells automatically using mana." if hero.type=="wizard" else ""))
	ui.modal_text("DEEDS THIS REIGN",20); ui.modal_text(Progress.deeds(s,hero),16)
	ui.modal_text("Equipment",18)
	if hero.equipment.is_empty(): ui.modal_text("No relics equipped. Clear lairs and keep the treasure safe so heroes can collect better equipment.",16)
	for item in hero.equipment.values(): ui.modal_text(s.definitions.items[item].name+" · "+s.definitions.items[item].description,16)
	var history=Progress.history(s,id)
	ui.modal_text("RECENT HISTORY",14)
	if history.is_empty(): ui.modal_text("No earlier events were recorded for this hero.",16)
	for line in history: ui.modal_text(line,16)
	ui.modal_footer.visible=true
	var footer:=HFlowContainer.new(); ui.modal_footer.add_child(footer)
	var find=ui.button("hero_find","Find hero",func():focus(ui,id)); ui.Royal.primary(find); footer.add_child(find)
	footer.add_child(ui.button("hero_roster","All heroes",func():roster(ui)))
	ui.layout(true)
