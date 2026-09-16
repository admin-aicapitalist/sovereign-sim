extends RefCounted
## Deliberate gallery for visual regression. Invoked only by the test bridge/tests.
static func setup(s) -> Dictionary:
	for actor in s.units: s.actors.erase(actor.id); s.by_id.erase(actor.id)
	s.units.clear(); s.effects.clear(); s.projectiles.clear(); s.events.clear()
	s.gold=20000
	for key in s.definitions.spells: s.magic.unlocked[key]=true
	var center: Vector2=s.pos(s.palace())+Vector2(7,7)
	var friend: Vector2=center+Vector2(-1.8,1.8)
	var foe: Vector2=center+Vector2(2,-2)
	var wizard=s.add_unit("wizard",center+Vector2(-4,-1),s.palace().id)
	for pair in [["warrior",friend],["guard",friend+Vector2(1.3,0.1)],["ranger",friend+Vector2(0.1,1.4)],["peasant",friend+Vector2(-1.2,-0.1)],["goblin",foe],["skeleton",foe+Vector2(-0.6,1.3)],["troll",foe+Vector2(1.3,0.3)],["thief",foe+Vector2(0.7,-1.2)]]:
		var u=s.add_unit(pair[0],pair[1],s.palace().id if pair[0] in ["warrior","guard","ranger","peasant"] else 0)
		if pair[0]=="thief": u.hostile=true
	for u in s.units:
		u.think=999; u.cooldown=999; u.cast_timer=999; u.hp=1000 if u.hostile else 240; u.max_hp=1500 if u.hostile else 500
		u.heading=(wizard.pos-u.pos).normalized() if u.hostile else Vector2.RIGHT
	wizard.cast_timer=0; wizard.heading=(foe-wizard.pos).normalized()
	s.fixture.trees.assign(s.fixture.trees.filter(func(t):return Vector2(t.x,t.y).distance_to(center)>13))
	s.revision+=1; s.reveal(center,20); s.rebuild_buckets()
	return {"center":center,"friend":friend,"foe":foe,"wizard":wizard.id}
