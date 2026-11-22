class_name Cammy
extends Hero
## Cammy: really powerful and really strong. His punch sends robots into next week, RIGHT
## CLICK rips a boulder out of the street and hurls it, SHIFT lifts a robot over his head
## (SHIFT again throws it at the others), and if he grabs the boss he BODY SLAMS it. At full
## energy he leaps up and comes down so hard it makes an EARTHQUAKE.

const LIFT_REACH := 3.0
const SLAM_COST := 20.0

var held = null           # the robot he's holding over his head
var quaking := false      # in the air on the way to an earthquake
var quake_t := 0.0
var slam_cd := 0.0


func _setup() -> void:
	hero_name = "Cammy"
	colour = Color(1.0, 0.5, 0.2)
	size = Models.CAMMY_SIZE
	max_hp = 260.0
	speed = 9.5
	jump = 14.0
	punch_damage = 55.0
	punch_reach = 3.2
	punch_cd = 0.4
	punch_knock = 32.0
	blast_cost = 18.0
	custom_shift = true
	ult_ready_text = "F: EARTHQUAKE READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump   LMB mega punch   RMB throw a boulder   SHIFT lift a robot (again: THROW it)   F ultimate"


func _build_model() -> Dictionary:
	return Models.cammy()


func info_line() -> String:
	if quaking:
		return "EARTHQUAKE!"
	if held != null:
		return "LIFTING A ROBOT (SHIFT or RMB: throw it)"
	return super()


func _pre_tick(ctl: Controls, dt: float) -> void:
	slam_cd = max(0.0, slam_cd - dt)
	if held != null and (not is_instance_valid(held) or held.dead):
		held = null
	if dead and held != null:
		_drop()
	if ctl.alt_pressed and not dead:
		if held != null:
			throw_held()
		else:
			lift()
	if quaking:  # up he goes... then straight down
		quake_t += dt
		if not pounding and not is_on_floor() and velocity.y < 0.0:
			pounding = true
			velocity = Vector3(velocity.x * 0.2, -45.0, velocity.z * 0.2)
		elif not pounding and is_on_floor() and quake_t > 0.3:
			_pound_landed()  # got knocked out of the dive: quake anyway


func lift() -> void:
	## Grab the robot in front of him and heave it up over his head.
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var best = null
	var best_d := 99.0
	for e in game.targets():
		var to: Vector3 = e.center() - center()
		var flat := Vector3(to.x, 0, to.z)
		var dd := flat.length()
		if dd < LIFT_REACH * size + e.radius and abs(to.y) < 3.0 and (dd < 0.5 or fwd.dot(flat.normalized()) > 0.0) and dd < best_d:
			best = e
			best_d = dd
	if best == null:
		say("Nothing to lift!", 0.8)
		return
	if best == game.boss:
		body_slam(best)
		return
	held = best
	best.held = true
	best.stun_t = 0.0
	if best.cocoon:
		best.cocoon.visible = false
	cd = 0.25
	say("HNNNGH!", 0.7)
	game.audio.play("heave")


func body_slam(b) -> void:
	## The boss is too big to carry about, but not too big to pick up and slam.
	if slam_cd > 0.0:
		return
	if energy < SLAM_COST:
		say("Need energy!")
		return
	energy -= SLAM_COST
	slam_cd = 1.5
	cd = 0.6
	punch_t = 0.3
	b.hurt(65.0, Vector3.ZERO)
	b.velocity.y = 12.0
	if b.has_method("daze"):
		b.daze(1.0)
	game.popup(b.center() + Vector3.UP * 3.0, "BODY SLAM!", Color(1.0, 0.6, 0.2))
	game.burst(b.global_position + Vector3.UP * 0.3, Color(0.7, 0.65, 0.58), 24, 9.0)
	game.audio.play("explode")
	game.shake(0.7)
	say("UP YOU GET!", 1.0)


func throw_held() -> void:
	var e = held
	held = null
	_face_aim()
	shoot_t = 0.35
	cd = 0.3
	var from := global_position + Vector3.UP * 3.2 * size
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 32.0 + Vector3.UP * 3.0, "player", "robot", 50.0, 0.8,
		{"gravity": 12.0, "life": 2.5, "splash": 3.5, "knock": 18.0, "shooter": e.kind == "shooter"})
	e.dead = true  # it goes in the throw, not on the street
	game.score += 100
	e.queue_free()
	game.audio.play("whoosh")


func _drop() -> void:
	if held != null and is_instance_valid(held):
		held.held = false
	held = null


func special() -> void:
	## Rip a boulder out of the street and hurl it. (Holding a robot? Throw that instead.)
	if held != null:
		throw_held()
		return
	_face_aim()
	energy -= blast_cost
	cd = 0.55
	shoot_t = 0.35
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	game.burst(global_position + fwd * 1.2 + Vector3.UP * 0.2, Color(0.5, 0.47, 0.43), 12, 6.0)
	var from := global_position + Vector3.UP * 3.2 * size + fwd * 0.5
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 30.0 + Vector3.UP * 2.0, "player", "boulder", 40.0, 0.9,
		{"gravity": 10.0, "life": 2.5, "splash": 4.0, "knock": 20.0})
	game.audio.play("heave")


func _ultimate_effect() -> void:
	## EARTHQUAKE: leap up, then come down so hard the whole street shakes.
	_drop()
	quaking = true
	quake_t = 0.0
	pounding = false
	velocity.y = 20.0
	say("EARTHQUAKE!", 1.2)
	game.audio.play("roar")


func _pound_landed() -> void:
	if quaking:
		quaking = false
		pounding = false
		game.earthquake(global_position)


func _animate_extra(_dt: float) -> void:
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	var lifting := held != null
	if lifting or shoot_t > 0.0 or (quaking and not pounding):  # both arms straight up
		var k := 1.0
		if shoot_t > 0.0 and not lifting:  # the throw: arms come over and forward
			k = shoot_t / 0.35
		arm_l.rotation = Vector3(-PI * (0.5 + 0.45 * k), 0, -0.25)
		arm_r.rotation = Vector3(-PI * (0.5 + 0.45 * k), 0, 0.25)
		fore_l.rotation.x = 0.35 * k
		fore_r.rotation.x = 0.35 * k
	if pounding:  # fists together, hammering down
		arm_l.rotation = Vector3(-2.7, 0, -0.2)
		arm_r.rotation = Vector3(-2.7, 0, 0.2)
		fore_l.rotation.x = 0.5
		fore_r.rotation.x = 0.5
	if lifting:  # the robot sits on his hands, kicking its wheels
		var e = held
		e.global_position = global_position + Vector3.UP * (3.05 * size)
		e.velocity = Vector3.ZERO
		e.face_yaw = face_yaw + PI / 2
		var r: Node3D = e.model["root"]
		r.rotation.y = e.face_yaw
		r.rotation.z = sin(t * 14.0) * 0.12
