class_name JamiesDad
extends Hero
## Jamie's Dad: huge muscles, really good looking and very powerful. Super strength (one
## punch sends a robot flying, a clap makes a shockwave, a ground-pound flattens everything
## round him), super speed (hold SHIFT to sprint; anything he runs into gets flattened) and
## super health (loads of it, and it heals itself back up). At full energy: DAD SMASH.

var streak_t := 0.0
var twinkle_t := 2.0


func _setup() -> void:
	hero_name = "Jamie's Dad"
	colour = Color(1.0, 0.82, 0.35)
	size = Models.DAD_SIZE
	max_hp = 300.0
	regen = 8.0
	speed = 13.0
	jump = 16.0
	punch_damage = 45.0
	punch_reach = 3.0
	punch_cd = 0.34
	punch_knock = 26.0
	blast_cost = 15.0
	can_sprint = true
	sprint_speed = 32.0
	can_pound = true
	ult_ready_text = "F: DAD SMASH READY!"
	hint = "WASD run   SHIFT super-sprint   MOUSE look/aim   SPACE super jump (CTRL in the air: GROUND POUND)   LMB punch   RMB thunder clap   F ultimate"


func _build_model() -> Dictionary:
	return Models.jamies_dad()


func special() -> void:
	## Thunder clap: a ring of air that blasts through every robot in front of him.
	_face_aim()
	energy -= blast_cost
	cd = 0.45
	shoot_t = 0.3
	var from := center() + Vector3(0, 0.3 * size, 0)
	var dir := (aim - from).normalized()
	game.spawn_projectile(from + dir * 1.2, dir * 30.0, "player", "clap", 30.0, 1.4,
		{"knock": 20.0, "life": 0.8, "pierce": true})
	game.audio.play("clap")
	game.shake(0.2)


func _pound_landed() -> void:
	game.shockwave(global_position, 10.0, 40.0)


func _ultimate_effect() -> void:
	game.dad_smash(global_position)


func _animate_extra(dt: float) -> void:
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	if shoot_t > 0.0:  # clap: both hands together out in front
		var k := 1.0 - shoot_t / 0.3
		arm_l.rotation = Vector3(-PI / 2, -0.6 + 0.6 * k, -0.1)
		arm_r.rotation = Vector3(-PI / 2, 0.6 - 0.6 * k, 0.1)
		fore_l.rotation.x = 0.2
		fore_r.rotation.x = 0.2
	if pounding:  # both fists raised to slam down
		arm_l.rotation = Vector3(-2.6, 0, -0.3)
		arm_r.rotation = Vector3(-2.6, 0, 0.3)
		fore_l.rotation.x = 0.4
		fore_r.rotation.x = 0.4
	# super-speed: white speed streaks rush off behind him
	var hv := Vector3(velocity.x, 0, velocity.z)
	if sprinting and hv.length() > speed * 1.2:
		streak_t -= dt
		if streak_t <= 0.0:
			streak_t = 0.02
			var off := Vector3(randf_range(-0.6, 0.6), randf_range(-1.0, 1.0), randf_range(-0.6, 0.6)) * size
			game.streak(center() + off, hv.normalized())
	# the twinkle off his perfect teeth
	twinkle_t -= dt
	var sparkle: Node3D = model["sparkle"]
	sparkle.visible = twinkle_t < 0.25
	if sparkle.visible:
		sparkle.rotation.z += dt * 8.0
		sparkle.scale = Vector3.ONE * (0.5 + sin(twinkle_t / 0.25 * PI) * 0.8)
	if twinkle_t <= 0.0:
		twinkle_t = randf_range(2.5, 4.5)
