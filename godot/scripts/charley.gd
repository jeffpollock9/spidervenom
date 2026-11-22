class_name Charley
extends Hero
## Charley: really, really weak. Slow, tiny jumps, punches that only tickle, only a little
## health, and he gets puffed out if he runs for long. But he's good at two things: hiding
## (hold SHIFT and the robots stop bothering with him) and, at full energy, CALLING FOR
## HELP: Jamie's Dad drops out of the sky and smashes everything.

const STAMINA_MAX := 100.0

var stamina := STAMINA_MAX
var puffed_t := 0.0
var helper: Node3D
var helper_t := 0.0
var helper_landed := false


func _setup() -> void:
	hero_name = "Charley"
	colour = Color(1.0, 0.85, 0.3)
	size = Models.CHARLEY_SIZE
	max_hp = 30.0
	speed = 6.0
	jump = 8.0
	punch_damage = 3.0
	punch_reach = 1.6
	punch_cd = 0.6
	punch_knock = 0.5
	blast_cost = 12.0
	can_hide = true
	ult_ready_text = "F: CALL FOR HELP!"
	hint = "WASD run (not for long)   MOUSE look/aim   SPACE jump (a wee one)   LMB punch (it tickles)   RMB throw a sock   SHIFT (hold) hide   F call for help"


func _build_model() -> Dictionary:
	return Models.charley()


func info_line() -> String:
	if puffed_t > 0.0:
		return "PUFFED OUT!"
	if hiding:
		return "HIDING"
	return super()


func _pre_tick(ctl: Controls, dt: float) -> void:
	# running tires him out; when he's puffed out he can barely walk
	var moving := ctl.move.length() > 0.2 and not hiding
	if puffed_t > 0.0:
		puffed_t -= dt
		speed = 2.5
		stamina = min(STAMINA_MAX, stamina + 40.0 * dt)
		if puffed_t <= 0.0:
			speed = 6.0
	elif moving and is_on_floor():
		stamina -= 30.0 * dt
		if stamina <= 0.0:
			stamina = 0.0
			puffed_t = 2.5
			say("*puff* *pant* *wheeze*", 2.0)
	else:
		stamina = min(STAMINA_MAX, stamina + 25.0 * dt)


func punch() -> int:
	var hits := super()
	if hits > 0:
		game.popup(hand() + Vector3.UP * 0.5, "tickle!", Color(1, 0.75, 0.85))
	return hits


func special() -> void:
	## Throws a sock. It doesn't do much.
	_face_aim()
	energy -= blast_cost
	cd = 0.6
	shoot_t = 0.3
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 14.0 + Vector3.UP * 3.0, "player", "sock", 2.0, 0.2,
		{"knock": 1.0, "life": 1.6, "gravity": 14.0})
	game.audio.play("punch")


func _ultimate_effect() -> void:
	## CALL FOR HELP: Jamie's Dad drops out of the sky next to him and smashes everything.
	say("HELP! JAMIE'S DAD!", 1.5)
	game.audio.play("whoosh")
	if helper and is_instance_valid(helper):
		helper.queue_free()
	var d := Models.jamies_dad()
	helper = d["root"]
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	helper.position = global_position + fwd * 3.0 + Vector3.UP * 30.0
	helper.rotation.y = face_yaw  # facing the same way as Charley: he's got his back
	game.world.add_child(helper)
	helper_t = 0.0
	helper_landed = false


func _update_helper(dt: float) -> void:
	if helper == null or not is_instance_valid(helper):
		return
	helper_t += dt
	if not helper_landed:
		helper.position.y = max(global_position.y, helper.position.y - 60.0 * dt)
		if helper.position.y <= global_position.y + 0.01:
			helper_landed = true
			helper_t = 0.0
			game.dad_smash(helper.position)
			game.banner("JAMIE'S DAD TO THE RESCUE!", 1.6)
	elif helper_t > 1.6:
		helper.queue_free()
		helper = null


func _animate_extra(dt: float) -> void:
	_update_helper(dt)
	var torso: Node3D = model["torso"]
	var head: Node3D = model["head"]
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	var leg_l: Node3D = model["leg_l"]
	var leg_r: Node3D = model["leg_r"]
	var shin_l: Node3D = model["shin_l"]
	var shin_r: Node3D = model["shin_r"]
	(model["sweat"] as Node3D).visible = puffed_t > 0.0 or stamina < 35.0
	if hiding:  # crouched down with his hands over his eyes
		torso.rotation.x = -0.6
		torso.position.y = 0.72
		head.rotation.x = 0.4
		leg_l.rotation = Vector3(1.4, 0, -0.15)
		leg_r.rotation = Vector3(1.4, 0, 0.15)
		shin_l.rotation.x = -2.3
		shin_r.rotation.x = -2.3
		arm_l.rotation = Vector3(-1.2, 0.0, -0.35)
		arm_r.rotation = Vector3(-1.2, 0.0, 0.35)
		fore_l.rotation.x = 2.0
		fore_r.rotation.x = 2.0
		torso.position.x = sin(t * 30.0) * 0.008  # shaking with fear
	elif puffed_t > 0.0:  # bent over, hands on knees, panting
		torso.rotation.x = -0.75 + sin(t * 9.0) * 0.05
		head.rotation.x = -0.5
		arm_l.rotation = Vector3(-0.5, 0, -0.1)
		arm_r.rotation = Vector3(-0.5, 0, 0.1)
		fore_l.rotation.x = 0.3
		fore_r.rotation.x = 0.3
	else:
		torso.position.x = 0.0
		torso.rotation.x += 0.08  # a bit of a slouch
	var mouth: Node3D = model["mouth"]
	mouth.scale = Vector3.ONE * (1.4 + sin(t * 9.0) * 0.4 if puffed_t > 0.0 else 1.0)
