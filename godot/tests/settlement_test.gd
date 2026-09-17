extends SceneTree
const S=preload("res://scripts/simulation.gd")
const Rules=preload("res://scripts/settlement_rules.gd")
const Store=preload("res://scripts/settlement_store.gd")
const HeroProgress=preload("res://scripts/hero_progress.gd")
class FaultStore extends "res://scripts/settlement_store.gd":
	var fail_slot: String=""
	func write_slot(slot: String,value: Variant) -> bool:
		if slot==fail_slot: error="Injected storage interruption"; return false
		return super.write_slot(slot,value)
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func snapshot(s) -> Dictionary: return JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
func same(a: Variant,b: Variant) -> bool:
	if a is Dictionary and b is Dictionary:
		if a.size()!=b.size(): return false
		for key in a:
			if not b.has(key) or not same(a[key],b[key]): return false
		return true
	elif a is Array and b is Array:
		if a.size()!=b.size(): return false
		for i in a.size():
			if not same(a[i],b[i]): return false
		return true
	# JSON represents integers as floats and may round cosmetic terrain noise by one ULP.
	if Rules.number(a) and Rules.number(b): return is_equal_approx(a,b)
	return a==b
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=S.new(); var baseline=s.definitions.duplicate(true)
	var c=Rules.config(41972,"guild_compact","rich_ruins")
	check(s.start_settlement(c),"Start a configured settlement")
	check(s.gold==1500 and s.operating("house").size()==3 and s.stats.recruits==0,"Starting kingdom and treasury")
	check(s.definitions.buildings.warriors.cost==298 and s.definitions.buildings.rangers.cost==255,"Guild discount rounds up")
	check(is_equal_approx(s.definitions.buildings.palace.tax,8.1) and s.definitions.units.warrior.cost==100,"Tax tradeoff leaves recruitment prices unchanged")
	check(s.definitions.mission.arrival_delay==90 and s.definitions.mission.slam_warning==2.4,"First-level encounter tuning")
	var frontier=s.lairs().filter(func(b):return Rules.frontier(s,b.id))[0]
	var defender=s.units.filter(func(u):return u.home==frontier.id)[0]
	check(is_equal_approx(defender.max_hp,baseline.units[defender.type].hp*1.1),"Initial frontier defenders receive the condition")
	var future=s.add_unit(defender.type,s.near_point(s.pos(frontier)),frontier.id)
	check(future.max_hp==defender.max_hp,"Later frontier defenders receive the condition")
	var near=s.lairs().filter(func(b):return not Rules.frontier(s,b.id))[0]
	var normal=s.units.filter(func(u):return u.home==near.id)[0]
	check(normal.max_hp==baseline.units[normal.type].hp,"Nearby threats retain normal health")
	var save=snapshot(s); var clone=S.new(7)
	check(save.version==4 and clone.restore(save),"New run save roundtrip")
	check(same(clone.run.config,s.run.config) and same(clone.definitions,s.definitions),"Resolved rules restore once")
	check(clone.entity(defender.id).max_hp==defender.max_hp and clone.entity(defender.id).definition.hp==defender.definition.hp,"Modified actor restores without stacking")
	check(clone.add_unit(future.type,clone.near_point(clone.pos(frontier)),frontier.id).max_hp==future.max_hp,"Future spawns after restore retain condition")
	clone.reset(41972)
	check(clone.run.is_empty() and clone.definitions==baseline and clone.snapshot().version==3,"New standalone game resets all modifiers")
	check(S.Content.definitions()==baseline,"Shared content remains unchanged")
	var damaged=save.duplicate(true); damaged.run.config.rules.charter.tax=-1
	check(not clone.restore(damaged) and clone.run.is_empty(),"Invalid rules rejected before mutation")
	damaged=save.duplicate(true); damaged.version=3
	check(not clone.restore(damaged),"Legacy saves cannot acquire run rewards")
	for key in ["mission","fixture"]:
		damaged=save.duplicate(true); damaged[key]=42
		check(not clone.restore(damaged) and clone.run.is_empty(),"Malformed run "+key+" rejected atomically")
	var old=S.new(2); old.Mission.start(old,"ember_crown")
	check(s.restore(snapshot(old)) and s.run.is_empty() and s.definitions.mission.arrival_delay==30,"Legacy Ember save keeps old tuning")
	check(Rules.record(s).is_empty(),"Standalone saves cannot earn progression")
	var archive:=ZIPReader.new(); archive.open("res://tests/fixtures/legacy-v2-save.zip")
	var legacy: Dictionary=JSON.parse_string(archive.read_file("kingdom-v2.json").get_string_from_utf8()); archive.close()
	check(s.restore(legacy) and s.mission.id=="classic" and s.run.is_empty(),"Immutable v2 save still loads")

	s.start_settlement(Rules.config(41972))
	var monastery=s.building(s.mission.encounter_id)
	s.reveal(s.pos(monastery),3); s.Mission.update(s,0)
	check(s.mission.revealed and s.stats.lairs==0,"Natural discovery bypasses reveal threshold")
	s.start_settlement(Rules.config(41972)); monastery=s.building(s.mission.encounter_id)
	var guild=s.add_building("warriors",s.find_site("warriors")); var hero=s.recruit(guild.id)
	hero.pos=s.near_point(s.pos(monastery))
	s.hurt(monastery,999999,hero)
	check(s.mission.revealed and s.mission.encounter_cleared and s.mission.arrival_remaining==90,"Clearing monastery first starts countdown")
	var relic=s.loot.filter(func(p):return p.items.has("runeblade"))[0]
	hero.pos=s.pos(relic); s.Supplies.collect(s,hero,relic)
	check(s.run.heroes[str(hero.id)].equipment.has("Monastery Runeblade"),"Record factual relic ownership")
	s.Mission.update(s,35); save=snapshot(s); clone=S.new()
	check(clone.restore(save) and clone.mission.arrival_remaining==55,"Countdown survives save and load")
	s.Mission.update(s,55); clone.Mission.update(clone,55)
	check(s.mission.boss_id>0 and clone.mission.boss_id==s.mission.boss_id,"Restored countdown spawns boss once")
	var boss=s.entity(s.mission.boss_id); var id: int=boss.id
	s.Mission.update(s,0); check(s.mission.boss_id==id,"Repeated update cannot respawn the boss")
	boss.hp=boss.max_hp*0.4; s.Mission.update(s,0); var count: int=s.units.size()
	clone.restore(snapshot(s)); clone.Mission.update(clone,0)
	check(clone.units.size()==count and clone.mission.enraged,"Reload cannot duplicate enrage reinforcements")
	hero.pos=boss.pos; s.hurt(boss,999999,hero); s.tick(0.05)
	check(s.result=="victory" and s.lairs().size()==7,"Boss victory leaves optional lairs standing")
	var victory=Rules.record(s)
	check(victory.renown==13 and victory.heroes.any(func(h):return h.boss),"Fast monastery-first victory and recorded participation")
	var elapsed: float=s.time; s.tick(10); check(s.time==elapsed,"Outcome freezes the simulation")
	clone.restore(save); clone.Mission.update(clone,55)
	clone.hurt(clone.entity(clone.mission.boss_id),999999,null); clone.hurt(clone.palace(),999999,null); clone.tick(0.05)
	check(clone.result=="defeat" and Rules.record(clone).renown==5,"Palace defeat wins simultaneous outcome and keeps accomplishments")

	s.start_settlement(Rules.config(41972)); s.result="abandoned"
	check(Rules.record(s).renown==0,"Immediate abandonment earns nothing")
	s.result=""; var lairs=s.lairs()
	for b in lairs: s.hurt(b,999999,null)
	for i in 10:
		var rat=s.add_unit("rat",s.near_point(s.pos(s.palace()))); rat.infestation=true; s.hurt(rat,999999,null)
	s.result="abandoned"; var partial=Rules.record(s)
	check(partial.renown==9,"Optional Renown is capped and renewable enemies earn none")
	var final=partial.duplicate(true); final.outcome="victory"; final.boss=true
	final.awards.append({"label":"Victory","amount":8}); final.renown+=8
	check(Store.valid_record(final),"Maximum 17 Renown record is valid")

	s.start_settlement(Rules.config(41972)); var raider=s.units.filter(func(u):return u.hostile)[0]
	s.units.filter(func(u):return not u.hostile).map(func(u):u.pos=s.pos(s.palace()))
	raider.raider=true; s.time=179; s.rebuild_buckets(); s.Brain.monster(s,raider)
	check(raider.state!="Marching on the Palace","Opening blocks scheduled march")
	s.time=181; s.Brain.monster(s,raider)
	check(raider.state=="Marching on the Palace","Raids begin after the opening")
	s.time=600; s.tick(0.05)
	check(not s.troll_spawned and not s.units.any(func(u):return u.type=="troll"),"Unrelated timed troll is suppressed")
	# Matching loot RNG proves that the bonus affects only the gold roll.
	var rich=S.new(); rich.start_settlement(Rules.config(41972,"crown","rich_ruins"))
	var plain=S.new(); plain.start_settlement(Rules.config(41972))
	frontier=rich.lairs().filter(func(b):return Rules.frontier(rich,b.id))[0]
	var rp=rich.Supplies.drop_loot(rich,frontier); var pp=plain.Supplies.drop_loot(plain,plain.building(frontier.id))
	check(rp.gold==ceili(pp.gold*1.25) and rp.potions==pp.potions,"Rich frontier loot multiplies gold without changing potion rolls")
	var lair=plain.lairs()[0]
	var wizard=plain.add_unit("wizard",plain.pos(lair)+Vector2(1,0))
	var nearby_enemy=plain.add_unit("goblin",plain.pos(lair)+Vector2(0.5,0),lair.id)
	var hp: float=nearby_enemy.hp
	plain.rebuild_buckets(); plain.shoot(wizard,lair,42,"fireball"); plain.update_projectiles(1)
	check(nearby_enemy.hp<hp,"Fireball splash handles a building target and adjacent actors")
	var thief=plain.add_unit("thief",nearby_enemy.pos); nearby_enemy.target=plain.palace().id
	check(plain.Supplies.damage(plain,thief,nearby_enemy)==29,"Thief can exploit a monster attacking a building")
	clone.restore(snapshot(plain)); var loot_count: int=clone.loot.size()
	clone.hurt(clone.lairs()[0],999999,null)
	check(clone.loot.size()>loot_count,"Lair equipment drops after JSON counters are restored")
	storage_checks(final,save)
	hero_checks()
	print("Settlement checks: ",checks," / failures: ",failures.size())
	var file=FileAccess.open("res://reports/settlement-systems.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty()},"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
func hero_checks() -> void:
	var s=S.new(); s.start_settlement(Rules.config(41972))
	var guild=s.add_building("rangers",s.find_site("rangers")); var hero=s.recruit(guild.id)
	check(HeroProgress.context(s,hero).xp_needed==45 and HeroProgress.context(s,hero).advice.contains("exploration bounty"),"New ranger explains XP requirement and class-appropriate offers")
	check(HeroProgress.history(s,hero.id).size()==1 and HeroProgress.history(s,hero.id)[0].contains("Joined"),"Hero journal begins with recorded recruitment")
	hero.pos=s.near_point(s.pos(s.palace())); hero.xp=40; s.rebuild_buckets()
	var flag=s.place_flag("explore",hero.pos,0)
	s.Journey.update(s,hero); s.time+=hero.journey.deliberation; s.Journey.update(s,hero); s.raise_bounty(flag.id); s.Journey.update(s,hero)
	var original_hp: float=hero.max_hp; var damage: float=s.Supplies.damage(s,hero)
	s.Brain.hero(s,hero)
	check(flag.dead and hero.level==2 and hero.xp==15,"Exploration reward levels immediately with correct overflow XP")
	check(hero.max_hp==original_hp+22 and s.Supplies.damage(s,hero)==damage+4,"Displayed next-level stat gains match the simulation")
	check(HeroProgress.context(s,hero).xp_needed==75,"Hero view updates its next-level requirement")
	var history=HeroProgress.history(s,hero.id)
	var milestones=history.filter(func(line):return line.contains("Reached level 2") or line.contains("exploration bounty"))
	check(milestones.size()==2 and milestones[0].contains("Reached level 2") and milestones[1].contains("exploration bounty"),"Journal records exploration and level-up in order")
	hero.pos=s.pos(guild)+Vector2(10,0); hero.hp=hero.max_hp*0.2; hero.state="Seeking adventure"
	s.Brain.hero(s,hero)
	var info=HeroProgress.context(s,hero)
	check(hero.state=="Fleeing" and info.goal.contains(guild.site_name) and info.advice.contains("86%"),"Wounded hero explains retreat and recovery threshold")
	var events: int=s.run.events.size(); s.Brain.hero(s,hero)
	check(s.run.events.size()==events,"Retreat history records transitions without repeating each decision")
	hero.pos=s.pos(guild); s.Brain.hero(s,hero)
	check(hero.state=="Resting" and HeroProgress.history(s,hero.id)[0].contains("Began resting"),"Journal records the actual recovery site")
	hero.hp=hero.max_hp; s.Brain.hero(s,hero)
	check(HeroProgress.history(s,hero.id).any(func(line):return line.contains("Recovered enough")),"Recovery becomes a recorded event")
	var recovered: int=s.run.events.filter(func(event):return event.kind=="recovered").size()
	s.Brain.hero(s,hero)
	check(s.run.events.filter(func(event):return event.kind=="recovered").size()==recovered,"Completed recovery is recorded once")
	var clone=S.new(); check(clone.restore(snapshot(s)),"Hero progress save restores")
	var restored=clone.entity(hero.id)
	check(HeroProgress.history(clone,hero.id)==HeroProgress.history(s,hero.id) and HeroProgress.context(clone,restored).xp_needed==75,"Hero history and progression survive JSON save/load")
	var market=s.add_building("marketplace",s.find_site("marketplace")); hero.state="Buying potions"
	info=HeroProgress.context(s,hero)
	check(info.focus==market.id and info.advice.contains("own purse"),"Shopping guidance names the service and personal money")
	hero.state="Seeking adventure"; hero.goal=0; hero.target=s.lairs()[0].id
	check(HeroProgress.context(s,hero).focus==hero.target,"Combat guidance points to the hero’s actual target")
	hero.target=0; var before: float=hero.xp
	var rat=s.add_unit("rat",hero.pos); rat.infestation=true; s.hurt(rat,999999,hero)
	check(hero.xp==before,"Urban rats cannot advance hero XP")
	s.hurt(hero,999999,null); s.grant_experience(hero,100)
	check(hero.xp==before and s.run.heroes[str(hero.id)].dead,"Fallen heroes retain their history and cannot gain experience")
	var legacy=S.new(); var old=legacy.add_unit("warrior",legacy.near_point(legacy.pos(legacy.palace())))
	check(HeroProgress.history(legacy,old.id).is_empty() and HeroProgress.context(legacy,old).xp_needed==45,"Standalone heroes show progress without inventing past events")
func storage_checks(record: Dictionary, active: Dictionary) -> void:
	var path="/tmp/sovereign-settlement-test-"+Crypto.new().generate_random_bytes(8).hex_encode()
	var store=FaultStore.new(path)
	check(store.initialize() and store.profile.renown==0,"Fresh profile")
	check(not store.purchase("guild_compact"),"Cannot overspend Renown")
	check(store.save_active(active),"Active save persists separately")
	check(same(store.load_active(),active),"Active save checksum roundtrip")
	store.fail_slot="receipt"
	check(not store.complete(record) and store.profile.renown==0,"Receipt failure does not grant progress")
	store.fail_slot="profile"
	check(not store.complete(record) and store.profile.renown==0,"Interrupted profile write leaves reward pending")
	var recovered=Store.new(path)
	check(recovered.initialize() and recovered.profile.renown==17,"Restart recovers pending reward")
	check(recovered.complete(record) and recovered.profile.renown==17,"Repeated completion awards once")
	var alternate=record.duplicate(true); alternate.outcome="abandoned"; alternate.renown=0; alternate.awards=[]
	check(recovered.complete(alternate) and recovered.profile.completed[record.id].outcome=="victory" and recovered.profile.renown==17,"Older save cannot replace a recorded outcome")
	check(recovered.purchase("guild_compact") and recovered.profile.renown==7 and recovered.profile.spent==10,"Purchase persists the tradeoff charter")
	check(not recovered.purchase("guild_compact") and recovered.profile.renown==7,"Duplicate purchase does not spend again")
	check(recovered.set_hint("recruit",false),"Persist hint preferences")
	var restart=Store.new(path)
	check(restart.initialize() and restart.profile.unlocks.has("guild_compact") and restart.profile.hints.has("recruit") and not restart.profile.hints_enabled,"Profile survives a second restart")
	check(restart.complete(record) and restart.profile.renown==7,"Reloaded result cannot refund spent Renown")
	check(same(restart.load_active(),active),"Profile writes preserve active settlement")
	# A damaged primary reads the verified backup; the retained receipt restores its reward.
	var corrupt=FileAccess.open(path+"-profile.json",FileAccess.WRITE); corrupt.store_string("interrupted"); corrupt=null
	var backup=Store.new(path)
	check(backup.initialize() and backup.profile.completed.has(record.id),"Backup plus receipt preserve completed-run identity")
	check(Store.valid_profile(backup.profile),"Recovered profile retains currency accounting")
