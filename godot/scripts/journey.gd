extends RefCounted
## A saved, deterministic journey per settlement hero. UI reads the same gates as AI.
const STAGES={"ordinary":"Ordinary World","call":"The Call","refusal":"Refusal","threshold":"Threshold Crossing","tests":"Tests & Allies","ordeal":"The Ordeal","return":"Reward & Return","shadow":"Shadow","mastery":"Mastery"}
const SHADOWS={"warrior":"Cowardice", "ranger":"Withdrawal", "wizard":"Hubris", "thief":"Disillusionment"}
const RECOVERY_COST=80
const RECOVERY_SECONDS=25.0
const PRACTICES={"warrior":"Supervised drills", "ranger":"Guided map work", "wizard":"Temple mentorship", "thief":"Guild reconciliation"}
const COMMITTED=["threshold","tests","ordeal"]
const ARCHETYPES={"warrior":"The Hero","ranger":"The Explorer","wizard":"The Sage","thief":"The Trickster"}
static func initialize(s,u,migrated: bool=false) -> void:
	if not u.hero or s.run.is_empty(): return
	if not u.journey.is_empty():
		if u.journey.version==1:
			var was_shadow: bool=u.journey.stage=="shadow"
			u.journey.merge(new_fields(),true); u.journey.version=2
			if was_shadow:
				u.journey.aspect="shadow"; u.journey.stage="refusal" if u.journey.calling>0 else "ordinary"; u.journey.shadow_since=s.time; u.journey.shadow_count=1
			remember(s,u,"Persona and Shadow tracking resumed; prior experience retained.")
		return
	u.journey={"version":2,"stage":"ordinary","entered":s.time,"cycles":0,"calling":0,"target":0,"kind":"","objective":"","destination":[u.pos.x,u.pos.y],"departure":[u.pos.x,u.pos.y],"deliberation":30+((int(s.fixture.seed)^int(u.id*17))%61),"returned":-1.0,"recovery_tasks":0,"explored":0,"temples":0,"research":0,"offer_marker":0,"history":[]}
	u.journey.merge(new_fields())
	remember(s,u,"Journey tracking began in this saved settlement." if migrated else "Arrived, looking for a purpose.")
static func new_fields() -> Dictionary:
	return {"aspect":"persona","shadow_since":0.0,"shadow_count":0,"recovery_site":0,"recovery_progress":0.0,"recovery_at":0.0,"leisure_place":0,"leisure_until":0.0,"leisure_next":0.0,"theft_ready":0.0,"spent":0.0,"stolen":0.0}
static func is_shadow(u) -> bool: return u.journey.get("aspect","")=="shadow" or u.journey.get("stage","")=="shadow"
static func recovery_site(s,u):
	var sites: Array=s.operating("temple" if u.type=="wizard" else {"warrior":"warriors","ranger":"rangers","thief":"thieves"}.get(u.type,"temple"))
	return s.nearest(u.pos,sites)
static func sponsor(s,u) -> bool:
	if u==null or u.dead or not is_shadow(u) or u.journey.recovery_site>0 or s.result!="" or s.gold<RECOVERY_COST: return false
	var site=recovery_site(s,u)
	if site==null: return false
	s.gold-=RECOVERY_COST; site.tax+=RECOVERY_COST
	u.journey.recovery_site=site.id; u.journey.recovery_progress=0.0; u.journey.recovery_at=s.time
	u.journey.leisure_place=0; u.journey.leisure_until=0; u.goal=0; u.target=0; s.stop(u); u.think=0
	remember(s,u,"The king funded "+PRACTICES[u.type].to_lower()+" at "+site.site_name+".")
	s.notify(u.name+" has royal support. Recovery requires safe time at "+site.site_name+".")
	return true
static func restore_persona(s,u) -> void:
	var j: Dictionary=u.journey
	j.entered+=s.time-j.shadow_since; j.aspect="persona"; j.recovery_site=0; j.recovery_progress=0.0; j.returned=-1
	u.goal=0; u.target=0; s.stop(u)
	remember(s,u,"Persona restored through royal support. Experience retained; another defeat can awaken Shadow.")
	s.Settlement.event(s,"journey",u,"Persona restored · "+PRACTICES[u.type]); s.notify(u.name+" has found their purpose again.")
	if j.stage in COMMITTED: change(s,u,"refusal","Ready to reconsider the interrupted call with support.")
	elif j.calling>0 and active_flag(s,u)==null: clear_call(s,u,"The old offer ended. Ready for a new call.")
static func remember(s,u,reason: String) -> void:
	u.journey.history.append({"at":s.time,"stage":u.journey.stage,"aspect":u.journey.aspect,"reason":reason})
	if u.journey.history.size()>16: u.journey.history.pop_front()
	var archive: Dictionary=s.run.get("heroes",{}).get(str(u.id),{})
	if not archive.is_empty(): archive.journey=u.journey.duplicate(true)
static func change(s,u,stage: String,reason: String) -> void:
	if u.journey.is_empty() or u.journey.stage==stage: return
	u.journey.stage=stage; u.journey.entered=s.time
	remember(s,u,reason); s.Settlement.event(s,"journey",u,STAGES[stage]+" · "+reason)
	s.notify(u.name+" — "+STAGES[stage]+". "+reason)
static func home(s,u):
	var b=s.entity(u.home)
	return b if b!=null and not b.dead else s.palace()
static func active_flag(s,u):
	var f=s.entity(int(u.journey.get("calling",0)))
	if f==null or f.kind!="flag" or f.dead: return null
	var target=s.entity(f.target)
	return null if f.type=="attack" and (target==null or target.dead) else f
static func matches(s,u,f) -> bool:
	if f.dead: return false
	var target=s.entity(f.target)
	if f.type=="attack" and (target==null or target.dead or target.infestation): return false
	match u.type:
		"warrior": return f.type=="attack" and (target.kind=="building" or target.type=="troll")
		"ranger": return f.type=="explore"
		"wizard": return f.type=="attack" and (target.type=="graveyard" or target.id==s.mission.boss_id)
		"thief": return f.type=="explore" or f.type=="attack" and target.hp<=target.max_hp*0.65
	return false
static func worthy(s,f) -> bool:
	var target=s.entity(f.target)
	return f.reward>=150 or target!=null and target.max_hp>=500
static func gates(s,u) -> Dictionary:
	var f=active_flag(s,u)
	var allies: int=s.units.filter(func(other):return other.hero and not other.dead and not is_shadow(other) and other.id!=u.id and other.hp>=other.max_hp*0.6 and other.pos.distance_to(u.pos)<10).size()
	var safety: bool=u.potions.healing>0 or s.operating("temple").any(func(b):return s.pos(b).distance_to(u.pos)<12)
	var premium: bool=f!=null and f.reward>=150
	return {"healthy":u.hp>=u.max_hp*0.6,"allies":allies,"safety":safety,"premium":premium,"ready":u.hp>=u.max_hp*0.6 and (allies>0 or safety or premium)}
static func start_call(s,u,f) -> void:
	var j: Dictionary=u.journey; var target=s.entity(f.target)
	j.calling=f.id; j.target=f.target; j.kind=f.type; j.objective=target.site_name if target!=null and target.kind=="building" else target.name if target!=null else "Explore the marked frontier"
	j.destination=[f.x,f.y]; j.departure=[u.pos.x,u.pos.y]; j.returned=-1
	change(s,u,"call","Considering "+j.objective+".")
static func clear_call(s,u,reason: String) -> void:
	u.journey.calling=0; u.journey.target=0; u.journey.kind=""; u.journey.objective=""; u.goal=0; u.target=0; s.stop(u)
	change(s,u,"mastery" if u.journey.cycles>0 else "ordinary",reason)
static func update(s,u) -> void:
	if u.journey.is_empty() or u.dead: return
	var j: Dictionary=u.journey
	if is_shadow(u):
		var site=s.entity(int(j.recovery_site))
		if j.recovery_site>0 and (site==null or site.dead or site.progress<1):
			j.recovery_site=0; j.recovery_progress=0.0; remember(s,u,"Recovery site was lost. Royal support is needed again.")
		return
	if j.stage=="return": return
	if j.stage in ["ordinary","mastery"]:
		var offers: Array=s.flags.values().filter(func(f):return matches(s,u,f) and (j.stage!="mastery" or worthy(s,f)))
		offers.sort_custom(func(a,b):return u.pos.distance_squared_to(s.pos(a))<u.pos.distance_squared_to(s.pos(b)))
		if not offers.is_empty(): start_call(s,u,offers[0])
		return
	var f=active_flag(s,u)
	if f==null: clear_call(s,u,"The offer ended. Looking for another call."); return
	if j.stage=="call":
		if s.time-j.entered>=j.deliberation: change(s,u,"refusal","Needs confidence before committing.")
	elif j.stage=="refusal":
		if gates(s,u).ready:
			j.departure=[u.pos.x,u.pos.y]; change(s,u,"threshold","Accepted the call with the kingdom’s support.")
	elif j.stage=="threshold":
		if u.pos.distance_to(Vector2(j.departure[0],j.departure[1]))>=2 or u.pos.distance_to(s.pos(f))<3: change(s,u,"tests","On the road to the calling objective.")
	elif j.stage=="tests":
		var target=s.entity(j.target)
		var reach: float=2 if target==null else u.definition.range+(target.size*0.45 if target.kind=="building" else 0)+1
		if u.pos.distance_to(s.pos(f))<=reach: change(s,u,"ordeal","Facing the calling objective.")
static func wounded(s,u) -> void:
	if u.journey.is_empty() or u.dead or u.hp>=u.max_hp*0.2: return
	var j: Dictionary=u.journey
	if is_shadow(u):
		if j.recovery_site>0:
			j.recovery_site=0; j.recovery_progress=0.0; remember(s,u,"Another crushing blow interrupted recovery. Needs renewed royal support.")
		return
	j.aspect="shadow"; j.shadow_since=s.time; j.shadow_count+=1; j.recovery_site=0; j.recovery_progress=0.0
	j.leisure_place=0; j.leisure_until=0; u.goal=0; u.target=0; u.pending_attack={}; u.think=0; s.stop(u)
	remember(s,u,"A crushing defeat interrupted "+STAGES[j.stage]+". Withdrew into "+SHADOWS[u.type]+".")
	s.Settlement.event(s,"journey",u,"Shadow · "+SHADOWS[u.type]+". Needs the king’s intervention.")
	s.notify(u.name+" has fallen into Shadow — "+SHADOWS[u.type]+". Open Hero Journeys to help.","danger")
static func finish(s,u) -> void:
	if is_shadow(u) or u.journey.stage not in COMMITTED: return
	u.goal=0; u.target=0; u.journey.returned=-1; s.stop(u); change(s,u,"return","The objective is won. Returning home changed.")
static func killed(s,e) -> void:
	if s.run.is_empty(): return
	if e.kind=="unit" and e.hero and not e.journey.is_empty():
		remember(s,e,"Fell during "+STAGES[e.journey.stage]+"."); return
	if not e.hostile: return
	for u in s.units:
		if not u.hero or u.dead or u.journey.is_empty(): continue
		if u.journey.target==e.id and u.journey.stage in COMMITTED and not is_shadow(u):
			if u.pos.distance_to(s.pos(e))<12: finish(s,u)
			else: clear_call(s,u,"Others completed the objective before they arrived.")
static func explored(s,u,f) -> void:
	if u.journey.is_empty(): return
	if is_shadow(u): return
	if u.journey.calling==f.id and u.journey.stage in COMMITTED:
		if u.journey.stage!="ordeal": change(s,u,"ordeal","Reached the calling destination.")
		finish(s,u)
static func bravery(u) -> float:
	if is_shadow(u): return 0.1
	return float({"ordinary":0.5,"call":0.7,"refusal":0.4,"threshold":1.3,"tests":1.2,"ordeal":1.5,"return":1.4,"shadow":0.3,"mastery":1.6}.get(u.journey.get("stage",""),1.0))
static func retreat_threshold(u) -> float:
	if is_shadow(u): return 0.6
	return float({"ordinary":0.45,"call":0.39,"refusal":0.54,"threshold":0.21,"tests":0.24,"ordeal":0.15,"return":0.27,"shadow":0.6,"mastery":0.18}.get(u.journey.get("stage",""),0.3))
static func allows(s,u,f) -> bool:
	if u.journey.is_empty(): return true
	var j: Dictionary=u.journey
	if is_shadow(u): return false
	if j.stage in ["call","refusal"] and f.id==j.calling: return false
	if j.stage in COMMITTED: return f.id==j.calling
	if j.stage=="mastery": return worthy(s,f)
	return true
static func override_behavior(s,u) -> bool:
	if u.journey.is_empty(): return false
	var j: Dictionary=u.journey
	if is_shadow(u):
		u.goal=0; u.target=0
		var site=s.entity(int(j.recovery_site))
		if site!=null and not site.dead and site.progress==1:
			var elapsed: float=clampf(s.time-j.recovery_at,0,1); j.recovery_at=s.time
			if u.pos.distance_to(s.pos(site))>=3.5: s.go(u,s.pos(site),"Seeking royal support"); return true
			s.stop(u); u.state=PRACTICES[u.type]
			if u.hp>=u.max_hp*0.6 and s.nearby(u.pos,6,true).is_empty(): j.recovery_progress+=elapsed
			if j.recovery_progress>=RECOVERY_SECONDS: restore_persona(s,u)
			return true
		s.Court.leisure(s,u)
		return true
	if j.stage=="return":
		var base=home(s,u)
		if u.pos.distance_to(s.pos(base))>=3.5: s.go(u,s.pos(base),"Returning from the ordeal"); return true
		s.stop(u); u.state="Reflecting on the journey"; u.hp=minf(u.max_hp,u.hp+7)
		if j.returned<0: j.returned=s.time
		if s.time-j.returned>=15 and u.hp>=u.max_hp*0.86:
			j.cycles+=1; change(s,u,"mastery","Completed a journey. Stronger, and more selective about offers.")
		return true
	if j.stage in ["call","refusal"]:
		s.Court.leisure(s,u)
		return true
	return false
static func describe(s,u) -> Dictionary:
	var j: Dictionary=u.journey
	var out={"stage":"Standalone","key":"legacy","category":"other","objective":"No settlement journey","next":"Levels and equipment are available in the journal.","action":"journal","cycles":0,"aspect":"persona"}
	if j.is_empty(): return out
	out.stage=STAGES[j.stage]; out.key=j.stage; out.cycles=j.cycles; out.aspect=j.aspect; out.objective=j.objective if j.objective!="" else "Awaiting a calling bounty"
	if is_shadow(u):
		out.stage="Shadow · "+SHADOWS[u.type]; out.key="shadow"; out.category="shadow"
		out.objective="Defeated during "+STAGES[j.stage]+(" · "+j.objective if j.objective!="" else "")
		var behavior: String={"warrior":"Refuses combat.","ranger":"Refuses exploration.","wizard":"Withholds spells.","thief":"Refuses bounties and guild theft."}[u.type]
		var site=recovery_site(s,u)
		out.action="support" if site!=null else "temple" if u.type=="wizard" else {"warrior":"warriors","ranger":"rangers","thief":"thieves"}[u.type]
		out.next=behavior+" Needs royal support: "+PRACTICES[u.type].to_lower()+" · 80g, then 25s safe at the site with 60% health. Healing or leisure alone cannot restore Persona."
		if j.recovery_site>0:
			out.action="recovery_site"; out.next=behavior+" Royal support funded · %ds safe practice remaining. Needs 60%% health. Interrupted journey and experience are retained."%ceili(RECOVERY_SECONDS-j.recovery_progress)
		return out
	out.category="quest" if j.stage in COMMITTED else "recovery" if j.stage in ["shadow","return"] else "mastery" if j.stage=="mastery" else "help"
	match j.stage:
		"ordinary","mastery":
			out.next={"warrior":"Post an attack bounty on a lair or troll.","ranger":"Post an exploration bounty on a useful frontier approach.","wizard":"Post an attack bounty on a graveyard, the monastery or Warlord.","thief":"Post an exploration bounty, or target a foe below 65% health."}.get(u.type,"")
			if j.stage=="mastery": out.next+=" Worthy offers need 150g or a target with 500+ maximum health."
			out.action="explore" if u.type in ["ranger","thief"] else "attack"
		"call": out.next="Considering the call · %ds remaining. Prepare an ally, healing or a 150g reward."%maxi(0,ceili(j.deliberation-(s.time-j.entered))); out.action="call"
		"refusal":
			var g=gates(s,u)
			out.next=("Health ready. " if g.healthy else "Recover to 60% health. ")+"One support condition: ally nearby (%d), healing (%s), or 150g bounty (%s)."%[g.allies,"ready" if g.safety else "missing","ready" if g.premium else "missing"]
			if g.ready: out.next="Support is ready. They will commit on their next decision."
			out.action="raise" if not g.premium else "call"
		"threshold","tests": out.next="They have committed. Keep the route safe; allies and healing help them reach the objective."; out.action="call"
		"ordeal": out.next="Facing the objective. A crushing defeat below 20% health awakens Shadow; nearby heroes share the victory."; out.action="call"
		"return": out.next="Returning to "+home(s,u).site_name+". Recover and reflect there for 15s to reach Mastery."; out.action="home"
	return out
static func valid(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	if (value.get("version")!=1 and value.get("version")!=2) or not STAGES.has(value.get("stage","")): return false
	if value.version==2:
		if value.stage=="shadow" or value.get("aspect") not in ["persona","shadow"]: return false
		for key in new_fields():
			if key=="aspect": continue
			var n=value.get(key)
			if typeof(n) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(n)) or n<0: return false
			if key in ["recovery_site","leisure_place","shadow_count"] and n!=floorf(n): return false
		if value.recovery_progress>RECOVERY_SECONDS or value.aspect=="persona" and value.recovery_site!=0: return false
	for key in ["entered","cycles","calling","target","deliberation","returned","recovery_tasks","explored","temples","research","offer_marker"]:
		var number=value.get(key)
		if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)): return false
		if float(number)<(-1.0 if key=="returned" else 0.0): return false
		if key not in ["entered","returned"] and number!=floorf(number): return false
	if value.deliberation<30 or value.deliberation>90 or value.cycles>10000: return false
	for key in ["kind","objective"]:
		if not value.get(key) is String or value[key].length()>300: return false
	if value.kind not in ["","attack","explore"]: return false
	for key in ["destination","departure"]:
		if not value.get(key) is Array or value[key].size()!=2: return false
		for number in value[key]:
			if typeof(number) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(number)) or number<0 or number>=88: return false
	if not value.get("history") is Array or value.history.size()>16: return false
	for event in value.history:
		if not event is Dictionary or not STAGES.has(event.get("stage","")) or not event.get("reason") is String or event.reason.length()>500: return false
		var at=event.get("at")
		if typeof(at) not in [TYPE_FLOAT,TYPE_INT] or not is_finite(float(at)) or at<0: return false
	return true
