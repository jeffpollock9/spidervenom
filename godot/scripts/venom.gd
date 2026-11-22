class_name Venom
extends CharacterBody3D
## The player: Venom. Runs, jumps, punches, fires symbiote blasts, swings on a tendril,
## flies on symbiote wings and, at full energy, clears the area with a symbiote blast.

const GRAVITY := 30.0
const SPEED := 9.0
const JUMP := 12.5
const FLY_SPEED := 15.0
const FLY_CEILING := 92.0
const MAX_HP := 140.0
const PUNCH_DAMAGE := 20.0
const PUNCH_REACH := 3.2
const BLAST_COST := 14.0
const SWING_COST := 3.0

var game  # Main
var rig: CameraRig
var model: Dictionary
var hp := MAX_HP
var energy := 100.0
var invuln := 0.0
var cd := 0.0
var punch_t := 0.0
var shoot_t := 0.0
var coyote := 0.0
var jump_buf := 0.0
var flying := false
var wing_open := 0.0
var flap_sound_t := 0.0
var anchor := Vector3.ZERO
var swinging := false
var swing_t := 0.0
var rope := 0.0
var safe_pos := Vector3.ZERO
var dead := false
var t := 0.0
var face_yaw := -PI / 2
var walk_phase := 0.0
var aim := Vector3.ZERO
var message := ""
var message_t := 0.0
var tendril: Node3D
var radius := 0.55
var camera_close := false  # hide the model when the camera is jammed against him


func _init(g) -> void:
	game = g
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5
	cap.height = 2.3
	shape.shape = cap
	shape.position.y = 1.15
	add_child(shape)
	model = Models.venom()
	add_child(model["root"])
	tendril = Node3D.new()
	tendril.top_level = true
	add_child(tendril)
	var black := Models.mat(Models.VENOM_BLACK, 0.25, 0.2, 0.0, 0.6)
	for i in 14:
		Models.part(tendril, Models.cylinder(0.09, 0.09, 1.0, 6), black)
	tendril.visible = false
	safe_pos = global_position


func center() -> Vector3:
	return global_position + Vector3(0, 1.3, 0)


func hand() -> Vector3:
	return global_position + Vector3(0, 1.9, 0) + Vector3(-sin(face_yaw), 0, -cos(face_yaw)) * 0.7


func say(text: String, secs := 1.4) -> void:
	message = text
	message_t = secs


func info_line() -> String:
	if swinging:
		return "SWINGING"
	if flying:
		return "FLYING"
	if energy >= 100:
		return "F: SYMBIOTE BLAST READY!"
	return ""


# ------------------------------------------------------------------ update

func tick(ctl: Controls, dt: float) -> void:
	t += dt
	invuln = max(0.0, invuln - dt)
	cd = max(0.0, cd - dt)
	punch_t = max(0.0, punch_t - dt)
	shoot_t = max(0.0, shoot_t - dt)
	message_t = max(0.0, message_t - dt)
	energy = min(100.0, energy + 14.0 * dt)
	aim = ctl.aim_override if ctl.aim_override != null else rig.aim_point(get_rid())

	var wish := rig.right() * ctl.move.x + rig.forward() * ctl.move.y
	if wish.length() > 1.0:
		wish = wish.normalized()

	if ctl.alt_pressed or (ctl.alt_held and not swinging and not is_on_floor() and _aim_up() > 0.2):
		try_swing(ctl.alt_pressed)
	elif swinging and not ctl.alt_held:
		release_swing()

	if swinging:
		swing_move(ctl, wish, dt)
	elif flying:
		fly_move(ctl, wish, dt)
	else:
		walk_move(ctl, wish, dt)

	if ctl.primary_pressed and cd <= 0.0:
		punch()
	if ctl.special_pressed and cd <= 0.0 and energy >= BLAST_COST:
		blast()
	if ctl.ult_pressed:
		ultimate()

	if global_position.y < -25.0:
		fell()
	elif is_on_floor() and _on_safe_ground():
		safe_pos = global_position

	_update_facing(wish, dt)
	_animate(dt)


func _aim_up() -> float:
	return (aim - center()).normalized().y


func _on_safe_ground() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var col = c.get_collider()
		if c.get_normal().y > 0.7 and col is Node and (col as Node).is_in_group("safe"):
			return true
	return false


func walk_move(ctl: Controls, wish: Vector3, dt: float) -> void:
	var spd := SPEED
	var accel := 60.0 if is_on_floor() else 25.0
	if game.in_puddle(self):
		spd *= 0.55
		accel = 10.0
	var h := Vector2(velocity.x, velocity.z).move_toward(Vector2(wish.x, wish.z) * spd, accel * dt)
	velocity.x = h.x
	velocity.z = h.y
	if ctl.jump_pressed:
		jump_buf = 0.12
	else:
		jump_buf = max(0.0, jump_buf - dt)
	if jump_buf > 0.0 and coyote > 0.0:
		velocity.y = JUMP
		jump_buf = 0.0
		coyote = 0.0
		game.audio.play("jump")
	elif ctl.jump_pressed and coyote <= 0.0 and not is_on_floor():
		start_flying()
		return
	var g := GRAVITY
	if not ctl.jump_held and velocity.y > 0.0:
		g *= 2.2
	velocity.y = max(velocity.y - g * dt, -40.0)
	move_and_slide()
	coyote = 0.1 if is_on_floor() else max(0.0, coyote - dt)


func start_flying() -> void:
	flying = true
	jump_buf = 0.0
	velocity.y = max(velocity.y, 6.0)
	game.audio.play("flap")


func fly_move(ctl: Controls, wish: Vector3, dt: float) -> void:
	var vy := -0.6
	if ctl.jump_held:
		vy = 9.0
	elif ctl.down_held:
		vy = -11.0
	var target := Vector3(wish.x * FLY_SPEED, vy, wish.z * FLY_SPEED)
	velocity = velocity.lerp(target, min(1.0, 5.0 * dt))
	move_and_slide()
	if global_position.y > FLY_CEILING:
		global_position.y = FLY_CEILING
		velocity.y = min(velocity.y, 0.0)
	coyote = 0.0
	flap_sound_t -= dt
	if flap_sound_t <= 0.0:
		flap_sound_t = 0.45 if velocity.y > 1.0 else 0.8
		game.audio.play("flap")
	if is_on_floor() and not ctl.jump_held:
		flying = false


func try_swing(pressed: bool) -> void:
	if swinging or energy < SWING_COST:
		return
	var from := center() + Vector3(0, 0.6, 0)
	var dir := (aim - from).normalized()
	if not pressed and dir.y < 0.2:
		return
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 70.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var point: Vector3
	if hit and (hit.position as Vector3).y > global_position.y + 1.0:
		point = hit.position
	elif dir.y > 0.25:
		point = from + dir * 32.0  # nothing to grab: stick to the sky, like the comics
	else:
		return
	anchor = point
	rope = max(3.0, from.distance_to(point))
	swinging = true
	swing_t = 0.0
	if is_on_floor() or coyote > 0.0:  # the tendril yanks him up off the street
		var pull := (point - from).normalized()
		velocity = Vector3(velocity.x, 0, velocity.z) + pull * 12.0 + Vector3.UP * 6.0
		rope *= 0.94
	flying = false
	energy -= SWING_COST
	game.audio.play("blob")


func release_swing() -> void:
	swinging = false
	if velocity.y > 0.0:
		velocity.y *= 1.15


func swing_move(ctl: Controls, wish: Vector3, dt: float) -> void:
	swing_t += dt
	velocity += wish * 18.0 * dt
	if ctl.jump_held:
		rope = max(3.0, rope - 10.0 * dt)
	velocity.y -= GRAVITY * dt
	var p := center() + Vector3(0, 0.6, 0)
	var nxt := p + velocity * dt
	var d := nxt - anchor
	if d.length() > rope:
		nxt = anchor + d.normalized() * rope
		velocity = (nxt - p) / dt
	velocity = velocity.limit_length(32.0)
	move_and_slide()
	coyote = 0.0
	if swing_t > 0.4 and is_on_floor() and velocity.y <= 0.0:
		swinging = false


func punch() -> void:
	_face_aim()
	cd = 0.42
	punch_t = 0.3
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var hits := 0
	for e in game.targets():
		var to: Vector3 = e.center() - center()
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < PUNCH_REACH + e.radius and abs(to.y) < 2.6 and fwd.dot(flat.normalized()) > 0.2:
			e.hurt(PUNCH_DAMAGE, fwd, 12.0)
			hits += 1
	game.audio.play("hit" if hits else "punch")


func blast() -> void:
	_face_aim()
	energy -= BLAST_COST
	cd = 0.4
	shoot_t = 0.3
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 34.0, "player", "symbiote", 22.0, 0.55, {"knock": 12.0, "life": 1.4})
	game.audio.play("blob")


func ultimate() -> void:
	if energy < 100.0:
		say("Need full energy!")
		return
	energy = 0.0
	invuln = max(invuln, 1.0)
	game.symbiote_blast(center())


func take_damage(amount: float, from_pos: Vector3, knock := 8.0) -> bool:
	if invuln > 0.0 or dead:
		return false
	hp -= amount
	invuln = 0.9
	var away := global_position - from_pos
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * knock + Vector3.UP * min(9.0, knock)
	swinging = false
	game.audio.play("hurt")
	game.shake(0.25)
	game.popup(center() + Vector3.UP, "-%d" % int(amount), Color(1, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
	return true


func heal(amount: float) -> void:
	hp = min(MAX_HP, hp + amount)


func fell() -> void:
	swinging = false
	flying = false
	global_position = safe_pos + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	hp -= 15.0
	invuln = 1.2
	game.audio.play("hurt")
	game.popup(center() + Vector3.UP, "-15", Color(1, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true


# ------------------------------------------------------------------ looks

func _face_aim() -> void:
	var d := aim - global_position
	face_yaw = atan2(-d.x, -d.z)


func _update_facing(wish: Vector3, dt: float) -> void:
	var target_yaw := face_yaw
	if punch_t > 0.0 or shoot_t > 0.0:
		var d := aim - global_position
		target_yaw = atan2(-d.x, -d.z)
	else:
		var hv := Vector3(velocity.x, 0, velocity.z)
		if hv.length() > 1.0:
			target_yaw = atan2(-hv.x, -hv.z)
	face_yaw = lerp_angle(face_yaw, target_yaw, min(1.0, 14.0 * dt))


func _animate(dt: float) -> void:
	var root: Node3D = model["root"]
	root.rotation.y = face_yaw
	root.visible = (dead or invuln <= 0.0 or int(invuln * 20.0) % 2 == 1) and not camera_close
	var torso: Node3D = model["torso"]
	var leg_l: Node3D = model["leg_l"]
	var leg_r: Node3D = model["leg_r"]
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var hspeed := Vector2(velocity.x, velocity.z).length()
	walk_phase += hspeed * dt * 1.5
	var swing_amt: float = min(1.0, hspeed / SPEED) if is_on_floor() else 0.0
	var s := sin(walk_phase) * 0.9 * swing_amt
	leg_l.rotation.x = s
	leg_r.rotation.x = -s
	arm_l.rotation = Vector3(-s * 0.8, 0, -0.15)
	arm_r.rotation = Vector3(s * 0.8, 0, 0.15)
	torso.rotation.x = 0.0
	if not is_on_floor() and not flying:
		leg_l.rotation.x = -0.7
		leg_r.rotation.x = 0.35
		arm_l.rotation = Vector3(-0.4, 0, -0.6)
		arm_r.rotation = Vector3(-0.4, 0, 0.6)
	if flying:
		var lean: float = clamp(hspeed / FLY_SPEED, 0.0, 1.0)
		torso.rotation.x = -0.6 * lean
		leg_l.rotation.x = 0.4 * lean + 0.15 * sin(t * 3.0)
		leg_r.rotation.x = 0.5 * lean
		arm_l.rotation = Vector3(0.3, 0, -0.5)
		arm_r.rotation = Vector3(0.3, 0, 0.5)
	if swinging:
		arm_r.rotation = Vector3(-PI + 0.2, 0, 0.1)
	if punch_t > 0.0:
		var k := sin((1.0 - punch_t / 0.3) * PI)
		arm_r.rotation = Vector3(-PI / 2 * (0.4 + 0.8 * k), 0, 0.1)
		torso.rotation.y = -0.3 * k
	else:
		torso.rotation.y = 0.0
	if shoot_t > 0.0:
		arm_r.rotation = Vector3(-PI / 2, 0, 0.05)
	(model["tongue"] as Node3D).rotation.x = sin(t * 7.0) * 0.35
	(model["head"] as Node3D).rotation.x = -0.15 if flying else 0.0

	# wings spread while flying, fold away on landing
	wing_open = move_toward(wing_open, 1.0 if flying else 0.0, dt * (5.0 if flying else 3.0))
	var wings: Node3D = model["wings"]
	wings.visible = wing_open > 0.02
	wings.scale = Vector3.ONE * max(0.02, wing_open)
	var rate := 13.0 if velocity.y > 1.0 else 8.0
	var flap := sin(t * rate) * 0.55
	(model["wing_l"] as Node3D).rotation = Vector3(0, -0.35, -flap)
	(model["wing_r"] as Node3D).rotation = Vector3(0, 0.35, flap)

	# the tendril: a wriggling black line from his hand to the anchor
	tendril.visible = swinging
	if swinging:
		var a := global_position + Vector3(0, 2.4, 0) + Vector3(-sin(face_yaw), 0, -cos(face_yaw)) * 0.3
		var b := anchor
		var n := tendril.get_child_count()
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var prev := a
		for i in n:
			var f := float(i + 1) / n
			var wob := sin(f * 10.0 - t * 18.0) * 0.25 * sin(f * PI)
			var p := a.lerp(b, f) + side * wob
			var seg := tendril.get_child(i) as MeshInstance3D
			seg.global_position = (prev + p) * 0.5
			var dir := p - prev
			seg.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
			prev = p
