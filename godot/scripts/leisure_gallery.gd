extends RefCounted
## Test-only occupied settlement; uses normal entrance, spending and rendering rules.
static func setup(s) -> void:
	s.gold=20000; s.paused=true
	for b in s.buildings:
		if b.hostile: b.spawn=10000
	for u in s.units:
		if u.hostile: u.dead=true
	var guilds: Array=[]
	for type in ["warriors","rangers","wizards","thieves"]:
		var b=s.add_building(type,s.find_site(type)); guilds.append(b)
		var u=s.recruit(b.id); u.pos=s.Shelter.door(s,b); s.Shelter.enter(s,u,b,"Resting"); u.hp=u.max_hp*0.65
	var temple=s.add_building("temple",s.find_site("temple")); var wizard=s.recruit(guilds[2].id)
	wizard.pos=s.Shelter.door(s,temple); s.Shelter.enter(s,wizard,temple,"Resting"); wizard.hp=wizard.max_hp*0.65
	for type in ["inn","brothel"]:
		var b=s.add_building(type,s.find_site(type)); var u=s.recruit(guilds[0 if type=="inn" else 1].id)
		s.hurt(u,u.max_hp*0.9,null); u.hp=u.max_hp*0.65; u.gold=200; u.pos=s.Shelter.door(s,b); u.journey.leisure_place=b.id; s.Court.leisure(s,u)
	for u in s.units: u.think=999
	s.rebuild_buckets(); s.update_vision()
