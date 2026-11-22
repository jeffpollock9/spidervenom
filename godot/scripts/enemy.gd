class_name Enemy
extends CharacterBody3D
## Supercity robots (walkers and shooters) and Mr Poo's mini-poos.

const GRAVITY := 30.0

var game
var kind := "walker"     # walker | shooter | minipoo
var hp := 36.0
var max_hp := 36.0
var contact := 12.0
var radius := 0.55
var height := 1.6
var model: Dictionary
var t := 0.0
var timer := 1.0
var flash := 0.0
var dead := false
var dir := Vector3.LEFT   # patrol direction
var face_yaw := 0.0
var rng := RandomNumberGenerator.new()
var stun_t := 0.0          # webbed up by Spider-Man: can't move or shoot
var cocoon: Node3D


func _init(g, k: String) -> void:
	game = g
	kind = k
	collision_layer = 4
	collision_mask = 1
	match kind:
		"shooter":
			hp = 32.0
		"minipoo":
			hp = 28.0
			radius = 0.6
			height = 1.0
	max_hp = hp
	rng.randomize()
	timer = rng.randf_range(0.5, 2.0)
	t = rng.randf() * 5.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = max(height, 0.95)
	shape.shape = cap
	shape.position.y = cap.height / 2
	add_child(shape)
	model = Models.poo(1.3) if kind == "minipoo" else Models.robot(kind == "shooter")
	add_child(model["root"])
	face_yaw = atan2(-dir.x, -dir.z)


func center() -> Vector3:
	return global_position + Vector3(0, height * 0.55, 0)


func hurt(dmg: float, push: Vector3, knock := 8.0) -> void:
	if dead:
		return
	hp -= dmg
	flash = 0.12
	var p := Vector3(push.x, 0, push.z).normalized()
	velocity = p * knock + Vector3.UP * 4.0
	game.popup(center() + Vector3.UP, str(int(dmg)), Color.WHITE)
	if hp <= 0.0:
		die()


func web(secs: float) -> void:
	if dead:
		return
	stun_t = max(stun_t, secs)
	if cocoon == null:
		cocoon = Models.web_cocoon(radius * 1.5, height * 1.1)
		cocoon.position.y = height * 0.5
		add_child(cocoon)
	cocoon.visible = true


func die() -> void:
	dead = true
	game.burst(center(), Color(1.0, 0.85, 0.4), 18, 8.0)
	game.score += 100
	queue_free()


func tick(dt: float) -> void:
	t += dt
	flash = max(0.0, flash - dt)
	var player = game.player
	var to: Vector3 = player.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var can_see: bool = not player.dead
	var h := Vector2(velocity.x, velocity.z)
	var k := kind
	if stun_t > 0.0:
		stun_t -= dt
		k = "stuck"
		h = h.move_toward(Vector2.ZERO, 30.0 * dt)
		if stun_t <= 0.0 and cocoon:
			cocoon.visible = false
	match k:
		"walker":
			var chase: bool = can_see and dist < 18.0 and abs(to.y) < 3.5
			if chase:
				dir = flat.normalized()
			if is_on_floor() and flash <= 0.0:
				var spd := 5.0 if chase else 2.5
				if not chase and (is_on_wall() or not _ground_ahead()):
					dir = -dir
				if chase and not _ground_ahead():
					spd = 0.0
				h = h.move_toward(Vector2(dir.x, dir.z) * spd, 30.0 * dt)
		"shooter":
			h = h.move_toward(Vector2.ZERO, 20.0 * dt)
			if can_see and dist < 30.0:
				dir = flat.normalized()
				timer -= dt
				if timer <= 0.0:
					timer = rng.randf_range(1.6, 2.4)
					var from := center() + dir * 0.7 + Vector3(0.3, 0.1, 0)
					var aimv: Vector3 = (player.center() - from).normalized()
					game.spawn_projectile(from, aimv * 17.0, "enemy", "bolt", 9.0, 0.3, {"life": 2.5})
					game.audio.play("shoot")
		"minipoo":
			if is_on_floor():
				h = h.move_toward(Vector2.ZERO, 15.0 * dt)
				timer -= dt
				if timer <= 0.0:
					timer = rng.randf_range(0.8, 1.6)
					if can_see and dist < 25.0:
						dir = flat.normalized()
					velocity.y = rng.randf_range(9.0, 11.0)
					h = Vector2(dir.x, dir.z) * 6.0
	velocity.x = h.x
	velocity.z = h.y
	velocity.y = max(velocity.y - GRAVITY * dt, -40.0)
	move_and_slide()
	if global_position.y < -25.0:
		dead = true
		queue_free()
		return
	face_yaw = lerp_angle(face_yaw, atan2(-dir.x, -dir.z), min(1.0, 8.0 * dt))
	var root: Node3D = model["root"]
	root.rotation.y = face_yaw
	Models.set_flash(root, flash > 0.0)
	if kind == "minipoo":
		Models.animate_poo(model, t, true, Vector3.ZERO)
	else:
		(model["body"] as Node3D).rotation.z = sin(t * 9.0) * 0.04 * min(1.0, h.length())


func _ground_ahead() -> bool:
	var from := global_position + dir * 0.9 + Vector3.UP * 0.5
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * 2.0, 1)
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
