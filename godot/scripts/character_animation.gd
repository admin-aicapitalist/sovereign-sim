extends RefCounted
## Samples packed, eight-direction animations without allocating a Node per actor.
## Pose time comes from simulation time, so pause and speed changes stay coherent.

static func direction(heading: Vector2) -> int:
	return posmod(roundi(heading.angle()/(PI/4)),8)

static func frame(u,sim,art: Dictionary) -> int:
	var sequence: Array=art.animations.idle
	var pose: int=posmod(int(sim.time*3+u.id*0.73),sequence.size())
	var working: bool=(u.state.begins_with("Building") or u.state.begins_with("Repairing")) and u.path_index>=u.path.size()
	if not u.pending_attack.is_empty():
		sequence=art.animations.attack
		# Wind-up occupies poses 0..2; the actual projectile/hit releases at pose 3.
		var progress: float=1-u.pending_attack.remaining/u.pending_attack.duration
		pose=clampi(int(progress*3),0,2)
	elif u.attacking>0:
		sequence=art.animations.attack
		var recovery: float=0.2 if sim.mission.id=="ember_crown" else 0.34
		pose=3+clampi(int((recovery-u.attacking)/recovery*3),0,2)
	elif working:
		sequence=art.animations.attack; pose=posmod(int(sim.time*9+u.id),sequence.size())
	elif u.path_index<u.path.size():
		sequence=art.animations.walk; pose=posmod(int(u.animation),sequence.size())
	return int(sequence[pose])+direction(u.heading)
