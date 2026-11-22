class_name Cattoon
extends Boss
## Ms Cattoon: a giant stinky cartoon cat-lady. She stinks: a green cloud hangs round her
## all the time and standing in it hurts. She stomps after you, fires stink clouds that
## hang in the air, and swings her handbag if you get close. When she's angry (half health)
## she sets off a huge STINK BOMB: get up high or get out of the way!

const SCALE := 1.5  # the model is built 6 m tall; she's 9 m
const AURA_R := 8.5
const AURA_DMG := 4.0

var aura_t := 0.0
var puff := 0.0
var choices := 0


func _init(g) -> void:
	super(g)
	boss_name = "Ms Cattoon"
	max_hp = 650.0
	hp = max_hp
	contact = 18.0
	radius = 1.9 * SCALE
	height = 6.0 * SCALE


func _ready() -> void:
	collision_mask = 1  # wades straight through the plaza platforms
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 1.6 * SCALE
	cap.height = height
	shape.shape = cap
	shape.position.y = height / 2
	add_child(shape)
	model = Models.cattoon()
	(model["root"] as Node3D).scale = Vector3.ONE * SCALE
	add_child(model["root"])


func aura_radius() -> float:
	return AURA_R * (1.25 if phase == 2 else 1.0)


func tick(dt: float) -> void:
	t += dt
	flash = max(0.0, flash - dt)
	var player = game.player
	var to: Vector3 = player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var spd := 1.35 if phase == 2 else 1.0
	var walk := Vector3.ZERO
	if active and not dead:
		_stink_aura(player, flat, dt)
	if _tick_stun(dt):
		pass
	elif active and not dead and player.hiding:
		walk = Vector3(sin(t * 0.7), 0, cos(t * 0.5)) * 1.5  # sniffing about: where's he gone?
	elif active and not dead:
		timer -= dt * spd
		walk = _think(player, flat, spd)
	velocity.x = walk.x
	velocity.z = walk.z
	velocity.y = max(velocity.y - GRAVITY * dt, -50.0)
	move_and_slide()
	if flat.length() > 0.5:
		face_yaw = lerp_angle(face_yaw, atan2(-flat.x, -flat.z), min(1.0, 3.0 * dt))
	puff = move_toward(puff, 1.0 if state == "bomb" else 0.0, dt * 1.2)
	var root: Node3D = model["root"]
	root.rotation.y = face_yaw
	Models.set_flash(root, flash > 0.0)
	Models.animate_cattoon(model, t, phase == 2, puff, (aura_radius() if active else 0.01) / SCALE)
	var arm_r: Node3D = model["arm_r"]
	arm_r.rotation = Vector3(0, 0, 0.15)
	if state == "bag":  # handbag wound up behind her, then swung round
		arm_r.rotation = Vector3(1.6 if timer > 0.0 else -1.4, 0, 0.5)
	(model["arm_l"] as Node3D).rotation = Vector3(sin(t * 2.0) * 0.2, 0, -0.15)


func _stink_aura(player, flat: Vector3, dt: float) -> void:
	## Standing near her hurts. Even when she's webbed up.
	aura_t -= dt
	var dy: float = player.global_position.y - global_position.y
	if flat.length() < aura_radius() and dy < height and aura_t <= 0.0 and not player.dead:
		aura_t = 0.9
		if player.take_damage(AURA_DMG, global_position, 1.0) and randf() < 0.5:
			player.say("*cough* *cough* PHWOAR!", 1.0)


func _think(player, flat: Vector3, spd: float) -> Vector3:
	var dist := flat.length()
	var dir := flat.normalized() if dist > 0.1 else Vector3.ZERO
	match state:
		"idle", "walk":
			if timer <= 0.0:
				choices += 1
				if phase == 2 and choices % 3 == 0:
					_go("bomb", 1.4)
					game.popup(center() + Vector3.UP * 4.0, "!!!", Color(0.6, 1.0, 0.2))
					game.audio.play("roar")
				elif dist < 8.5:
					_go("bag", 0.55)
				elif rng.randf() < 0.55:
					_go("stink", 0.5)
				else:
					_go("walk", rng.randf_range(1.2, 2.2))
			if state == "walk" and dist > 3.0:
				return dir * 3.5 * spd
		"bag":
			if timer <= 0.0:
				if dist < 9.0 and abs(player.global_position.y - global_position.y) < 5.0:
					player.take_damage(20.0, global_position, 14.0)
				game.audio.play("punch")
				_go("walk", 0.8)
		"stink":
			if timer <= 0.0:
				_fire_stink(player)
				_go("walk", rng.randf_range(1.0, 1.8))
		"bomb":
			if timer <= 0.0:
				game.add_stink_cloud(global_position, 14.0, 5.0, 5.0, 10.0, true)
				game.banner("STINK BOMB!", 1.2)
				game.audio.play("explode")
				game.shake(0.6)
				_go("walk", 1.5)
	return Vector3.ZERO


func _fire_stink(player) -> void:
	var n := 1 if phase == 1 else 3
	var from := global_position + Vector3(0, height * 0.75, 0)
	var target: Vector3 = player.global_position
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	var side := flat.normalized().cross(Vector3.UP)
	for i in n:
		var tp := target + side * (float(i) - (n - 1) / 2.0) * 4.0
		var tf := 1.2
		var g := 14.0
		var v := Vector3((tp.x - from.x) / tf, (tp.y - from.y + 0.5 * g * tf * tf) / tf, (tp.z - from.z) / tf)
		game.spawn_projectile(from, v, "enemy", "stink", 8.0, 0.7, {"gravity": g, "life": 4.0, "knock": 3.0})
	game.audio.play("blob")
