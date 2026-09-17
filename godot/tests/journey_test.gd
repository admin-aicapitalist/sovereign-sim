extends SceneTree
const S=preload("res://scripts/simulation.gd")
const J=preload("res://scripts/journey.gd")
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func fresh():
	var s=S.new(); s.start_settlement(s.Settlement.config(41972)); s.gold=10000; return s
func hero(s,type: String="warrior"):
	var guild=s.add_building({"warrior":"warriors","ranger":"rangers","wizard":"wizards","thief":"thieves"}[type],s.find_site({"warrior":"warriors","ranger":"rangers","wizard":"wizards","thief":"thieves"}[type]))
	return s.recruit(guild.id)
func save(s) -> Dictionary: return JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
func commit_call(s,u,f) -> void:
	J.update(s,u); s.time+=u.journey.deliberation; J.update(s,u)
	if f.reward<150: s.raise_bounty(f.id)
	J.update(s,u)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=fresh(); var u=hero(s); var lair=s.lairs()[0]; var f=s.place_flag("attack",s.pos(lair),lair.id)
	check(u.journey.stage=="ordinary" and u.journey.history.size()==1,"New hero begins an actual journey")
	var gold: float=s.gold; var rng: int=s.rng.state
	J.describe(s,u); J.gates(s,u)
	check(s.gold==gold and s.rng.state==rng and u.journey.stage=="ordinary","Reading the overview does not alter simulation state")
	J.update(s,u)
	check(u.journey.stage=="call" and u.journey.calling==f.id,"Archetype notices a matching calling bounty")
	check(u.journey.deliberation>=30 and u.journey.deliberation<=90 and not J.allows(s,u,f),"Call has deterministic deliberation and cannot be accepted early")
	s.time+=u.journey.deliberation-1; J.update(s,u); check(u.journey.stage=="call","Call waits for its full deliberation period")
	s.time+=1; J.update(s,u); check(u.journey.stage=="refusal","Call becomes refusal before commitment")
	check(not J.gates(s,u).ready and J.describe(s,u).next.contains("150g"),"Unsupported refusal exposes its real support conditions")
	s.time+=20; J.update(s,u); check(u.journey.stage=="refusal","Waiting alone cannot bypass missing support")
	u.hp=u.max_hp*0.4; s.raise_bounty(f.id); J.update(s,u)
	check(u.journey.stage=="refusal" and not J.gates(s,u).healthy,"Gold cannot bypass the health requirement")
	u.hp=u.max_hp; J.update(s,u)
	check(u.journey.stage=="threshold" and J.allows(s,u,f),"Health and bounty premium cause commitment")
	var rival=s.place_flag("explore",s.near_point(s.pos(s.palace())),0,300)
	check(not J.allows(s,u,rival),"Committed heroes stay focused on their calling bounty")
	u.pos+=Vector2(3,0); J.update(s,u); check(u.journey.stage=="tests","Leaving home advances to Tests & Allies")
	u.pos=s.pos(lair); J.update(s,u); check(u.journey.stage=="ordeal","Reaching the actual target starts the ordeal")
	var cloned=S.new(); check(cloned.restore(save(s)) and JSON.parse_string(JSON.stringify(cloned.entity(u.id).journey,"",true,true))==JSON.parse_string(JSON.stringify(u.journey,"",true,true)),"Journey stage, call and history survive JSON save/load")
	s.hurt(lair,999999,u); check(u.journey.stage=="return","Winning the calling objective causes Reward & Return")
	u.pos=s.Shelter.door(s,J.home(s,u)); J.override_behavior(s,u); s.time+=15; J.override_behavior(s,u)
	check(u.journey.stage=="mastery" and u.journey.cycles==1,"Homecoming and reflection finish a journey exactly once")
	var damage: float=s.Supplies.damage(s,u); J.override_behavior(s,u)
	check(u.journey.cycles==1 and s.Supplies.damage(s,u)==damage,"Mastery does not repeatedly award its completed-cycle bonus")
	check(J.bravery(u)>1 and J.retreat_threshold(u)<0.3,"Mastery affects courage and self-preservation")
	var weak=s.add_unit("goblin",s.near_point(s.pos(s.palace())))
	var easy=s.place_flag("attack",weak.pos,weak.id,100)
	check(not J.allows(s,u,easy) and J.allows(s,u,rival),"Mastery refuses petty offers while allowing worthy ones")
	s.Shelter.leave(s,u); s.hurt(u,999999,null); var record=s.run.heroes[str(u.id)]
	check(record.dead and record.journey.stage=="mastery" and record.journey.cycles==1,"Fallen heroes retain their final journey in the all-hero archive")
	s.tick(3); check(s.run.heroes[str(u.id)].journey.history[-1].reason.contains("Fell"),"Death history survives actor cleanup")

	s=fresh(); u=hero(s); lair=s.lairs()[0]; f=s.place_flag("attack",s.pos(lair),lair.id)
	J.update(s,u); var partial=save(s); cloned=S.new(); check(cloned.restore(partial),"An in-progress deliberation restores")
	s.time+=u.journey.deliberation; cloned.time=s.time; J.update(s,u); J.update(cloned,cloned.entity(u.id))
	check(JSON.parse_string(JSON.stringify(cloned.entity(u.id).journey))==JSON.parse_string(JSON.stringify(u.journey)),"Restored deliberation reaches the same refusal without rerolling")
	s.cancel_bounty(f.id); J.update(s,u); check(u.journey.stage=="ordinary" and u.journey.calling==0,"Cancelled calling offers cannot strand a journey")

	for type in ["warrior","ranger","wizard","thief"]:
		s=fresh(); u=hero(s,type)
		var target=s.building(s.mission.encounter_id)
		f=s.place_flag("explore",s.near_point(s.pos(s.palace())),0) if type in ["ranger","thief"] else s.place_flag("attack",s.pos(target),target.id)
		commit_call(s,u,f); u.pos=s.pos(f); J.update(s,u); J.update(s,u)
		check(u.journey.stage=="ordeal",type+" reaches a calling ordeal")
		s.hurt(u,u.max_hp*0.9,null)
		check(J.is_shadow(u) and u.journey.stage=="ordeal" and J.describe(s,u).category=="shadow",type+" defeat interrupts its journey with persistent Shadow")
		u.hp=u.max_hp; s.time+=180
		s.reveal(Vector2(5,5),8); s.add_building("temple",s.find_site("temple")); s.place_flag("explore",s.near_point(u.pos),0)
		J.update(s,u)
		check(J.is_shadow(u) and not J.allows(s,u,f),type+" cannot escape Shadow through time, healing, new buildings, maps or bounties")
		if type=="wizard": check(not s.Magic.wizard_cast(s,u,"heal",u.pos),"Shadow Wizard withholds spells")
		var healthy_save=save(s); cloned=S.new()
		check(cloned.restore(healthy_save) and J.is_shadow(cloned.entity(u.id)),type+" remains in Shadow after full-health reload")
		gold=s.gold; check(J.sponsor(s,u) and s.gold==gold-J.RECOVERY_COST and J.is_shadow(u),type+" king funds recovery without instant cure")
		check(not J.sponsor(s,u) and s.gold==gold-J.RECOVERY_COST,type+" cannot be charged twice for recovery")
		var site=s.entity(u.journey.recovery_site); u.pos=s.Shelter.door(s,site); u.hp=u.max_hp*0.5
		for i in 4: s.time+=1; J.override_behavior(s,u)
		check(u.journey.recovery_progress==0,type+" recovery waits for physical health")
		u.hp=u.max_hp
		for i in 12: s.time+=1; J.override_behavior(s,u)
		cloned=S.new(); check(cloned.restore(save(s)) and cloned.entity(u.id).journey.recovery_progress==12,type+" saves funded recovery progress")
		for i in 13: s.time+=1; J.override_behavior(s,u)
		check(not J.is_shadow(u) and u.journey.stage=="refusal" and u.journey.calling==f.id,type+" restores Persona and reconsiders the interrupted call")
		u.journey.cycles=2; J.change(s,u,"mastery","Experienced veteran"); s.hurt(u,u.max_hp*0.9,null)
		check(J.is_shadow(u) and u.journey.cycles==2 and u.journey.stage=="mastery" and u.journey.shadow_count==2,type+" can relapse from Mastery without losing experience")
		check(J.sponsor(s,u),type+" can receive new support after relapse")
		s.hurt(site,999999,null); J.update(s,u)
		check(J.is_shadow(u) and u.journey.recovery_site==0,type+" lost recovery site requires renewed intervention")

	economy_checks()

	s=fresh(); u=hero(s); f=s.place_flag("attack",s.pos(s.lairs()[0]),s.lairs()[0].id); J.update(s,u)
	var ally=hero(s,"ranger"); ally.pos=u.pos+Vector2.ONE
	check(J.gates(s,u).allies==1 and J.gates(s,u).ready,"Healthy nearby allies satisfy the support gate")
	ally.journey.aspect="shadow"; check(not J.gates(s,u).ready,"A healthy Shadow hero cannot offer combat confidence"); ally.journey.aspect="persona"
	ally.hp=1; check(not J.gates(s,u).ready,"A critically wounded ally cannot provide confidence")
	u.potions.healing=1; check(J.gates(s,u).safety and J.gates(s,u).ready,"Carried healing supplies satisfy the support gate")
	u.potions.healing=0; var temple=s.add_building("temple",s.find_site("temple")); u.pos=s.pos(temple)
	check(J.gates(s,u).safety,"A nearby operating Temple is a safety net")
	partial=save(s)
	for field in ["stage","cycles","history","destination","aspect","recovery_progress","leisure_until"]:
		var bad=partial.duplicate(true); var h=bad.units.filter(func(item):return item.hero)[0]
		h.journey[field]="corrupt"
		var before=save(cloned); check(not cloned.restore(bad) and save(cloned)==before,"Malformed journey "+field+" is rejected before mutation")
	for field in ["entered","returned","calling"]:
		var bad=partial.duplicate(true); var h=bad.units.filter(func(item):return item.hero)[0]
		h.journey[field]=bad.next_id+1000 if field=="calling" else bad.time+1000
		var before=save(cloned); check(not cloned.restore(bad) and save(cloned)==before,"Impossible journey "+field+" cannot strand a loaded hero")
	var v1=partial.duplicate(true)
	for item in v1.units:
		if item.hero:
			item.journey.version=1; item.journey.stage="shadow"
			for key in J.new_fields(): item.journey.erase(key)
	check(cloned.restore(v1) and J.is_shadow(cloned.entity(u.id)) and cloned.entity(u.id).journey.version==2,"Version-one Shadow migrates without becoming Persona")
	var old=partial.duplicate(true)
	for item in old.units: item.erase("journey")
	for h in old.run.heroes.values(): h.erase("journey")
	check(cloned.restore(old) and cloned.entity(u.id).journey.stage=="ordinary","Earlier settlement saves receive journey tracking safely")
	check(cloned.entity(u.id).journey.history[0].reason.contains("saved settlement"),"Migration does not invent prior journey accomplishments")
	var legacy=S.new(); u=hero(legacy); check(u.journey.is_empty() and J.allows(legacy,u,easy),"Standalone rules and heroes retain legacy behavior")
	print("Journey checks: ",checks," / failures: ",failures.size())
	var file=FileAccess.open("res://reports/journey-systems.json",FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty()},"\t")+"\n")
	quit(0 if failures.is_empty() else 1)

func economy_checks() -> void:
	var s=fresh(); var patron=hero(s); var thief=hero(s,"thief")
	var inn=s.add_building("inn",s.find_site("inn")); var brothel=s.add_building("brothel",s.find_site("brothel"))
	patron.gold=200; s.hurt(patron,patron.max_hp*0.9,null); patron.hp=patron.max_hp
	patron.pos=s.Shelter.door(s,inn); patron.journey.leisure_place=inn.id
	var treasury: float=s.gold; s.Court.leisure(s,patron)
	check(patron.gold==192 and inn.tax==8 and s.gold==treasury and J.is_shadow(patron),"Inn transfers personal spending into local taxes without curing Shadow")
	s.Court.leisure(s,patron); check(patron.gold==192,"A continuing visit does not charge every decision")
	s.Shelter.leave(s,thief); thief.pos=s.Shelter.door(s,s.building(patron.inside)); var purse: float=thief.gold
	check(s.Court.thieve(s,thief),"Idle thief picks a real nearby patron’s pocket")
	check(patron.gold==172 and thief.gold==purse+10 and s.Court.bank(s,thief.home)==10,"Theft conserves gold: half to thief, half to own guild bank")
	check(not s.Court.thieve(s,thief) and patron.gold==172,"Theft cooldown prevents repeated immediate theft")
	check(s.Court.confiscate(s,thief.home) and s.gold==treasury+10 and s.Court.bank(s,thief.home)==0,"King transfers guild bank to treasury")
	var ready: float=s.run.court.confiscate_ready
	check(not s.Court.confiscate(s,thief.home) and s.run.court.confiscate_ready==ready,"Empty or cooling-down seizure cannot duplicate money or reset cooldown")
	s.time+=31; s.Shelter.leave(s,patron); patron.pos=s.Shelter.door(s,brothel); patron.journey.leisure_place=brothel.id; s.Court.leisure(s,patron)
	check(patron.gold==158 and brothel.tax==14 and patron.state=="Visiting the Brothel","Brothel charges its own fee from a new physical visit")
	s.Shelter.leave(s,thief); thief.pos=s.Shelter.door(s,s.building(patron.inside)); s.Court.thieve(s,thief)
	var second=hero(s,"thief"); second.pos=s.Shelter.door(s,brothel); s.Court.thieve(s,second)
	check(s.Court.bank(s,second.home)>0 and not s.Court.confiscate(s,second.home),"A second guild cannot bypass the kingdom-wide seizure cooldown")
	var data=save(s); var restored=S.new(); check(restored.restore(data),"Court ledger and visit state restore")
	check(restored.Court.bank(restored,thief.home)==s.Court.bank(s,thief.home) and restored.Court.wait_time(restored)==s.Court.wait_time(s),"Bank balances and seizure cooldown survive reload")
	check(not restored.Court.thieve(restored,restored.entity(thief.id)),"Reload cannot bypass a thief’s cooldown")
	for key in ["stolen","confiscate_ready","banks"]:
		var bad=data.duplicate(true); bad.run.court[key]=-1
		var before=save(restored); check(not restored.restore(bad) and save(restored)==before,"Corrupt court "+key+" rejected atomically")
	s.time=ready; check(s.Court.confiscate(s,thief.home),"King can confiscate again after 120 game seconds")
	patron.gold=0; patron.journey.leisure_until=0; patron.journey.leisure_next=0; s.Court.leisure(s,patron)
	check(patron.gold==0 and J.is_shadow(patron) and not s.Court.patron(s,patron),"Broke heroes linger safely without free visits or negative purses")
	s.Shelter.leave(s,thief); s.hurt(thief,thief.max_hp*0.9,null); thief.hp=thief.max_hp
	check(not s.Court.thieve(s,thief),"Shadow thief also refuses its normal guild work")
	# A hostile beside a healthy Shadow warrior must not provoke voluntary combat.
	s.Shelter.leave(s,patron); patron.pos=s.near_point(s.pos(s.palace()),4); var foe=s.add_unit("goblin",patron.pos+Vector2.ONE); s.rebuild_buckets(); s.Brain.hero(s,patron)
	check(patron.target==0 and J.is_shadow(patron),"Shadow warrior retreats instead of acquiring a nearby combat target")
	check(not J.allows(s,patron,s.place_flag("explore",patron.pos,0)),"Shadow warrior cannot clear its state by taking old exploration tasks")
