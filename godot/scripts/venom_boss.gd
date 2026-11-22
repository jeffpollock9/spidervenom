class_name VenomBoss
extends Boss
## Venom as a baddie: a giant symbiote monster, nearly 7 m tall. He stalks after you, slashes
## with his claws if you get close, fires symbiote blasts, pounces, and lashes out a tendril
## that yanks you over to him. When he's angry (half health) his wings come out: he flies up
## and dive-bombs you, and the landing sends out a ring of symbiote you have to jump over.

const SCALE := 2.52  # the model is built ~2.7 m tall: about 6.8 m
const SLASH_R := 8.0

var was_on_floor := true
var choices := 0
var walk_phase := 0.0
var wing_open := 0.0
var lash_t := 0.0      # the tendril is out (drawn for this long)
var dive_target := Vector3.ZERO


func _init(g) -> void:
	super(g)
	boss_name = "Venom"
	max_hp = 700.0
	hp = max_hp
	contact = 18.0
	radius = 1.8
	height = 6.6


func _ready() -> void:
	collision_mask = 1  # too big for the plaza platforms: he goes straight through them
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.5
	cap.height = height
	shape.shape = cap
	shape.position.y = height / 2
	add_child(shape)
	model = Models.venom()
	(model["root"] as Node3D).scale = Vector3.ONE * SCALE
	add_child(model["root"])


func _angry() -> void:
	game.popup(center() + Vector3.UP * 4.5, "WE ARE VENOM!", Color(0.8, 0.8, 1.0))


func tick(dt: float) -> void:
	t += dt
	flash = max(0.0, flash - dt)
	lash_t = max(0.0, lash_t - dt)
	var player = game.player
	var to: Vector3 = player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var spd := 1.3 if phase == 2 else 1.0
	var walk := Vector3.ZERO
	var airborne := state == "leap" or state == "dive"
	if _tick_stun(dt) and not airborne:
		pass
	elif active and not dead and player.hiding and not airborne:
		walk = Vector3(sin(t * 0.8), 0, cos(t * 0.6)) * 2.0  # sniffing about with his tongue out
	elif active and not dead:
		timer -= dt * spd
		walk = _think(player, flat, spd, dt)
	if airborne:
		pass  # keeps the speed he jumped with
	elif is_on_floor():
		velocity.x = walk.x
		velocity.z = walk.z
	if state == "dive" and timer <= 0.0:
		velocity.y = max(velocity.y - GRAVITY * 2.0 * dt, -60.0)  # plummeting
	elif state == "dive":
		velocity.y = move_toward(velocity.y, 0.0, 30.0 * dt)       # hovering, wings beating
	else:
		velocity.y = max(velocity.y - GRAVITY * dt, -50.0)
	move_and_slide()
	var landed := is_on_floor() and not was_on_floor
	was_on_floor = is_on_floor()
	if landed and active and airborne:
		_land(player)
	if flat.length() > 0.5:
		face_yaw = lerp_angle(face_yaw, atan2(-flat.x, -flat.z), min(1.0, 5.0 * dt))
	_animate(dt, walk)
	if lash_t > 0.0 and is_instance_valid(player):  # the tendril, from his hand to the hero
		game.beam(hand(), player.center(), Models.VENOM_BLACK)


func hand() -> Vector3:
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	return global_position + Vector3.UP * height * 0.62 + fwd * 1.6


func _think(player, flat: Vector3, spd: float, _dt: float) -> Vector3:
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.1 else Vector3.ZERO
	match state:
		"idle", "walk":
			if timer <= 0.0 and is_on_floor():
				choices += 1
				var r := rng.randf()
				if phase == 2 and choices % 3 == 0:
					_go("dive", 0.9)
					velocity = Vector3(0, 24.0, 0)
					game.audio.play("flap")
					game.popup(center() + Vector3.UP * 4.0, "!!!", Color(0.8, 0.8, 1.0))
				elif dist < SLASH_R:
					_go("slash", 0.45)
				elif r < 0.4:
					_go("blast", 0.5)
				elif r < 0.65 and dist < 30.0:
					_go("lash", 0.45)
				elif r < 0.85:
					_go("leap", 0.0)
					var reach: float = min(16.0, dist * 0.85)
					velocity = dir * reach + Vector3.UP * 15.0
					game.audio.play("roar")
				else:
					_go("walk", rng.randf_range(1.0, 1.8))
			if state == "walk" and dist > 4.0:
				return dir * 5.0 * spd
		"slash":
			if timer <= 0.0:
				if dist < SLASH_R + 1.0 and abs(player.global_position.y - global_position.y) < 5.0:
					player.take_damage(22.0, global_position, 14.0)
				game.audio.play("punch")
				_go("walk", 0.7)
		"blast":
			if timer <= 0.0:
				_blast(player)
				_go("walk", rng.randf_range(0.9, 1.6))
		"lash":
			if timer <= 0.0:
				_lash(player)
				_go("walk", 1.0)
		"dive":
			if timer > 0.0:  # up in the air, picking his spot
				dive_target = player.global_position
			elif timer > -0.05 and velocity.y <= 0.0:  # swoop down at where the hero was
				var d := dive_target - global_position
				velocity.x = d.x * 1.4
				velocity.z = d.z * 1.4
	return Vector3.ZERO


func _blast(player) -> void:
	var n := 3 if phase == 1 else 5
	var from := hand()
	var aimv: Vector3 = (player.center() - from).normalized()
	var side := aimv.cross(Vector3.UP).normalized()
	for i in n:
		var d := (aimv + side * (float(i) - (n - 1) / 2.0) * 0.12).normalized()
		game.spawn_projectile(from, d * 24.0, "enemy", "symbiote", 10.0, 0.6, {"life": 3.0, "knock": 8.0})
	game.audio.play("blob")


func _lash(player) -> void:
	## A tendril shoots out and drags the hero over to him.
	lash_t = 0.35
	game.audio.play("blob")
	if player.dead or player.hiding:
		return
	var pull: Vector3 = global_position - player.global_position
	pull.y = 0
	if pull.length() > 32.0:
		return
	if player.take_damage(8.0, global_position, 2.0):
		player.velocity = pull.normalized() * min(26.0, pull.length() * 1.3) + Vector3.UP * 8.0
		player.say("WAAAH!", 0.8)
	game.popup(center() + Vector3.UP * 4.0, "COME HERE!", Color(0.8, 0.8, 1.0))


func _land(player) -> void:
	var dive := state == "dive"
	game.shake(0.7 if dive else 0.45)
	game.audio.play("explode")
	game.burst(global_position + Vector3.UP * 0.3, Models.VENOM_BLACK, 24, 9.0)
	var near: float = 7.0 if dive else 5.0
	var to: Vector3 = player.global_position - global_position
	if Vector2(to.x, to.z).length() < near + radius and to.y < 3.0:
		player.take_damage(25.0 if dive else 18.0, global_position, 16.0)
	if dive or phase == 2:
		game.ground_wave(global_position, 16.0, 15.0, Models.VENOM_BLACK)
	velocity = Vector3.ZERO
	_go("walk", 1.0)


func _animate(dt: float, walk: Vector3) -> void:
	var root: Node3D = model["root"]
	root.rotation.y = face_yaw
	Models.set_flash(root, flash > 0.0)
	var torso: Node3D = model["torso"]
	var head: Node3D = model["head"]
	var leg_l: Node3D = model["leg_l"]
	var leg_r: Node3D = model["leg_r"]
	var shin_l: Node3D = model["shin_l"]
	var shin_r: Node3D = model["shin_r"]
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	var hs := Vector2(walk.x, walk.z).length() if is_on_floor() else 0.0
	walk_phase += hs * dt * 0.45
	var run: float = min(1.0, hs / 5.0)
	var s := sin(walk_phase)
	torso.rotation = Vector3(-0.2 - 0.2 * run, 0, 0)
	head.rotation = Vector3(0.15, sin(t * 0.6) * 0.2, 0)
	leg_l.rotation = Vector3(0.15 + s * 0.7 * run, 0, -0.08)
	leg_r.rotation = Vector3(0.15 - s * 0.7 * run, 0, 0.08)
	shin_l.rotation.x = -0.3 - max(0.0, -cos(walk_phase)) * run
	shin_r.rotation.x = -0.3 - max(0.0, cos(walk_phase)) * run
	arm_l.rotation = Vector3(-s * 0.5 * run + 0.1, 0, -0.4)
	arm_r.rotation = Vector3(s * 0.5 * run + 0.1, 0, 0.4)
	fore_l.rotation.x = 0.6
	fore_r.rotation.x = 0.6
	var snarl := 0.0
	match state:
		"slash":  # claws raised high, then raked down
			var up := timer > 0.1
			arm_r.rotation = Vector3(-2.6 if up else -0.6, 0, 0.5)
			arm_l.rotation = Vector3(-2.4 if up else -0.8, 0, -0.5)
			fore_r.rotation.x = 0.3
			fore_l.rotation.x = 0.3
			snarl = 1.0
		"blast", "lash":
			arm_r.rotation = Vector3(-PI / 2, 0, 0.1)
			fore_r.rotation.x = 0.0
			snarl = 1.0
		"leap", "dive":
			leg_l.rotation.x = 0.9
			shin_l.rotation.x = -1.3
			leg_r.rotation.x = 0.4
			shin_r.rotation.x = -0.8
			arm_l.rotation = Vector3(-0.6, 0, -1.0)
			arm_r.rotation = Vector3(-0.6, 0, 1.0)
			snarl = 1.0
	if lash_t > 0.0:
		arm_r.rotation = Vector3(-PI / 2, 0, 0.1)
	(model["jaw"] as Node3D).rotation.x = 0.15 + 0.05 * sin(t * 3.0) + 0.3 * snarl
	var segs: Array = model["tongue_segs"]
	for i in segs.size():
		(segs[i] as Node3D).rotation = Vector3(-0.3 + sin(t * 6.0 - i * 0.9) * 0.3, sin(t * 4.0 - i * 0.7) * 0.35, 0)
	var strands: Array = model["strands"]
	for i in strands.size():
		(strands[i] as Node3D).rotation = Vector3(0.3 * run + sin(t * 2.5 + i) * 0.2, 0, sin(t * 3.1 + i * 1.7) * 0.2)
	# wings: out for good once he's angry, beating hard in a dive
	wing_open = move_toward(wing_open, 1.0 if phase == 2 else 0.0, dt * 2.0)
	var wings: Node3D = model["wings"]
	wings.visible = wing_open > 0.02
	wings.scale = Vector3.ONE * max(0.02, wing_open)
	var flap := sin(t * (13.0 if state == "dive" else 3.0)) * (0.55 if state == "dive" else 0.2)
	(model["wing_l"] as Node3D).rotation = Vector3(0, -0.35, -flap)
	(model["wing_r"] as Node3D).rotation = Vector3(0, 0.35, flap)
