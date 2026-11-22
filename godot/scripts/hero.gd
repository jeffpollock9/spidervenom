class_name Hero
extends CharacterBody3D
## The shared player code: running, jumping, punching, swinging on a line, flying (if the
## hero can), wall-crawling (if the hero can), taking hits and falling. Each hero (Venom,
## Spiderman) extends this, sets its stats in _init and builds its own model and powers.

const GRAVITY := 30.0
const FLY_CEILING := 92.0

# --- stats, set by each hero in _init
var hero_name := "HERO"
var colour := Color.WHITE          # HUD name colour
var size := 1.0                    # model scale; collision, camera and reach follow it
var max_hp := 140.0
var speed := 9.0
var jump := 12.5
var punch_damage := 20.0
var punch_reach := 4.0
var punch_cd := 0.42
var punch_knock := 12.0
var blast_cost := 14.0
var swing_cost := 3.0
var swing_max_speed := 32.0
var swing_pull := 18.0
var can_fly := false
var fly_speed := 15.0
var can_climb := false
var climb_speed := 8.0
var air_jumps := 0
var can_sprint := false            # SHIFT sprints instead of swinging
var sprint_speed := 30.0
var can_pound := false             # CTRL in mid-air slams down
var regen := 0.0
var invincible := false            # nothing can hurt him
var can_jetpack := false           # SHIFT (hold) is a jetpack
var can_hide := false              # SHIFT (hold) hides: robots stop bothering with him
var custom_shift := false          # the hero handles SHIFT himself (in _pre_tick)                   # health per second, once he's gone a while without a hit
var ult_ready_text := "F: ULTIMATE READY!"
var hint := ""
var rope_radius := 0.12

var game  # Main
var rig: CameraRig
var model: Dictionary
var hp := 0.0
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
var climbing := false
var wall_n := Vector3.ZERO
var air_jumps_left := 0
var flip_t := 0.0
var sprinting := false
var pounding := false
var hurt_t := 99.0
var ram_cd := 0.0
var jetting := false
var hiding := false


func _init(g) -> void:
	game = g
	_setup()
	hp = max_hp
	radius = 0.55 * size
	collision_layer = 2
	collision_mask = 1 | 16  # the world, plus the plaza platforms (layer 16)
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)


func _setup() -> void:
	pass  # heroes set their stats here


func _build_model() -> Dictionary:
	return {}


func _rope_material() -> Material:
	return Models.venom_skin()


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.5 * size
	cap.height = 2.5 * size
	shape.shape = cap
	shape.position.y = 1.25 * size
	add_child(shape)
	model = _build_model()
	add_child(model["root"])
	tendril = Node3D.new()
	tendril.top_level = true
	add_child(tendril)
	for i in 14:
		Models.part(tendril, Models.cylinder(rope_radius, rope_radius, 1.0, 8), _rope_material())
	tendril.visible = false
	safe_pos = global_position


func center() -> Vector3:
	return global_position + Vector3(0, 1.3 * size, 0)


func hand() -> Vector3:
	return global_position + Vector3(0, 1.9 * size, 0) + Vector3(-sin(face_yaw), 0, -cos(face_yaw)) * 0.7 * size


func say(text: String, secs := 1.4) -> void:
	message = text
	message_t = secs


func info_line() -> String:
	if swinging:
		return "SWINGING"
	if flying:
		return "FLYING"
	if climbing:
		return "WALL-CRAWLING"
	if jetting:
		return "JETPACK"
	if energy >= 100:
		return ult_ready_text
	return ""


# ------------------------------------------------------------------ update

func _pre_tick(_ctl: Controls, _dt: float) -> void:
	pass  # hero-specific per-frame stuff before moving (e.g. Charley getting puffed out)


func tick(ctl: Controls, dt: float) -> void:
	t += dt
	_pre_tick(ctl, dt)
	invuln = max(0.0, invuln - dt)
	cd = max(0.0, cd - dt)
	punch_t = max(0.0, punch_t - dt)
	shoot_t = max(0.0, shoot_t - dt)
	message_t = max(0.0, message_t - dt)
	flip_t = max(0.0, flip_t - dt)
	ram_cd = max(0.0, ram_cd - dt)
	hurt_t += dt
	if regen > 0.0 and hurt_t > 2.0 and not dead and hp < max_hp:
		heal(regen * dt)
	energy = min(100.0, energy + 14.0 * dt)
	aim = ctl.aim_override if ctl.aim_override != null else rig.aim_point(get_rid())

	var wish := rig.right() * ctl.move.x + rig.forward() * ctl.move.y
	if wish.length() > 1.0:
		wish = wish.normalized()

	# SHIFT: each hero uses it for one thing
	if custom_shift:
		pass
	elif can_hide:
		hiding = ctl.alt_held and is_on_floor() and not dead
		if hiding:
			wish = Vector3.ZERO
	elif can_jetpack:
		var was_jet := jetting
		jetting = ctl.alt_held and energy > 1.0
		if jetting and not was_jet:
			game.audio.play("whoosh")
	elif can_sprint:
		var was := sprinting
		sprinting = ctl.alt_held and wish.length() > 0.1
		if sprinting and not was:
			game.audio.play("whoosh")
	elif ctl.alt_pressed or (ctl.alt_held and not swinging and not is_on_floor() and _aim_up() > 0.2):
		try_swing(ctl.alt_pressed)
	elif swinging and not ctl.alt_held:
		release_swing()

	if swinging:
		swing_move(ctl, wish, dt)
	elif climbing:
		climb_move(ctl, wish, dt)
	elif flying:
		fly_move(ctl, wish, dt)
	else:
		walk_move(ctl, wish, dt)

	if ctl.primary_pressed and cd <= 0.0:
		punch()
	if ctl.special_pressed and cd <= 0.0 and energy >= blast_cost:
		special()
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
	var spd := sprint_speed if sprinting else speed
	var accel := (60.0 if is_on_floor() else 25.0) * (2.0 if sprinting else 1.0)
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
		velocity.y = jump
		jump_buf = 0.0
		coyote = 0.0
		game.audio.play("jump")
	elif ctl.jump_pressed and coyote <= 0.0 and not is_on_floor():
		if can_fly:
			start_flying()
			return
		if air_jumps_left > 0:  # a somersault in mid-air
			air_jumps_left -= 1
			velocity.y = jump * 0.95
			jump_buf = 0.0
			flip_t = 0.5
			game.audio.play("jump")
	if can_pound and ctl.down_held and not pounding and not is_on_floor() and coyote <= 0.0:
		pounding = true  # GROUND POUND: straight down, fast
		velocity = Vector3(velocity.x * 0.2, -40.0, velocity.z * 0.2)
		game.audio.play("whoosh")
	if jetting:  # thrust up, burning energy
		velocity.y = min(velocity.y + 62.0 * dt, 11.0)
		energy = max(0.0, energy - 26.0 * dt)
		coyote = 0.0
	var g := GRAVITY
	if not ctl.jump_held and velocity.y > 0.0 and not jetting:
		g *= 2.2
	velocity.y = max(velocity.y - g * dt, -40.0)
	move_and_slide()
	coyote = 0.1 if is_on_floor() else max(0.0, coyote - dt)
	if is_on_floor():
		air_jumps_left = air_jumps
		if pounding:
			pounding = false
			_pound_landed()
	if can_climb and is_on_wall() and wish.length() > 0.3:
		var n := get_wall_normal()
		if abs(n.y) < 0.3 and wish.dot(-n) > 0.5:
			start_climb(n)


# ------------------------------------------------------------------ wall-crawling

func start_climb(n: Vector3) -> void:
	climbing = true
	flying = false
	wall_n = Vector3(n.x, 0, n.z).normalized()
	velocity = Vector3.ZERO
	face_yaw = atan2(wall_n.x, wall_n.z)


func climb_move(ctl: Controls, wish: Vector3, dt: float) -> void:
	## Stick to the wall: pushing towards it climbs, pulling away climbs down, sideways slides.
	var side := wall_n.cross(Vector3.UP)
	var up := wish.dot(-wall_n)
	if ctl.down_held:
		up = -1.0
	velocity = Vector3.UP * up * climb_speed + side * wish.dot(side) * climb_speed * 0.8 - wall_n * 3.0
	coyote = 0.0
	if ctl.jump_pressed:  # leap off the wall
		climbing = false
		velocity = wall_n * 10.0 + Vector3.UP * jump
		air_jumps_left = air_jumps
		game.audio.play("jump")
		return
	move_and_slide()
	if is_on_floor() and up < -0.1:  # climbed back down to the ground: let go
		climbing = false
		return
	if is_on_wall():
		var n := get_wall_normal()
		if abs(n.y) < 0.3:
			wall_n = Vector3(n.x, 0, n.z).normalized()
		return
	climbing = false
	if up > 0.1:  # reached the top: vault up onto the roof
		velocity = Vector3.UP * 9.0 - wall_n * 5.0
		game.audio.play("jump")
	elif is_on_floor():
		pass
	air_jumps_left = air_jumps


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
	var target := Vector3(wish.x * fly_speed, vy, wish.z * fly_speed)
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
	if swinging or energy < swing_cost:
		return
	var from := center() + Vector3(0, 0.6, 0)
	var dir := (aim - from).normalized()
	if not pressed and dir.y < 0.2:
		return
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * 70.0, 1 | 16, [get_rid()])
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
	climbing = false
	energy -= swing_cost
	game.audio.play(_swing_sound())


func _swing_sound() -> String:
	return "blob"


func release_swing() -> void:
	swinging = false
	if velocity.y > 0.0:
		velocity.y *= 1.15


func swing_move(ctl: Controls, wish: Vector3, dt: float) -> void:
	swing_t += dt
	velocity += wish * swing_pull * dt
	if ctl.jump_held:
		rope = max(3.0, rope - 10.0 * dt)
	velocity.y -= GRAVITY * dt
	var p := center() + Vector3(0, 0.6, 0)
	var nxt := p + velocity * dt
	var d := nxt - anchor
	if d.length() > rope:
		nxt = anchor + d.normalized() * rope
		velocity = (nxt - p) / dt
	velocity = velocity.limit_length(swing_max_speed)
	move_and_slide()
	coyote = 0.0
	if swing_t > 0.4 and is_on_floor() and velocity.y <= 0.0:
		swinging = false
	air_jumps_left = air_jumps


func punch() -> int:
	_face_aim()
	cd = punch_cd
	punch_t = min(0.3, punch_cd * 0.75)
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var hits := 0
	for e in game.targets():
		var to: Vector3 = e.center() - center()
		var flat := Vector3(to.x, 0, to.z)
		if flat.length() < punch_reach + e.radius and abs(to.y) < 2.0 * size + 0.6 and fwd.dot(flat.normalized()) > 0.2:
			e.hurt(punch_damage, fwd, punch_knock)
			hits += 1
	game.audio.play("hit" if hits else "punch")
	return hits


func special() -> void:
	pass  # RIGHT CLICK: each hero's ranged power


func ultimate() -> void:
	if energy < 100.0:
		say("Need full energy!")
		return
	energy = 0.0
	invuln = max(invuln, 1.0)
	_ultimate_effect()


func _ultimate_effect() -> void:
	pass


func _pound_landed() -> void:
	pass


func _blocked() -> void:
	pass  # an invincible hero shrugged off a hit


func rams() -> bool:
	## True while he's running fast enough to flatten whatever he runs into.
	return sprinting and Vector2(velocity.x, velocity.z).length() > speed * 1.2


func take_damage(amount: float, from_pos: Vector3, knock := 8.0) -> bool:
	if invuln > 0.0 or dead:
		return false
	if invincible:  # bounces right off
		var push := global_position - from_pos
		push.y = 0
		velocity += push.normalized() * min(knock, 6.0) if push.length() > 0.01 else Vector3.ZERO
		invuln = 0.4
		_blocked()
		return false
	hp -= amount
	invuln = 0.9
	hurt_t = 0.0
	pounding = false
	var away := global_position - from_pos
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.BACK
	velocity = away * knock + Vector3.UP * min(9.0, knock)
	swinging = false
	climbing = false
	game.audio.play("hurt")
	game.shake(0.25)
	game.popup(center() + Vector3.UP, "-%d" % int(amount), Color(1, 0.35, 0.35))
	if hp <= 0.0:
		hp = 0.0
		dead = true
	return true


func heal(amount: float) -> void:
	hp = min(max_hp, hp + amount)


func fell() -> void:
	swinging = false
	climbing = false
	flying = false
	global_position = safe_pos + Vector3.UP * 0.5
	velocity = Vector3.ZERO
	invuln = 1.2
	if invincible:
		_blocked()
		return
	hp -= 15.0
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
	if climbing:
		target_yaw = atan2(wall_n.x, wall_n.z)
	elif punch_t > 0.0 or shoot_t > 0.0:
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
	var chest: Node3D = model["chest"]
	var head: Node3D = model["head"]
	var leg_l: Node3D = model["leg_l"]
	var leg_r: Node3D = model["leg_r"]
	var shin_l: Node3D = model["shin_l"]
	var shin_r: Node3D = model["shin_r"]
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	var hspeed := Vector2(velocity.x, velocity.z).length()
	walk_phase += hspeed * dt * 1.1 / size
	var run: float = min(1.0, hspeed / speed) if is_on_floor() else 0.0
	var s := sin(walk_phase)
	var breathe := sin(t * 2.2)

	# a hunched, prowling stance: knees and elbows bent, leaning in when he runs
	torso.rotation = Vector3(-0.12 - 0.22 * run, 0, 0)
	torso.position.y = 1.0 - 0.04 * run * abs(cos(walk_phase))
	chest.scale = Vector3(1.0 + 0.015 * breathe, 1.0 + 0.01 * breathe, 1.0 + 0.02 * breathe)
	head.rotation = Vector3(0.12 + 0.18 * run, sin(t * 0.7) * 0.15 * (1.0 - run), 0)
	leg_l.rotation = Vector3(0.12 + s * 0.85 * run, 0, -0.05)
	leg_r.rotation = Vector3(0.12 - s * 0.85 * run, 0, 0.05)
	shin_l.rotation.x = -0.25 - max(0.0, -cos(walk_phase)) * 1.2 * run
	shin_r.rotation.x = -0.25 - max(0.0, cos(walk_phase)) * 1.2 * run
	arm_l.rotation = Vector3(-s * 0.7 * run + 0.1, 0, -0.28 - 0.03 * breathe)
	arm_r.rotation = Vector3(s * 0.7 * run + 0.1, 0, 0.28 + 0.03 * breathe)
	fore_l.rotation.x = 0.45 + 0.4 * run
	fore_r.rotation.x = 0.45 + 0.4 * run
	if not is_on_floor() and not flying and not swinging and not climbing:  # tucked jump pose
		leg_l.rotation = Vector3(0.9, 0, -0.1)
		shin_l.rotation.x = -1.4
		leg_r.rotation = Vector3(0.2, 0, 0.1)
		shin_r.rotation.x = -0.6
		arm_l.rotation = Vector3(-0.5, 0, -0.75)
		arm_r.rotation = Vector3(-0.5, 0, 0.75)
		fore_l.rotation.x = 1.0
		fore_r.rotation.x = 1.0
	if flying:
		var lean: float = clamp(hspeed / fly_speed, 0.0, 1.0)
		torso.rotation.x = -0.25 - 0.6 * lean
		leg_l.rotation = Vector3(0.3 * lean + 0.12 * sin(t * 3.0), 0, -0.08)
		leg_r.rotation = Vector3(0.4 * lean, 0, 0.08)
		shin_l.rotation.x = -0.5
		shin_r.rotation.x = -0.3
		arm_l.rotation = Vector3(0.3, 0, -0.55)
		arm_r.rotation = Vector3(0.3, 0, 0.55)
		head.rotation.x = 0.4 * lean
	if climbing:  # spread out flat against the wall, hands and feet taking turns
		var c := sin(t * 9.0) if abs(velocity.y) > 0.5 or Vector2(velocity.x, velocity.z).length() > 3.5 else 0.0
		torso.rotation.x = 0.0
		head.rotation.x = -0.5
		arm_l.rotation = Vector3(-2.3 + 0.5 * c, 0, -0.5)
		arm_r.rotation = Vector3(-2.3 - 0.5 * c, 0, 0.5)
		fore_l.rotation.x = 0.9
		fore_r.rotation.x = 0.9
		leg_l.rotation = Vector3(0.7 - 0.5 * c, 0, -0.5)
		leg_r.rotation = Vector3(0.7 + 0.5 * c, 0, 0.5)
		shin_l.rotation.x = -1.3
		shin_r.rotation.x = -1.3
	if flip_t > 0.0:  # mid-air somersault
		torso.rotation.x = -TAU * (1.0 - flip_t / 0.5)
	if swinging:
		arm_r.rotation = Vector3(-PI + 0.2, 0, 0.1)
		fore_r.rotation.x = 0.1
		leg_l.rotation.x = 0.7
		shin_l.rotation.x = -1.1
	if punch_t > 0.0:  # wind up, then a huge straight right
		var k := sin((1.0 - punch_t / 0.3) * PI)
		arm_r.rotation = Vector3(-PI / 2 * (0.3 + 0.8 * k), 0, 0.1)
		fore_r.rotation.x = 1.3 * (1.0 - k)
		torso.rotation.y = -0.4 * k
	else:
		torso.rotation.y = 0.0
	if shoot_t > 0.0:
		arm_r.rotation = Vector3(-PI / 2, 0, 0.05)
		fore_r.rotation.x = 0.0

	_animate_extra(dt)

	# the swing line (tendril or web) from his hand to the anchor
	tendril.visible = swinging
	if swinging:
		var a := global_position + Vector3(0, 2.4 * size, 0) + Vector3(-sin(face_yaw), 0, -cos(face_yaw)) * 0.3 * size
		var b := anchor
		var n := tendril.get_child_count()
		var axis := (b - a).normalized()
		var side := axis.cross(Vector3.UP).normalized()
		if side.length() < 0.1:
			side = Vector3.RIGHT
		var prev := a
		for i in n:
			var f := float(i + 1) / n
			var wob := sin(f * 10.0 - t * 18.0) * 0.25 * sin(f * PI) * (1.0 if rope_radius > 0.06 else 0.15)
			var p := a.lerp(b, f) + side * wob
			var seg := tendril.get_child(i) as MeshInstance3D
			seg.global_position = (prev + p) * 0.5
			var dir := p - prev
			seg.global_basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
			prev = p


func _animate_extra(_dt: float) -> void:
	pass  # hero-specific bits: Venom's jaw, tongue and wings
