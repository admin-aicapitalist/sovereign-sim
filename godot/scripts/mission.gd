extends RefCounted
## Authored encounter layered onto the existing seeded campaign geography.
static func empty() -> Dictionary:
	return {"id":"classic","encounter_id":0,"encounter_cleared":false,"revealed":false,"boss_id":0,"boss_defeated":false,"enraged":false,"slam_remaining":0.0,"slam_x":0.0,"slam_y":0.0,"special_cooldown":4.0,"arrival_remaining":0.0}
static func start(s,key: String) -> void:
	s.mission=empty()
	if key!="ember_crown": return
	s.mission.id=key
	# The first graveyard is reachable early and retains the map generator's dry foundation.
	for b in s.buildings:
		if b.type=="graveyard":
			s.mission.encounter_id=b.id; b.site_name="Ashen Monastery"; break
	s.notify("The Ember Crown: clear two lairs to uncover the lost monastery.")
static func title(s) -> String: return s.definitions.mission.name if s.mission.id=="ember_crown" else "The Young Kingdom"
static func objective(s) -> String:
	if s.mission.id!="ember_crown": return "Keep your Palace standing."
	if not s.mission.revealed: return "Break %d lairs to uncover the monastery."%s.definitions.mission.reveal_after
	if not s.mission.encounter_cleared: return "Recover the Ashen Monastery and its Runeblade."
	if s.mission.boss_id==0: return "Recover the relics. Warlord arrives in %ds."%ceili(s.mission.arrival_remaining)
	if not s.mission.boss_defeated: return "Defeat the Ember Warlord. Heroes try to dodge the marked ground slam."
	return "The Warlord has fallen. Clear the remaining lairs."
static func apply_boss(s,u) -> void:
	u.definition=s.definitions.units.troll.duplicate(true)
	u.definition.name="Ember Warlord"; u.definition.damage=s.definitions.mission.boss_damage
	u.definition.regeneration=0; u.definition.speed=0.95; u.definition.armor=6
	u.name="The Ember Warlord"
static func killed(s,e) -> void:
	if s.mission.id!="ember_crown": return
	if e.id==s.mission.encounter_id:
		s.mission.encounter_cleared=true; s.mission.arrival_remaining=s.definitions.mission.arrival_delay; s.gold+=s.definitions.mission.encounter_reward
		s.notify("The monastery is free. Its Runeblade lies in the ruins. +%dg."%s.definitions.mission.encounter_reward,"complete")
	if e.id==s.mission.boss_id:
		s.mission.boss_defeated=true; s.mission.slam_remaining=0
		s.notify("The Ember Warlord is defeated. Recover his crown and secure the borderlands!","victory")
static func update(s,dt: float) -> void:
	if s.mission.id!="ember_crown" or s.stress: return
	var m: Dictionary=s.mission; var d: Dictionary=s.definitions.mission
	if not m.revealed and s.stats.lairs>=d.reveal_after:
		m.revealed=true
		var site=s.building(m.encounter_id)
		s.vision.append({"x":site.x,"y":site.y,"r":8.0,"until":s.time+3600}); s.reveal(s.pos(site),8)
		s.notify("Scouts found the Ashen Monastery. Recover its relics before challenging the Warlord.","flag")
	if m.encounter_cleared and m.revealed and m.boss_id==0: m.arrival_remaining=maxf(0,m.arrival_remaining-dt)
	if m.encounter_cleared and m.revealed and m.boss_id==0 and m.arrival_remaining==0:
		var b=s.building(m.encounter_id); var u=s.add_unit("troll",s.near_point(s.pos(b),3),b.id)
		m.boss_id=u.id; apply_boss(s,u); u.max_hp=d.boss_hp; u.hp=u.max_hp; u.raider=false
		s.notify("The Ember Warlord has arrived at the monastery. Post a bounty when your heroes are ready!","danger")
	var boss=s.entity(m.boss_id)
	if boss==null or boss.dead: return
	if not m.enraged and boss.hp/boss.max_hp<=d.enrage_threshold:
		m.enraged=true
		for i in 2:
			var guard=s.add_unit("goblin",s.near_point(boss.pos,2),boss.home); guard.raider=false
		s.notify("The Warlord is enraged! His slams quicken and reinforcements arrive.","danger"); s.fx("relic",boss.pos,0,1.2)
	if m.slam_remaining>0:
		m.slam_remaining=maxf(0,m.slam_remaining-dt); s.stop(boss); boss.state="Winding up a ground slam"
		if m.slam_remaining==0:
			var at:=Vector2(m.slam_x,m.slam_y)
			for u in s.units:
				if not u.dead and not u.hostile and u.pos.distance_to(at)<d.slam_radius: s.hurt(u,d.slam_damage,boss)
			s.fx("slam",at,d.slam_radius,1.1); s.events.append("meteor-impact"); s.stats.boss_slams+=1
			m.special_cooldown=d.enrage_cooldown if m.enraged else d.slam_cooldown
	else:
		m.special_cooldown=maxf(0,m.special_cooldown-dt)
		if m.special_cooldown==0 and not s.nearby(boss.pos,4.5,false).is_empty():
			m.slam_x=boss.pos.x; m.slam_y=boss.pos.y; m.slam_remaining=d.slam_warning; s.stop(boss)
			s.events.append("spell-meteor")
			for u in s.units:
				if u.hero: u.think=0
static func dodge(s,u) -> bool:
	if s.mission.slam_remaining<=0: return false
	var at:=Vector2(s.mission.slam_x,s.mission.slam_y); var radius: float=s.definitions.mission.slam_radius
	if u.pos.distance_to(at)>radius+0.5: return false
	var direction: Vector2=(u.pos-at).normalized()
	if direction.length_squared()<0.1: direction=Vector2.from_angle(u.id*1.7)
	for turn in [0.0,0.7,-0.7,1.4,-1.4,3.14]:
		var goal: Vector2=at+direction.rotated(turn)*(radius+1.3)
		if s.walkable(goal): s.go(u,goal,"Dodging the ground slam"); return true
	return false
static func boss_think(s,u) -> void:
	var enemy=s.nearest(u.pos,s.nearby(u.pos,9,false))
	if enemy!=null: u.target=enemy.id; u.state="Hunting intruders"
	else:
		u.target=0; s.go(u,s.near_open(s.pos(s.building(s.mission.encounter_id))),"Guarding the monastery")
