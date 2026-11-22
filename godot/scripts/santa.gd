class_name Santa
extends Hero
## Santa: his reindeer come and defeat the enemies. RIGHT CLICK calls a reindeer that
## gallops down out of the sky and charges the robot you point at. Jump again in mid-air and
## the sleigh appears: he flies it like Venom flies. LEFT CLICK throws a present, SHIFT is a
## big "HO HO HO!" that stuns robots nearby, and at full energy all nine reindeer come in a
## REINDEER STAMPEDE.

const DEER_COST := 16.0
const NAMES := ["DASHER", "DANCER", "PRANCER", "VIXEN", "COMET", "CUPID", "DONNER", "BLITZEN", "RUDOLPH"]

var next_deer := 0


func _setup() -> void:
	hero_name = "SANTA"
	colour = Color(1.0, 0.3, 0.3)
	size = Models.SANTA_SIZE
	max_hp = 150.0
	speed = 8.5
	jump = 12.0
	punch_damage = 16.0
	punch_reach = 2.8
	punch_cd = 0.4
	blast_cost = DEER_COST
	can_fly = true
	fly_speed = 17.0
	custom_shift = true
	ult_ready_text = "F: REINDEER STAMPEDE READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump (again in the air: SLEIGH)   LMB throw a present   RMB call a reindeer   SHIFT ho ho ho   F ultimate"


func _build_model() -> Dictionary:
	return Models.santa()


func info_line() -> String:
	if flying:
		return "SLEIGH RIDE"
	return super()


func _pre_tick(ctl: Controls, _dt: float) -> void:
	if ctl.alt_pressed:
		ho_ho_ho()


func ho_ho_ho() -> void:
	## Such a jolly laugh that every robot nearby stops to listen.
	if energy < 12.0:
		say("Need energy!")
		return
	energy -= 12.0
	say("HO HO HO!", 1.2)
	game.audio.play("hohoho")
	for e in game.targets():
		if e != game.boss and e.center().distance_to(center()) < 12.0:
			e.daze(2.5)
			game.popup(e.center() + Vector3.UP * 1.5, "?", Color(1, 1, 1))


func punch() -> int:
	## Throw a present. It bursts open on whatever it hits.
	_face_aim()
	cd = punch_cd
	shoot_t = 0.3
	var from := hand() + Vector3.UP * 0.3
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 22.0 + Vector3.UP * 4.0, "player", "present", punch_damage, 0.3,
		{"gravity": 16.0, "life": 2.5, "splash": 3.0, "knock": 6.0})
	game.audio.play("punch")
	return 0


func special() -> void:
	## Call a reindeer: it charges the robot nearest the crosshair.
	_face_aim()
	energy -= DEER_COST
	cd = 0.35
	shoot_t = 0.3
	var from := hand()
	var ray := (aim - from).normalized()
	var pick = null
	var best := 0.9
	for e in game.targets():
		var to: Vector3 = e.center() - from
		if to.length() < 50.0 and to.normalized().dot(ray) > best:
			best = to.normalized().dot(ray)
			pick = e
	var back := Vector3(sin(face_yaw), 0, cos(face_yaw))
	var start := global_position + back * 6.0 + Vector3.UP * 7.0 + Vector3(randf_range(-2, 2), 0, randf_range(-2, 2))
	var deer_name: String = NAMES[next_deer % NAMES.size()]
	next_deer += 1
	game.spawn_reindeer(start, pick, aim, 45.0, 30.0, deer_name, deer_name == "RUDOLPH")
	say("ON, %s!" % deer_name, 1.0)
	game.audio.play("bells")


func _ultimate_effect() -> void:
	game.reindeer_stampede(self)


func _animate_extra(_dt: float) -> void:
	var sleigh: Node3D = model["sleigh"]
	sleigh.visible = flying
	if flying:  # sitting in the sleigh, reins in hand
		for tm in model["team"]:
			Models.animate_reindeer(tm, t)
		(model["torso"] as Node3D).rotation.x = 0.0
		(model["leg_l"] as Node3D).rotation = Vector3(1.5, 0, -0.1)
		(model["leg_r"] as Node3D).rotation = Vector3(1.5, 0, 0.1)
		(model["shin_l"] as Node3D).rotation.x = -1.5
		(model["shin_r"] as Node3D).rotation.x = -1.5
		(model["arm_l"] as Node3D).rotation = Vector3(-0.9, 0, -0.1)
		(model["arm_r"] as Node3D).rotation = Vector3(-0.9, 0, 0.1)
		(model["fore_l"] as Node3D).rotation.x = 0.5
		(model["fore_r"] as Node3D).rotation.x = 0.5
	# a jolly belly wobble
	(model["torso"] as Node3D).scale = Vector3(1.0 + sin(t * 3.0) * 0.012, 1.0, 1.0 + sin(t * 3.0) * 0.012)
