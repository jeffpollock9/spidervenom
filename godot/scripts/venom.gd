class_name Venom
extends Hero
## Venom: a huge, heavy-hitting brute. Flies on symbiote wings, swings on tendrils, fires
## symbiote blasts and, at full energy, clears the area with a SYMBIOTE BLAST.


func _setup() -> void:
	hero_name = "Venom"
	colour = Color(0.75, 0.78, 1.0)
	size = Models.VENOM_SIZE
	max_hp = 140.0
	speed = 9.0
	jump = 12.5
	punch_damage = 20.0
	punch_reach = 4.0
	punch_cd = 0.42
	blast_cost = 14.0
	swing_cost = 3.0
	swing_max_speed = 32.0
	can_fly = true
	ult_ready_text = "F: SYMBIOTE BLAST READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump (again in the air: FLY)   LMB punch   RMB blast   SHIFT swing   F ultimate   ESC pause"


func _build_model() -> Dictionary:
	return Models.venom()


func special() -> void:
	## Symbiote blast at the crosshair.
	_face_aim()
	energy -= blast_cost
	cd = 0.4
	shoot_t = 0.3
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 34.0, "player", "symbiote", 22.0, 0.55, {"knock": 12.0, "life": 1.4})
	game.audio.play("blob")


func _ultimate_effect() -> void:
	game.symbiote_blast(center())


func _animate_extra(dt: float) -> void:
	var run: float = min(1.0, Vector2(velocity.x, velocity.z).length() / speed) if is_on_floor() else 0.0
	# jaw opens wider when he's attacking, the tongue whips and the strands sway
	var snarl := 0.0
	if punch_t > 0.0 or shoot_t > 0.0 or swinging:
		snarl = 1.0
	(model["jaw"] as Node3D).rotation.x = 0.12 + 0.05 * sin(t * 3.0) + 0.25 * snarl
	var segs: Array = model["tongue_segs"]
	for i in segs.size():
		var seg := segs[i] as Node3D
		seg.rotation = Vector3(-0.3 + sin(t * 6.0 - i * 0.9) * 0.25, sin(t * 4.3 - i * 0.7) * 0.3, 0)
	var strands: Array = model["strands"]
	for i in strands.size():
		var st := strands[i] as Node3D
		st.rotation = Vector3(0.3 * run + sin(t * 2.5 + i) * 0.2, 0, sin(t * 3.1 + i * 1.7) * 0.2)

	# wings spread while flying, fold away on landing
	wing_open = move_toward(wing_open, 1.0 if flying else 0.0, dt * (5.0 if flying else 3.0))
	var wings: Node3D = model["wings"]
	wings.visible = wing_open > 0.02
	wings.scale = Vector3.ONE * max(0.02, wing_open)
	var rate := 13.0 if velocity.y > 1.0 else 8.0
	var flap := sin(t * rate) * 0.55
	(model["wing_l"] as Node3D).rotation = Vector3(0, -0.35, -flap)
	(model["wing_r"] as Node3D).rotation = Vector3(0, 0.35, flap)

