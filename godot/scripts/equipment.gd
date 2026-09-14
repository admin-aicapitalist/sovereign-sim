extends RefCounted
## Relics are physical treasure. Heroes equip better items and leave others to share.
static func bonus(s,u,key: String) -> float:
	var total: float=0
	for item in u.equipment.values(): total+=s.definitions.items[item].get(key,0)
	var guild=s.building(u.home)
	if not guild.is_empty() and not guild.dead and guild.get("tier",1)>1:
		total+=s.definition_of(guild).get("upgrade_"+key,0)
	return total
static func wants(s,u,key: String) -> bool:
	if not u.hero or not s.definitions.items.has(key): return false
	var d: Dictionary=s.definitions.items[key]
	var old: String=u.equipment.get(d.slot,"")
	return old=="" or s.definitions.items[old].rank<d.rank
static func collect(s,u,p) -> int:
	var taken: int=0; var remaining: Array=[]
	for key in p.items:
		if not wants(s,u,key): remaining.append(key); continue
		var slot: String=s.definitions.items[key].slot; var old: String=u.equipment.get(slot,"")
		u.equipment[slot]=key
		if old!="": remaining.append(old)
		taken+=1; s.notify(u.name+" equipped "+s.definitions.items[key].name+".","complete"); s.fx("relic",u.pos,0,1.4)
	p.items=remaining; s.stats.equipment_found+=taken; return taken
static func drop_hero(s,u) -> void:
	if u.equipment.is_empty(): return
	var p=s.Supplies.loot_schema(); var at: Vector2=s.near_open(u.pos)
	if not s.walkable(at): return
	p.merge({"id":s.next_id,"x":at.x,"y":at.y,"chest":true,"type":"loot_chest","source":u.name+"’s equipment","items":u.equipment.values()},true)
	s.next_id+=1; s.loot.append(p); s.by_id[p.id]=p; u.equipment.clear()
