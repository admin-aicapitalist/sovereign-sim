extends SceneTree
const Simulation=preload("res://scripts/simulation.gd")
const Supplies=preload("res://scripts/supplies.gd")
const Magic=preload("res://scripts/magic.gd")
const Sanitation=preload("res://scripts/sanitation.gd")
var failures: Array[String]=[]
var checks: int=0
func check(ok: bool,text: String) -> void:
	checks+=1
	if not ok: failures.append(text); push_error(text)
func advance(s,seconds: float) -> void:
	for i in int(seconds*20): s.tick(0.05)
func place(s,type: String,built: bool=false) -> Dictionary:
	var site=s.find_site(type)
	check(site.x>=0,"Site for "+type)
	return s.add_building(type,site,true) if built else s.build(type,site)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var s=Simulation.new()
	check(s.lairs().size()==8,"Eight campaign lairs")
	check(s.lairs().filter(func(b):return b.dormant).size()==4,"Four dormant frontier lairs")
	for b in s.lairs(): check(not s.find_path(s.near_open(s.pos(s.palace())),s.pos(b)).is_empty(),"Reachable "+b.site_name)
	check(s.build("warriors",Vector2i(s.palace().tx,s.palace().ty)).is_empty() and s.gold==1500,"Invalid placement does not charge")
	check(not Magic.cast(s,"lightning",s.pos(s.lairs()[0])),"Unlearned spell rejected")
	advance(s,180)
	check(not s.palace().dead,"Opening survives three unattended minutes")
	check(s.stats.taxes>0,"Collectors deliver taxes")
	print("PASS opening; treasury=",s.gold)

	s.reset(41972); s.gold=10000
	var market=place(s,"marketplace",true); var temple=place(s,"temple",true)
	check(not Supplies.research(s,"strength",market.id),"Advanced potion prerequisites")
	check(Supplies.research(s,"healing",market.id),"Healing research funded")
	market.dead=true; Supplies.update_research(s,60); check(s.alchemy.project.remaining==25,"Research pauses without an operating market")
	market.dead=false; Supplies.update_research(s,25); check(s.alchemy.unlocked.healing,"Healing research completes")
	var hero=s.add_unit("warrior",s.near_point(s.pos(market)),s.palace().id); hero.pos=s.pos(market)+Vector2(1.4,0); hero.gold=100
	var tax: float=market.tax
	check(Supplies.buy(s,hero,market)==2 and hero.gold==64 and market.tax==tax+36,"Personal shopping pays taxable revenue and capacity")
	hero.hp=30; Supplies.update_unit(s,hero,0.05); check(hero.hp==140 and hero.potions.healing==1,"Healing potion auto-use")
	hero.buffs.stoneskin=10; hero.magic_buffs.ward=10
	check(Supplies.armor(s,hero)==16,"Potion and magical armor stack")
	var enemy=s.add_unit("goblin",hero.pos+Vector2(1,0)); var thief=s.add_unit("thief",hero.pos)
	enemy.target=hero.id
	check(Supplies.damage(s,thief,enemy)==29,"Thief distraction bonus")
	check(Magic.research(s,"heal",temple.id),"Temple starts research")
	check(not Magic.research(s,"lightning",temple.id),"One spell study at a time")
	temple.dead=true; Magic.update(s,30); check(s.magic.project.remaining==20,"Temple loss pauses study")
	temple.dead=false; Magic.update(s,20); check(Magic.available(s,"heal"),"Learned spell shared kingdom-wide")
	check(not Magic.research(s,"meteor",temple.id),"Meteor prerequisite")
	s.update_vision(); hero.hp=40
	check(Magic.cast(s,"heal",hero.pos) and hero.hp==170,"Sovereign healing effect")
	check(not Magic.cast(s,"heal",hero.pos),"Sovereign cooldown")
	var wiz=s.add_unit("wizard",hero.pos+Vector2(0,1)); hero.hp=30
	check(Magic.wizard_cast(s,wiz,"heal",hero.pos) and wiz.mana==75,"Wizard mana independent from crown cooldown")
	check(not Magic.wizard_cast(s,wiz,"heal",hero.pos),"Wizard cast gap/cooldown")
	wiz.cast_timer=0; wiz.spell_cooldowns.clear(); wiz.mana=100; hero.hp=30
	var casts: int=s.stats.wizard_spells
	Magic.think(s,wiz)
	check(s.stats.wizard_spells==casts+1 and hero.hp==160,"Wizard autonomously heals a wounded ally")
	for key in s.definitions.spells: s.magic.unlocked[key]=true
	var hp: float=enemy.hp
	check(Magic.cast(s,"meteor",enemy.pos),"Meteor accepted")
	check(enemy.hp==hp,"Meteor damage delayed")
	s.time+=0.66; Magic.update(s,0.66); check(enemy.dead,"Meteor impact applies damage")
	var loot=s.loot[-1]
	hero.pos=s.pos(loot); hero.potions.healing=2; var purse: float=hero.gold
	check(Supplies.collect(s,hero,loot) and hero.gold>purse,"Physical loot goes to personal purse")
	var frost_enemy=s.add_unit("troll",hero.pos+Vector2(1,0)); s.update_vision()
	check(Magic.cast(s,"frost",frost_enemy.pos) and frost_enemy.magic_buffs.frost==6,"Frost damage and timed slow")
	check(Magic.move_multiplier(s,frost_enemy)==0.45 and Magic.attack_multiplier(s,frost_enemy)==0.65,"Frost movement/attack multipliers")
	check(Magic.cast(s,"haste",hero.pos) and hero.magic_buffs.haste==14,"Haste buff")
	s.update_vision(); check(Magic.cast(s,"farsight",Vector2(5,5)) and s.is_explored(Vector2(5,5)),"Far Sight reveals fog")
	var saved: Dictionary=JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
	var restored=Simulation.new(1)
	check(restored.restore(saved),"Restore complete research/magic/loot state onto another map")
	check(restored.fixture.seed==41972 and restored.magic.unlocked==s.magic.unlocked,"Save retains map and research")
	advance(s,2); advance(restored,2)
	check(s.rng.state==restored.rng.state and s.gold==restored.gold and s.stats.hits==restored.stats.hits,"Save simulation continues deterministically")
	for i in s.units.size(): check(s.units[i].pos.distance_to(restored.units[i].pos)<0.001,"Saved actor path continuity")
	var broken=saved.duplicate(true); broken.units[0].pos=["bad"]
	check(not restored.restore(broken),"Malformed save rejected atomically")
	for collection in ["trees","decor"]:
		broken=saved.duplicate(true); broken.fixture[collection]=[{}]
		check(not restored.restore(broken),"Malformed "+collection+" rejected")
	for collection in ["vision","projectiles","effects","ruins"]:
		broken=saved.duplicate(true); broken[collection]=[{}]
		check(not restored.restore(broken),"Malformed "+collection+" rejected")
	broken=saved.duplicate(true); broken.magic.impacts=[{}]
	check(not restored.restore(broken),"Malformed delayed impact rejected")
	broken=saved.duplicate(true); broken.magic.project={"key":"missing","remaining":3,"total":4}
	check(not restored.restore(broken),"Unknown research rejected")
	check(restored.restore(saved),"Valid state still loads after rejecting corrupt saves")
	print("PASS supplies, magic, loot and persistence")

	s.reset(41972); s.gold=10000
	while Sanitation.status(s).cottages<7: place(s,"house",true)
	Sanitation.update(s,59); check(Sanitation.status(s).active==0,"Overcrowding grace period")
	Sanitation.update(s,1); check(Sanitation.status(s).active==1,"Seventh cottage opens a sewer")
	var sewer=s.buildings.filter(func(b):return b.infestation)[0]
	var before: float=s.gold; var loot_count: int=s.loot.size()
	s.hurt(sewer,99999,null)
	for u in s.units:
		if u.infestation: s.hurt(u,99999,null)
	check(s.gold==before and s.loot.size()==loot_count and s.stats.lairs==0,"Infestations cannot farm gold/loot or campaign credit")
	Sanitation.update(s,60); check(Sanitation.status(s).active==1,"Overcrowding recurs")
	var house=s.buildings.filter(func(b):return b.type=="house" and not b.dead)[-1]
	check(s.demolish(house.id) and s.gold==before,"Cottage demolition no refund")
	check(Sanitation.status(s).target==0,"Demolition reduces pressure")
	s.paused=true; var frozen: float=s.time; advance(s,10); check(s.time==frozen,"Pause freezes all systems")
	s.paused=false; s.hurt(s.palace(),99999,null); s.tick(0.05); check(s.result=="defeat","Palace defeat")
	print("PASS sanitation, pause and defeat")

	# Full eight-lair campaign using the same spending policy as the browser smoke test.
	s.reset(41972)
	var warrior_guild=place(s,"warriors"); market=place(s,"marketplace")
	advance(s,45); check(warrior_guild.progress==1 and market.progress==1,"Workers finish real construction")
	for i in 4: check(s.recruit(warrior_guild.id)!=null,"Recruit warrior")
	check(s.recruit(warrior_guild.id)==null,"Guild capacity enforced")
	var ranger_guild=place(s,"rangers"); advance(s,40); check(s.recruit(ranger_guild.id)!=null,"Recruit ranger")
	Supplies.research(s,"healing",market.id)
	var wizard_guild: Dictionary={}; temple={}; var tower: Dictionary={}
	for second in 2400:
		if s.result!="": break
		if s.alchemy.project.is_empty() and s.gold>500:
			for key in ["strength","stoneskin"]:
				if not s.alchemy.unlocked.get(key,false): Supplies.research(s,key,market.id); break
		var alive=s.lairs()
		if not s.flags.values().any(func(f):return not f.dead and f.type=="attack") and not alive.is_empty() and s.gold>=150:
			alive.sort_custom(func(a,b):return s.pos(a).distance_to(s.pos(s.palace()))<s.pos(b).distance_to(s.pos(s.palace())))
			s.place_flag("attack",s.pos(alive[0]),alive[0].id,150)
		if wizard_guild.is_empty() and s.gold>720: wizard_guild=place(s,"wizards")
		if temple.is_empty() and not wizard_guild.is_empty() and s.gold>550: temple=place(s,"temple")
		if not temple.is_empty() and temple.progress==1 and not temple.dead and s.magic.project.is_empty() and s.gold>450:
			for key in ["heal","lightning","ward","frost","haste","meteor"]:
				if not Magic.available(s,key): Magic.research(s,key,temple.id); break
		if tower.is_empty() and s.time>400 and s.gold>350: tower=place(s,"tower")
		for guild in [warrior_guild,ranger_guild,wizard_guild]:
			if guild.is_empty() or guild.dead or guild.progress<1: continue
			var d=s.definition_of(guild)
			if s.gold>s.definitions.units[d.recruits].cost+150: s.recruit(guild.id)
		if Magic.available(s,"heal") and s.cooldowns.heal==0 and s.gold>150:
			var wounded=s.units.filter(func(u):return u.hero and not u.dead and u.hp<u.max_hp*0.45)
			if not wounded.is_empty(): Magic.cast(s,"heal",wounded[0].pos)
		if Magic.available(s,"lightning") and s.cooldowns.lightning==0 and s.gold>300:
			var attack=s.flags.values().filter(func(f):return not f.dead and f.type=="attack")
			if not attack.is_empty(): Magic.cast(s,"lightning",s.pos(attack[0]))
		advance(s,1)
		if second%120==0: print("CAMPAIGN ",s.time," lairs=",s.lairs().size()," palace=",s.palace().hp," gold=",s.gold," heroes=",s.units.filter(func(u):return u.hero and not u.dead).size())
	check(s.result=="victory","Scripted full campaign wins")
	check(s.stats.lairs==8,"All eight lairs counted")
	check(s.stats.potions_bought>0 and s.stats.potions_used>0,"Campaign heroes buy and consume supplies")
	check(s.stats.bounties==8,"Every campaign bounty paid once")
	FileAccess.open("res://reports/full-victory-save.json",FileAccess.WRITE).store_string(JSON.stringify(s.snapshot(),"",true,true))
	var report={"checks":checks,"failures":failures,"campaign":{"result":s.result,"time":s.time,"stats":s.stats},"engine":Engine.get_version_info().string}
	FileAccess.open("res://reports/full-simulation.json",FileAccess.WRITE).store_string(JSON.stringify(report,"  "))
	print(JSON.stringify(report)); quit(0 if failures.is_empty() else 1)
