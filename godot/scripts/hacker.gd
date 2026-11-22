class_name Hacker
extends Hero
## The Hacker: he can hack. Point at a robot and RIGHT CLICK to hack it: it turns green and
## fights for you until its battery runs out. LEFT CLICK zaps with electricity that jumps to
## a second robot. SHIFT glitches him a few metres forward. At full energy SYSTEM HACK hacks
## every robot nearby at once, deletes the mini-poos and crashes Mr Poo.

const HACK_TIME := 12.0
const HACK_RANGE := 40.0


func _setup() -> void:
	hero_name = "Hacker"
	colour = Color(0.3, 1.0, 0.45)
	size = Models.HACKER_SIZE
	max_hp = 90.0
	speed = 10.0
	jump = 13.0
	punch_damage = 14.0
	punch_reach = 5.0
	punch_cd = 0.45
	blast_cost = 22.0
	custom_shift = true
	ult_ready_text = "F: SYSTEM HACK READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump   LMB zap   RMB HACK a robot (it fights for you)   SHIFT glitch forward   F ultimate   ESC pause"


func _build_model() -> Dictionary:
	return Models.hacker()


func _pre_tick(ctl: Controls, _dt: float) -> void:
	if ctl.alt_pressed:
		glitch(ctl)


func glitch(ctl: Controls) -> void:
	## Glitch forward 7 m in an instant (stopping short of walls).
	if energy < 10.0:
		say("Need energy!")
		return
	var wish := rig.right() * ctl.move.x + rig.forward() * ctl.move.y
	if wish.length() < 0.1:
		wish = Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	wish = Vector3(wish.x, 0, wish.z).normalized()
	var from := center()
	var dist := 7.0
	var q := PhysicsRayQueryParameters3D.create(from, from + wish * (dist + 1.0), 1 | 16, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		dist = max(0.0, from.distance_to(hit.position) - 1.0)
	energy -= 10.0
	game.burst(center(), Models.HACK_GREEN, 14, 5.0)
	global_position += wish * dist
	invuln = max(invuln, 0.3)
	game.burst(center(), Models.HACK_GREEN, 14, 5.0)
	game.audio.play("glitch")


func punch() -> int:
	## ZAP: electricity from the laptop to the nearest robot in front, then on to a second one.
	_face_aim()
	cd = punch_cd
	shoot_t = 0.25
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var first = null
	var best := punch_reach + 2.0
	for e in game.targets():
		var to: Vector3 = e.center() - center()
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < punch_reach + e.radius and abs(to.y) < 3.0 and fwd.dot(flat.normalized()) > 0.3 \
				and flat.length() < best:
			best = flat.length()
			first = e
	if first == null:
		game.beam(hand(), hand() + fwd * 2.0, Models.HACK_GREEN)
		game.audio.play("zap")
		return 0
	game.beam(hand(), first.center(), Models.HACK_GREEN)
	first.hurt(punch_damage, fwd, 5.0)
	var second = null
	best = 7.0
	if is_instance_valid(first):
		for e in game.targets():
			if e == first:
				continue
			var dd: float = e.center().distance_to(first.center())
			if dd < best:
				best = dd
				second = e
		if second != null:
			game.beam(first.center(), second.center(), Models.HACK_GREEN)
			second.hurt(punch_damage * 0.6, second.center() - first.center(), 4.0)
	game.audio.play("zap")
	return 1 + int(second != null)


func special() -> void:
	## HACK the robot nearest the crosshair.
	_face_aim()
	var from := hand()
	var ray := (aim - from).normalized()
	var pick = null
	var best := 0.93
	var candidates: Array = game.targets()
	for e in candidates:
		var to: Vector3 = e.center() - from
		if to.length() > HACK_RANGE:
			continue
		var dot := to.normalized().dot(ray)
		if dot > best:
			best = dot
			pick = e
	cd = 0.4
	shoot_t = 0.3
	if pick == null:
		say("Nothing to hack")
		return
	energy -= blast_cost
	game.beam(from, pick.center(), Models.HACK_GREEN)
	if pick == game.boss:
		game.popup(pick.center() + Vector3.UP * 4.0, "ACCESS DENIED", Color(1, 0.3, 0.3))
		pick.hurt(10.0, Vector3.ZERO)
		game.audio.play("hurt")
	elif not pick.hackable():
		game.popup(pick.center() + Vector3.UP * 1.5, "CAN'T HACK POO", Color(1, 0.6, 0.3))
		game.audio.play("splat")
	else:
		pick.hack(HACK_TIME)
		game.audio.play("hack")


func _ultimate_effect() -> void:
	game.system_hack(center())


func _animate_extra(_dt: float) -> void:
	# laptop held out in front, typing with the other hand
	var arm_l: Node3D = model["arm_l"]
	var fore_l: Node3D = model["fore_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_r: Node3D = model["fore_r"]
	if not flying and not swinging:
		arm_l.rotation = Vector3(-0.35, 0, -0.15)
		fore_l.rotation.x = 1.35
		if shoot_t <= 0.0 and punch_t <= 0.0 and is_on_floor() and Vector2(velocity.x, velocity.z).length() < 1.0:
			arm_r.rotation = Vector3(-0.3, 0, 0.25)
			fore_r.rotation.x = 1.4 + sin(t * 20.0) * 0.08  # tap tap tap
	if shoot_t > 0.0:
		arm_l.rotation = Vector3(-1.2, 0, -0.1)
		fore_l.rotation.x = 0.4
