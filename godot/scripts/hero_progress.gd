extends RefCounted
## Player-facing explanations of the current simulation, without inventing journey stages.
static func recovery(s,u) -> bool:
	return u.hp<u.max_hp*s.Journey.retreat_threshold(u) or u.state in ["Resting","Fleeing"] and u.hp<u.max_hp*0.86
static func context(s,u) -> Dictionary:
	var info={"activity":u.state,"goal":"Seeking an opportunity","advice":"","focus":0,"focus_label":"","xp_needed":maxi(0,ceili(u.level*45-u.xp))}
	var flag=s.entity(u.goal)
	var target=s.entity(u.target)
	if recovery(s,u):
		var home=s.building(u.inside) if u.inside>0 else s.nearest(u.pos,s.operating("temple"))
		if home==null: home=s.entity(u.home)
		if not s.Shelter.usable(home): home=s.palace()
		info.goal=("Resting at " if u.state=="Resting" else "Returning to ")+home.site_name
		info.advice="Let them recover to about 86% health before another expedition. A Temple restores health faster; healing potions help before retreat."
		info.focus=home.id; info.focus_label="View recovery site"
	elif s.Journey.is_shadow(u):
		info.goal="Shadow · "+s.Journey.SHADOWS[u.type]; info.advice=s.Journey.describe(s,u).next
	elif u.state=="Buying potions":
		info.goal="Buying supplies before heading out"
		info.advice="Let the shopping trip finish. Heroes spend their own purse; your treasury funds potion research."
		var shop=s.nearest(u.pos,s.operating("marketplace"))
		if shop!=null: info.focus=shop.id; info.focus_label="View Marketplace"
	elif u.state in ["Recovering treasure","Collecting loot"]:
		info.goal="Recovering spoils for their next expedition"
		info.advice="Keep enemies away from the treasure. Heroes collect it and equip better relics automatically."
		var loot=s.entity(u.loot_target)
		if loot!=null and not loot.dead: info.focus=loot.id; info.focus_label="View treasure"
	elif target!=null and not target.dead and target.hostile:
		info.goal="Facing "+(target.site_name if target.kind=="building" else target.name)
		info.advice="Support this fight with other heroes and healing. The hero who lands the finishing blow earns combat XP."
		info.focus=target.id; info.focus_label="View target"
	elif flag!=null and not flag.dead and flag.kind=="flag":
		info.goal="Answering a %dg %s bounty"%[flag.reward,flag.type]
		info.advice="Claiming an exploration bounty gives its first arriving hero 20 XP and the reward." if flag.type=="explore" else "Heroes share attack-bounty gold when near the defeated target. Combat XP goes to the finishing hero."
		info.focus=flag.id; info.focus_label="View current bounty"
	else:
		info.advice="Post an exploration bounty on a reachable approach. Rangers and thieves favor scouting; claiming the flag earns 20 XP." if u.type in ["ranger","thief"] else "Post an attack bounty on a nearby discovered threat. Heroes weigh reward, danger, distance and health; they choose whether to answer."
	if u.inside>0: info.activity="Inside "+s.building(u.inside).site_name+" · "+u.state
	return info
static func history(s,id: int) -> Array:
	var lines: Array=[]
	if s.run.is_empty(): return lines
	for event in s.run.events:
		if int(event.hero)!=id: continue
		var description: String=""
		match event.kind:
			"recruit": description="Joined the settlement"
			"level": description="Reached level "+event.detail
			"explore": description="Claimed an exploration bounty · +20 XP"
			"retreat": description="Withdrew to recover"
			"recovery": description="Began resting at "+event.detail
			"recovered": description="Recovered enough to venture out again"
			"lair": description="Helped defeat "+event.detail
			"boss": description="Helped defeat the Ember Warlord"
			"equipment": description="Equipped "+event.detail
			"death": description="Fell in service to the kingdom"
			"journey","leisure","theft": description=event.detail
		if description!="": lines.append("%d:%02d · %s"%[int(event.at/60),int(event.at)%60,description])
	lines.reverse(); return lines.slice(0,8)
static func deeds(s,u) -> String:
	var record: Dictionary=s.run.get("heroes",{}).get(str(u.id),{})
	var text="Reached level %d · %d relics equipped"%[u.level,u.equipment.size()]
	if not record.is_empty(): text+="\n%d lairs helped clear"%record.lairs+(" · Warlord defeated" if record.boss else "")
	return text
