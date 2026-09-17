extends SceneTree
const S=preload("res://scripts/simulation.gd")
var checks: int=0
var failures: Array=[]
func check(ok: bool,label: String) -> void:
	checks+=1
	if not ok: failures.append(label); push_error(label)
func fresh():
	var s=S.new(); s.start_settlement(s.Settlement.config(41972)); s.gold=10000
	for b in s.buildings:
		if b.hostile: b.spawn=10000
	for u in s.units:
		if u.hostile: u.dead=true
	s.rebuild_buckets(); return s
func hero(s,type: String="warriors"):
	var b=s.add_building(type,s.find_site(type)); return s.recruit(b.id)
func save(s) -> Dictionary: return JSON.parse_string(JSON.stringify(s.snapshot(),"",true,true))
func step(s,seconds: float) -> void:
	s.paused=false
	for i in int(seconds*20): s.tick(0.05)
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for type in ["warriors","rangers","wizards","thieves","temple","inn","brothel"]:
		var s=fresh(); var u=hero(s); var b=s.building(u.home) if type=="warriors" else s.add_building(type,s.find_site(type))
		u.pos=s.Shelter.door(s,b)+Vector2(4,0)
		check(not s.Shelter.enter(s,u,b,"Resting") and u.inside==0,type+": cannot enter from a distance")
		u.pos=s.Shelter.door(s,b); u.pending_attack={"target":1}; u.target=1
		check(s.Shelter.enter(s,u,b,"Resting") and u.inside==b.id and u.path.is_empty() and u.pending_attack.is_empty() and u.target==0,type+": crossing the door clears travel and combat")
		s.rebuild_buckets(); var hp: float=u.hp; s.hurt(u,9999,null)
		check(u.hp==hp and not u.dead and u not in s.nearby(u.pos,6,false),type+": occupants cannot be attacked outside")
		var restored=S.new(); check(restored.restore(save(s)) and restored.entity(u.id).inside==b.id,type+": occupancy survives JSON save/load")
		var old: Vector2=u.pos; s.navigate(u,1); check(u.pos==old,type+": occupants stay inside until leaving")
		u.hp=u.max_hp*0.5; s.Brain.hero(s,u)
		check(u.hp>u.max_hp*0.5 and u.inside==b.id,type+": heroes recover indoors")
		u.hp=u.max_hp; s.Brain.hero(s,u)
		check(u.inside==0 and s.walkable(u.pos),type+": recovered heroes emerge on walkable ground")
		u.pos=s.Shelter.door(s,b); s.Shelter.enter(s,u,b,"Resting"); s.hurt(b,999999,null)
		check(u.inside==0 and not u.dead and s.walkable(u.pos),type+": destroyed shelters release their occupants")
	var s=fresh(); var u=hero(s); var b=s.building(u.home)
	u.hp=u.max_hp*0.27; u.pos=s.Shelter.door(s,b)+Vector2(2,0)
	var entered: bool=false; var recovered: bool=false
	for i in 1200:
		step(s,0.05)
		entered=entered or u.inside==b.id
		if entered and u.inside==0 and u.hp>=u.max_hp*0.86: recovered=true; break
	check(entered and recovered,"Autonomous wounded hero walks to a door, rests, then returns outside")
	var temple=s.add_building("temple",s.find_site("temple")); var wizard=hero(s,"wizards")
	wizard.pos=s.Shelter.door(s,temple); s.Shelter.enter(s,wizard,temple,"Resting")
	check(not s.Magic.wizard_cast(s,wizard,"heal",wizard.pos),"Sheltered Wizard cannot cast into the outside world")
	var unfinished=s.add_building("inn",s.find_site("inn")); unfinished.progress=0.5; u.pos=s.Shelter.door(s,unfinished)
	check(not s.Shelter.enter(s,u,unfinished,"Resting"),"Construction sites cannot shelter heroes")
	var marketplace=s.add_building("marketplace",s.find_site("marketplace")); u.pos=s.Shelter.door(s,marketplace)
	check(not s.Shelter.enter(s,u,marketplace,"Resting"),"Shops retain their existing outside service behavior")
	u.pos=s.Shelter.door(s,b); s.Shelter.enter(s,u,b,"Resting"); var data=save(s); var clone=S.new()
	check(clone.restore(data),"Valid occupied settlement restores")
	for value in [-1,0.5,"1",data.next_id+1,marketplace.id,unfinished.id]:
		var bad=data.duplicate(true); bad.units.filter(func(item):return item.id==u.id)[0].inside=value
		var before=save(clone); check(not clone.restore(bad) and save(clone)==before,"Invalid occupancy %s rejected before mutation"%str(value))
	for field in ["pos","path","target","pending_attack","dead"]:
		var bad=data.duplicate(true); var item=bad.units.filter(func(unit):return unit.id==u.id)[0]
		item[field]={"pos":[0,0],"path":[[1,1]],"target":b.id,"pending_attack":{"target":b.id,"remaining":1,"duration":1},"dead":true}[field]
		check(not clone.restore(bad),"Contradictory indoor "+field+" rejected")
	var legacy=data.duplicate(true)
	for item in legacy.units: item.erase("inside")
	check(clone.restore(legacy) and clone.entity(u.id).inside==0,"Older saves migrate without inventing occupants")
	s.Shelter.leave(s,u); u.hp=u.max_hp; s.hurt(u,u.max_hp*0.9,null); u.hp=u.max_hp*0.5; u.gold=200
	unfinished.progress=1; u.pos=s.Shelter.door(s,unfinished); u.journey.leisure_place=unfinished.id
	s.Court.leisure(s,u); u.think=999; var purse: float=u.gold; var hp: float=u.hp
	step(s,4)
	check(u.inside==unfinished.id and u.hp>=hp+7.9 and u.gold==purse,"Paid visit supplies continuous rest without charging each tick")
	check(s.Journey.is_shadow(u),"Indoor rest does not clear a persistent Shadow")
	s.Shelter.leave(s,u)
	check(u.journey.leisure_place==0 and u.journey.leisure_until==0,"Leaving closes the paid visit and prevents remote patron theft")
	print("Shelter checks: ",checks," / failures: ",failures.size())
	var file=FileAccess.open("res://reports/shelter-systems.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"pass":failures.is_empty()},"\t")+"\n")
	quit(0 if failures.is_empty() else 1)
