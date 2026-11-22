class_name MrPoo
extends Boss
## Supercity's first boss. Hops at you, lobs poo that leaves slippery puddles, and when he's
## angry (half health) he throws more, slams the ground and spawns mini-poos.

const SIZE := 5.0

var was_on_floor := true


func _init(g) -> void:
	super(g)
	boss_name = "Mr Poo"
	max_hp = 610.0
	hp = max_hp
	contact = 16.0
	radius = 2.3
	height = 4.4


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 2.1
	cyl.height = height
	shape.shape = cyl
	shape.position.y = height / 2
	add_child(shape)
	model = Models.poo(SIZE)
	add_child(model["root"])


func tick(dt: float) -> void:
	t += dt
	flash = max(0.0, flash - dt)
	var player = game.player
	var to: Vector3 = player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var speed := 1.3 if phase == 2 else 1.0
	if _tick_stun(dt):
		pass
	elif active and not dead and player.hiding and state != "hop":
		pass  # where did he go? (Charley is hiding)
	elif active and not dead:
		timer -= dt * speed
		_think(player, flat, speed)
	if is_on_floor():
		velocity.x *= 0.85
		velocity.z *= 0.85
	velocity.y = max(velocity.y - GRAVITY * dt, -50.0)
	move_and_slide()
	var landed := is_on_floor() and not was_on_floor
	was_on_floor = is_on_floor()
	if landed and active:
		game.shake(0.35)
		game.audio.play("splat")
		game.burst(global_position + Vector3.UP * 0.3, Color(0.5, 0.33, 0.15), 14, 7.0)
		if phase == 2 and state == "hop":
			game.ground_wave(global_position, 14.0, 14.0)
	if flat.length() > 0.5 and (state != "hop" or is_on_floor()):
		face_yaw = lerp_angle(face_yaw, atan2(-flat.x, -flat.z), min(1.0, 4.0 * dt))
	var root: Node3D = model["root"]
	root.rotation.y = face_yaw
	Models.set_flash(root, flash > 0.0)
	var local_look: Vector3 = root.global_basis.inverse() * (player.center() - center()).normalized()
	Models.animate_poo(model, t, phase == 2, Vector3(-local_look.x, local_look.y, 0))
	if state == "lob" and timer < 0.3:
		(model["squash"] as Node3D).scale *= Vector3(1.08, 0.9, 1.08)


func _think(player, flat: Vector3, _speed: float) -> void:
	match state:
		"idle", "hop":
			if is_on_floor() and timer <= 0.0:
				var r := rng.randf()
				if r < 0.45:
					velocity.y = rng.randf_range(13.0, 16.0)
					var reach: float = min(9.0, flat.length() * 0.9)
					var d := flat.normalized()
					velocity.x = d.x * reach
					velocity.z = d.z * reach
					_go("hop", 1.0)
				elif r < 0.85 or phase == 1:
					_go("lob", 0.6)
				else:
					_go("spawn", 0.5)
		"lob":
			if timer <= 0.0:
				_lob(player)
				_go("hop", rng.randf_range(1.0, 1.8))
		"spawn":
			if timer <= 0.0:
				var alive := 0
				for e in game.enemies:
					if is_instance_valid(e) and not e.dead and e.kind == "minipoo":
						alive += 1
				for i in min(2, 4 - alive):
					var off := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
					game.spawn_enemy("minipoo", global_position + off + Vector3.UP * 0.5)
				game.audio.play("splat")
				_go("hop", 1.5)


func _lob(player) -> void:
	var n := 3 if phase == 1 else 5
	var from := global_position + Vector3(0, height * 0.9, 0)
	var target: Vector3 = player.global_position
	var flat := Vector3(target.x - from.x, 0, target.z - from.z)
	var side := flat.normalized().cross(Vector3.UP)
	for i in n:
		var tp := target + side * (float(i) - (n - 1) / 2.0) * 3.2
		var tf := 1.1
		var g := 18.0
		var v := Vector3((tp.x - from.x) / tf, (tp.y - from.y + 0.5 * g * tf * tf) / tf, (tp.z - from.z) / tf)
		game.spawn_projectile(from, v, "enemy", "poo", 12.0, 0.5, {"gravity": g, "life": 4.0})
	game.audio.play("splat")
