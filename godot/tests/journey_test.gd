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
	u.pos=s.pos(J.home(s,u)); J.override_behavior(s,u); s.time+=15; J.override_behavior(s,u)
	check(u.journey.stage=="mastery" and u.journey.cycles==1,"Homecoming and reflection finish a journey exactly once")
	var damage: float=s.Supplies.damage(s,u); J.override_behavior(s,u)
	check(u.journey.cycles==1 and s.Supplies.damage(s,u)==damage,"Mastery does not repeatedly award its completed-cycle bonus")
	check(J.bravery(u)>1 and J.retreat_threshold(u)<0.3,"Mastery affects courage and self-preservation")
	var weak=s.add_unit("goblin",s.near_point(s.pos(s.palace())))
	var easy=s.place_flag("attack",weak.pos,weak.id,100)
	check(not J.allows(s,u,easy) and J.allows(s,u,rival),"Mastery refuses petty offers while allowing worthy ones")
	s.hurt(u,999999,null); var record=s.run.heroes[str(u.id)]
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
		check(u.journey.stage=="ordeal",type+" can reach a real calling ordeal")
		s.hurt(u,u.max_hp*0.85,null)
		check(u.journey.stage=="shadow" and J.describe(s,u).category=="recovery",type+" has a failure branch after an ordeal")
		u.hp=u.max_hp
		match type:
			"warrior":
				check(not J.allows(s,u,s.place_flag("attack",s.pos(s.lairs()[0]),s.lairs()[0].id)),"Warrior Shadow refuses combat offers")
				for i in 2:
					var task=s.place_flag("explore",u.pos,0); task.dead=true; J.explored(s,u,task); J.update(s,u)
					check(u.journey.stage==("shadow" if i==0 else "ordinary"),"Warrior rebuilds confidence after %d small tasks"%(i+1))
			"ranger":
				J.update(s,u); check(u.journey.stage=="shadow","Ranger needs newly revealed ground")
				s.reveal(Vector2(5,5),8); J.update(s,u)
			"wizard":
				check(not s.Magic.wizard_cast(s,u,"heal",u.pos),"Wizard Shadow withholds automatic spells")
				s.add_building("temple",s.find_site("temple")); J.update(s,u)
			"thief":
				J.update(s,u); check(u.journey.stage=="shadow","Thief needs a newly posted suitable offer")
				s.place_flag("explore",s.near_point(u.pos),0); J.update(s,u)
		check(u.journey.stage=="ordinary",type+" recovers through its own kingdom condition")

	s=fresh(); u=hero(s); f=s.place_flag("attack",s.pos(s.lairs()[0]),s.lairs()[0].id); J.update(s,u)
	var ally=hero(s,"ranger"); ally.pos=u.pos+Vector2.ONE
	check(J.gates(s,u).allies==1 and J.gates(s,u).ready,"Healthy nearby allies satisfy the support gate")
	ally.hp=1; check(not J.gates(s,u).ready,"A critically wounded ally cannot provide confidence")
	u.potions.healing=1; check(J.gates(s,u).safety and J.gates(s,u).ready,"Carried healing supplies satisfy the support gate")
	u.potions.healing=0; var temple=s.add_building("temple",s.find_site("temple")); u.pos=s.pos(temple)
	check(J.gates(s,u).safety,"A nearby operating Temple is a safety net")
	partial=save(s)
	for field in ["stage","cycles","history","destination"]:
		var bad=partial.duplicate(true); var h=bad.units.filter(func(item):return item.hero)[0]
		h.journey[field]="corrupt"
		var before=save(cloned); check(not cloned.restore(bad) and save(cloned)==before,"Malformed journey "+field+" is rejected before mutation")
	for field in ["entered","returned","calling"]:
		var bad=partial.duplicate(true); var h=bad.units.filter(func(item):return item.hero)[0]
		h.journey[field]=bad.next_id+1000 if field=="calling" else bad.time+1000
		var before=save(cloned); check(not cloned.restore(bad) and save(cloned)==before,"Impossible journey "+field+" cannot strand a loaded hero")
	var old=partial.duplicate(true)
	for item in old.units: item.erase("journey")
	for h in old.run.heroes.values(): h.erase("journey")
	check(cloned.restore(old) and cloned.entity(u.id).journey.stage=="ordinary","Earlier settlement saves receive journey tracking safely")
	check(cloned.entity(u.id).journey.history[0].reason.contains("saved settlement"),"Migration does not invent prior journey accomplishments")
	var legacy=S.new(); u=hero(legacy); check(u.journey.is_empty() and J.allows(legacy,u,easy),"Standalone rules and heroes retain legacy behavior")
	print("Journey checks: ",checks," / failures: ",failures.size())
	var file=FileAccess.open("res://reports/journey-systems.json",FileAccess.WRITE); file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty()},"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
