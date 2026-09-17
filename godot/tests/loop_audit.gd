extends "res://tests/settlement_campaign.gd"
## Observes the existing paid campaign policy; changes no simulation rules.
var samples: Array=[]
var calls: Dictionary={}
var entries: Dictionary={}
var first_shadow: float=-1
var town_danger_seconds: int=0
var palace_hit_seconds: int=0
var minimum_palace_hp: float=INF
var last_sample: int=-1
func advance(s,seconds: int) -> void:
	for second in seconds:
		for tick in 20: s.tick(0.05)
		observe(s)
func observe(s) -> void:
	var heroes: Array=s.units.filter(func(u):return u.hero and not u.dead)
	for u in heroes:
		if u.journey.calling>0: calls[str(u.id)+":"+str(u.journey.calling)]=true
	for id in s.run.heroes:
		var count: int=s.run.heroes[id].get("journey",{}).get("shadow_count",0)
		entries[id]=maxi(entries.get(id,0),count)
	var shadow_entries: int=0
	for n in entries.values(): shadow_entries+=n
	if shadow_entries>0 and first_shadow<0: first_shadow=s.time
	var near_town: int=s.units.filter(func(u):return u.hostile and not u.dead and u.pos.distance_to(s.pos(s.palace()))<12).size()
	if near_town>0: town_danger_seconds+=1
	if s.time-s.palace().last_hit<1: palace_hit_seconds+=1
	minimum_palace_hp=minf(minimum_palace_hp,s.palace().hp)
	var bucket: int=floori(s.time/30)
	if bucket==last_sample and s.result=="": return
	last_sample=bucket
	var levels: float=0
	for u in heroes: levels+=u.level
	samples.append({"time":snappedf(s.time,0.05),"gold":snappedf(s.gold,1),"living_heroes":heroes.size(),"average_level":snappedf(levels/maxi(1,heroes.size()),0.1),"heroes_inside":heroes.filter(func(u):return u.inside>0).size(),"current_shadows":heroes.filter(func(u):return s.Journey.is_shadow(u)).size(),"shadow_entries":shadow_entries,"near_town_enemies":near_town,"hostile_units":s.units.filter(func(u):return u.hostile and not u.dead).size(),"marching_raiders":s.units.filter(func(u):return u.hostile and not u.dead and u.state=="Marching on the Palace").size(),"active_lairs":s.lairs().filter(func(b):return not b.dormant).size(),"dormant_lairs":s.lairs().filter(func(b):return b.dormant).size(),"palace_hp":s.palace().hp,"monastery_cleared":s.mission.encounter_cleared,"boss_arrived":s.mission.boss_id>0})
func run() -> void:
	for seed_value in [41972,0,4]:
		samples=[]; calls={}; entries={}; first_shadow=-1; town_danger_seconds=0; palace_hit_seconds=0; minimum_palace_hp=INF; last_sample=-1
		var report: Dictionary=campaign(seed_value,"crown","untroubled")
		var count: int=0
		for n in entries.values(): count+=n
		report.shadow_entries=count; report.heroes_ever_in_shadow=entries.values().filter(func(n):return n>0).size(); report.observed_callings=calls.size(); report.first_shadow=first_shadow
		report.town_danger_seconds=town_danger_seconds; report.palace_hit_seconds=palace_hit_seconds; report.minimum_palace_hp=minimum_palace_hp
		print("LOOP AUDIT ",JSON.stringify(report))
		report.samples=samples.duplicate(true); reports.append(report)
	var file=FileAccess.open("res://reports/loop-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"runs":reports,"note":"Observational audit at 1x simulation time. Uses the existing campaign test's paid building/recruitment/research/bounty policy, including automatic royal Shadow support. The policy builds neither leisure venues nor thieves, so it does not test the leisure economy. These are reproducible comparison runs, not a replay of the human playthrough. No pass/fail threshold for pacing has been imposed."},"\t")+"\n")
	quit()
