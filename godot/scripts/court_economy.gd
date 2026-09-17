extends RefCounted
## Money changes hands only at real visits/thefts. Guild reserves are not ordinary taxes.
const CONFISCATION_COOLDOWN=120.0
const THEFT_COOLDOWN=20.0
static func empty() -> Dictionary:
	return {"banks":{},"confiscate_ready":0.0,"confiscated":0.0,"spent":0.0,"stolen":0.0}
static func ledger(s) -> Dictionary:
	if not s.run.has("court"): s.run.court=empty()
	return s.run.court
static func bank(s,id: int) -> float:
	return float(s.run.get("court",{}).get("banks",{}).get(str(id),0))
static func wait_time(s) -> int:
	return maxi(0,ceili(float(s.run.get("court",{}).get("confiscate_ready",0))-s.time))
static func confiscate(s,id: int) -> bool:
	var guild=s.building(id)
	if s.run.is_empty() or s.result!="" or guild.is_empty() or guild.dead or guild.progress<1 or guild.type!="thieves" or wait_time(s)>0 or bank(s,id)<=0: return false
	var account=ledger(s); var amount: float=bank(s,id)
	s.gold+=amount; account.banks[str(id)]=0.0; account.confiscated+=amount; account.confiscate_ready=s.time+CONFISCATION_COOLDOWN
	s.notify("Confiscated %dg from the Thieves’ Guild. Next seizure in 120s."%amount,"coin")
	return true
static func thieve(s,u) -> bool:
	if s.run.is_empty() or u.journey.is_empty() or u.type!="thief" or s.Journey.is_shadow(u) or u.journey.stage in s.Journey.COMMITTED or u.journey.stage=="return": return false
	var guild=s.building(u.home)
	if guild.is_empty() or guild.dead or guild.progress<1 or guild.type!="thieves" or s.time<u.journey.theft_ready: return false
	var victims: Array=s.units.filter(func(v):return v.hero and not v.dead and v.id!=u.id and v.type!="thief" and v.gold>=4 and v.journey.get("leisure_until",0)>s.time and patron(s,v))
	var victim=s.nearest(u.pos,victims)
	if victim==null: return false
	if not s.nearby(victim.pos,6,true).is_empty(): return false
	u.goal=0; u.target=0
	if victim.inside>0:
		if not s.Shelter.seek(s,u,s.building(victim.inside),"Following a patron inside","Picking pockets"): return true
	elif u.pos.distance_to(victim.pos)>1.8: s.go(u,victim.pos,"Seeking a distracted patron"); return true
	var amount: float=minf(20,floorf(victim.gold*0.25)); var cut: float=floorf(amount*0.5)
	victim.gold-=amount; u.gold+=amount-cut
	var account=ledger(s); account.banks[str(guild.id)]=bank(s,guild.id)+cut; account.stolen+=amount
	u.journey.stolen+=amount; u.journey.theft_ready=s.time+THEFT_COOLDOWN
	u.state="Picking pockets"; s.stop(u)
	s.Settlement.event(s,"theft",u,"Stole %dg from %s · %dg to guild bank"%[amount,victim.name,cut])
	s.fx("gold",u.pos,amount-cut)
	return true
static func patron(s,u) -> bool:
	var site=s.building(int(u.journey.get("leisure_place",0)))
	return not site.is_empty() and not site.dead and site.progress==1 and site.type in ["inn","brothel"] and u.inside==site.id
static func leisure(s,u) -> void:
	u.goal=0; u.target=0
	if thieve(s,u): return
	var j: Dictionary=u.journey
	if u.inside==0 and not s.nearby(u.pos,6,true).is_empty():
		j.leisure_until=0; j.leisure_place=0; s.Shelter.seek(s,u,s.Journey.home(s,u),"Seeking shelter","Sheltering inside"); return
	var site=s.building(int(j.leisure_place))
	if not site.is_empty() and not site.dead and site.progress==1 and j.leisure_until>s.time:
		s.Shelter.seek(s,u,site,"Returning to "+site.site_name,"Drinking at the Inn" if site.type=="inn" else "Visiting the Brothel")
		return
	if s.time>=j.leisure_next:
		var places: Array=s.operating("").filter(func(b):return b.type in ["inn","brothel"] and s.pos(b).distance_to(s.pos(s.palace()))<16 and u.gold>=s.definition_of(b).visit_cost and s.nearby(s.pos(b),6,true).is_empty())
		# Keep the selected destination while walking. Alternate venues between visits.
		if site.is_empty() or site not in places:
			site=places[(u.id+int(s.time/30))%places.size()] if not places.is_empty() else {}
		if not site.is_empty():
			if u.inside>0: s.Shelter.leave(s,u)
			j.leisure_place=site.id
			if not s.Shelter.seek(s,u,site,"Heading to "+site.site_name,"Drinking at the Inn" if site.type=="inn" else "Visiting the Brothel"): return
			var cost: float=s.definition_of(site).visit_cost
			u.gold-=cost; site.tax+=cost; j.spent+=cost; ledger(s).spent+=cost
			j.leisure_until=s.time+18; j.leisure_next=s.time+30
			u.state="Drinking at the Inn" if site.type=="inn" else "Visiting the Brothel"; s.stop(u)
			s.Settlement.event(s,"leisure",u,"Spent %dg at %s; purse %dg"%[cost,site.site_name,u.gold]); return
	j.leisure_place=0
	s.Shelter.seek(s,u,s.Journey.home(s,u),"Returning to the castle","Sheltering inside" if s.Journey.is_shadow(u) else "Waiting inside")
static func valid(value: Variant,next_id: float,time: float,buildings: Array) -> bool:
	if not value is Dictionary or not value.get("banks") is Dictionary: return false
	for key in ["confiscate_ready","confiscated","spent","stolen"]:
		var n=value.get(key)
		if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or n<0: return false
	if value.confiscate_ready>time+CONFISCATION_COOLDOWN+0.01: return false
	for id in value.banks:
		if not id is String or not id.is_valid_int() or int(id)<=0 or int(id)>=next_id: return false
		if not buildings.any(func(b):return b is Dictionary and b.get("id")==int(id) and b.get("type")=="thieves"): return false
		var n=value.banks[id]
		if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or n<0: return false
	return true
