extends RefCounted
const Supplies=preload("res://scripts/supplies.gd")
static func wander(s,u,origin: Vector2,radius: float) -> void:
	if u.path_index>=u.path.size(): s.go(u,s.near_point(origin,radius),"Seeking adventure" if u.hero else "Patrolling")
static func think(s,u) -> void:
	if u.id==s.mission.boss_id: s.Mission.boss_think(s,u)
	elif u.hostile: monster(s,u)
	elif u.hero: hero(s,u)
	elif u.type=="peasant": peasant(s,u)
	elif u.type=="collector": collector(s,u)
	else:
		var enemy=s.nearest(u.pos,s.nearby(s.pos(s.palace()),11,true))
		if enemy!=null: u.target=enemy.id; u.state="Defending the kingdom"
		else: u.target=0; wander(s,u,s.pos(s.palace()),5)
static func hero(s,u) -> void:
	if s.Mission.dodge(s,u): return
	if u.hp<u.max_hp*0.3 or u.state in ["Resting","Fleeing"] and u.hp<u.max_hp*0.86:
		var home=s.nearest(u.pos,s.operating("temple"))
		if home==null: home=s.entity(u.home)
		if home==null or home.dead: home=s.palace()
		if u.pos.distance_to(s.pos(home))<3.5:
			if u.state!="Resting": s.Settlement.event(s,"recovery",u,home.site_name)
			u.state="Resting"; u.target=0; s.stop(u); u.hp=minf(u.max_hp,u.hp+(11 if home.type=="temple" else 7))
		else:
			if u.state!="Fleeing": s.Settlement.event(s,"retreat",u)
			s.go(u,s.pos(home),"Fleeing")
		return
	if u.state in ["Resting","Fleeing"]:
		s.Settlement.event(s,"recovered",u); u.state="Seeking adventure"; s.stop(u)
	var enemy=s.nearest(u.pos,s.nearby(u.pos,u.definition.range+3,true))
	if enemy!=null: u.target=enemy.id; u.state="Fighting "+enemy.definition.name; return
	if Supplies.seek(s,u): return
	if not Supplies.shopping_list(s,u).is_empty():
		var shop=s.nearest(u.pos,s.operating("marketplace"))
		if shop!=null and (u.pos.distance_to(s.pos(shop))<9 or u.goal==0):
			if u.pos.distance_to(s.pos(shop))<3: Supplies.buy(s,u,shop); u.goal=0
			else: s.go(u,s.pos(shop),"Buying potions"); return
	var best=null; var best_score: float=0.045
	for f in s.flags.values():
		var target=s.entity(f.target)
		if f.dead or target!=null and target.dead: continue
		var threat: float=maxf(0.8,s.definition_of(target).get("damage",14)/14.0+target.hp/500.0) if target!=null else 1
		var affinity: float=(2.5 if u.type=="ranger" else 1.7 if u.type=="thief" else 0.55) if f.type=="explore" else u.definition.affinity
		var score: float=f.reward/(30*threat)*affinity*u.bravery*(1+(u.level-1)*0.18)*(u.hp/u.max_hp)/(1+u.pos.distance_to(s.pos(f))*0.08)
		if score>best_score: best=f; best_score=score
	if best!=null:
		u.goal=best.id
		if best.type=="attack": u.target=best.target; u.state="Answering a bounty"
		elif u.pos.distance_to(s.pos(best))<1.9:
			best.dead=true; u.gold+=best.reward; s.Settlement.event(s,"explore",u); s.grant_experience(u,20); s.reveal(s.pos(best),9); s.notify(u.name+" claimed an exploration bounty."); s.fx("level",u.pos); u.goal=0
		else: s.go(u,s.pos(best),"Exploring for gold")
		return
	u.goal=0; u.target=0
	var lair=s.nearest(u.pos,s.buildings.filter(func(b):return not b.dead and b.hostile and u.pos.distance_to(s.pos(b))<5))
	if lair!=null and u.hp>u.max_hp*0.8 and (u.level>1 or u.type=="warrior"): u.target=lair.id; u.state="Raiding a lair"; return
	if u.type in ["ranger","thief"]:
		if u.path_index>=u.path.size():
			var unknown: Array=s.fixture.tiles.filter(func(t):return not t.explored and s.walkable(Vector2(t.x,t.y)) and u.pos.distance_to(Vector2(t.x,t.y))<16)
			if not unknown.is_empty():
				var t=unknown[s.rng.integer(0,unknown.size()-1)]; s.go(u,Vector2(t.x,t.y),"Exploring the borderlands"); return
		wander(s,u,s.pos(s.palace()),18)
	else:
		var home=s.entity(u.home)
		wander(s,u,s.pos(home) if home!=null and not home.dead else s.pos(s.palace()),7)
static func peasant(s,u) -> void:
	u.target=0
	var repair=s.nearest(u.pos,s.buildings.filter(func(b):return not b.dead and not b.hostile and (b.progress<1 or b.hp<b.max_hp)))
	if repair==null: wander(s,u,s.pos(s.palace()),6); return
	if not s.nearby(u.pos,3,true).is_empty(): s.go(u,s.pos(s.palace()),"Seeking shelter"); return
	if u.pos.distance_to(s.pos(repair))<repair.size*0.7+1.4:
		s.stop(u)
		if repair.progress<1:
			repair.progress=minf(1,repair.progress+0.8/s.definition_of(repair).buildTime); repair.hp=maxf(repair.hp,repair.max_hp*(0.2+0.8*repair.progress)); u.state="Building "+s.definition_of(repair).name
			if repair.progress==1: s.stats.built+=1; s.notify(s.definition_of(repair).name+" is ready.","complete")
		else: repair.hp=minf(repair.max_hp,repair.hp+7); u.state="Repairing "+s.definition_of(repair).name
	else: s.go(u,s.pos(repair),"Off to build" if repair.progress<1 else "Off to repair")
static func collector(s,u) -> void:
	u.target=0
	if u.carried>0:
		if u.pos.distance_to(s.pos(s.palace()))<3:
			s.gold+=u.carried; s.stats.taxes+=u.carried; s.fx("gold",u.pos,u.carried); u.carried=0; s.stop(u)
		else: s.go(u,s.pos(s.palace()),"Delivering taxes"); return
	var shop=s.nearest(u.pos,s.buildings.filter(func(b):return not b.dead and not b.hostile and b.tax>=10))
	if shop!=null:
		if u.pos.distance_to(s.pos(shop))<shop.size*0.7+1.1: u.carried+=floorf(shop.tax); shop.tax-=floorf(shop.tax); s.stop(u)
		else: s.go(u,s.pos(shop),"Collecting taxes")
	else: wander(s,u,s.pos(s.palace()),4)
static func monster(s,u) -> void:
	var enemy=s.nearest(u.pos,s.nearby(u.pos,u.definition.sight,false))
	if enemy!=null: u.target=enemy.id; u.state="Attacking"; return
	var near=s.nearest(u.pos,s.buildings.filter(func(b):return not b.dead and not b.hostile and u.pos.distance_to(s.pos(b))<6))
	if near!=null: u.target=near.id; u.state="Raiding the kingdom"; return
	var home=s.entity(u.home)
	if s.time>(100.0 if s.run.is_empty() else s.raid_after()) and (u.raider or u.type=="troll" or home!=null and home.dead): u.target=s.palace().id; u.state="Marching on the Palace"
	else: u.target=0; wander(s,u,s.pos(home) if home!=null else u.pos,4)
