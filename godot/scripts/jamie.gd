class_name Jamie
extends Hero
## Jamie: invincible, very good looking, very smart and very strong. Nothing can hurt him.
## Being smart, he built his own gadgets: a jetpack (hold SHIFT) and smart shots that steer
## themselves into the nearest robot. At full energy his GENIUS HACK shuts down every robot
## nearby and scrambles Mr Poo.

var shield_t := 0.0
var shield: MeshInstance3D


func _setup() -> void:
	hero_name = "JAMIE"
	colour = Color(0.35, 1.0, 0.8)
	size = Models.JAMIE_SIZE
	max_hp = 100.0
	invincible = true
	speed = 11.0
	jump = 14.0
	punch_damage = 36.0
	punch_reach = 2.6
	punch_cd = 0.3
	punch_knock = 20.0
	blast_cost = 10.0
	can_jetpack = true
	ult_ready_text = "F: GENIUS HACK READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump   SHIFT (hold) jetpack   LMB strong punch   RMB smart shot (it aims itself)   F ultimate   ESC pause"


func _build_model() -> Dictionary:
	return Models.jamie()


func _ready() -> void:
	super()
	# a golden force field that flashes up whenever something tries to hurt him
	shield = MeshInstance3D.new()
	shield.mesh = Models.sphere(1.0, 20)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.3, 0.3)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.3)
	m.emission_energy_multiplier = 1.5
	m.rim_enabled = true
	m.rim = 1.0
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	shield.material_override = m
	shield.position.y = 1.25 * size
	shield.scale = Vector3(0.95, 1.25, 0.95) * size * 1.4
	shield.visible = false
	add_child(shield)


func _blocked() -> void:
	shield_t = 0.4
	game.popup(center() + Vector3.UP, "INVINCIBLE!", Color(1, 0.85, 0.3))
	game.audio.play("shield")


func special() -> void:
	## Smart shot: a glowing bolt that steers itself into the nearest robot (or Mr Poo).
	_face_aim()
	energy -= blast_cost
	cd = 0.3
	shoot_t = 0.25
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 28.0, "player", "smart", 20.0, 0.3, {"knock": 8.0, "life": 2.2, "homing": true})
	game.audio.play("shoot")


func _ultimate_effect() -> void:
	game.genius_hack(center())


func _animate_extra(dt: float) -> void:
	for f in model["flames"]:
		var flame := f as Node3D
		flame.visible = jetting
		if jetting:
			flame.scale = Vector3(1, 0.8 + randf() * 0.5, 1)
	shield_t = max(0.0, shield_t - dt)
	shield.visible = shield_t > 0.0
	if shield.visible:
		(shield.material_override as StandardMaterial3D).albedo_color.a = 0.75 * shield_t
	# the family twinkle
	var sparkle: Node3D = model["sparkle"]
	sparkle.visible = fmod(t, 3.3) < 0.25
	if sparkle.visible:
		sparkle.rotation.z += dt * 8.0
