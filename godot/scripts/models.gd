class_name Models
## Cartoon 3D models built from primitive shapes, so the game needs no asset files.
## Models face -Z (Godot's forward) with their feet at y = 0.

static var _mats := {}


static func mat(color: Color, rough := 0.6, metal := 0.0, emit := 0.0, rim := 0.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s|%s" % [color, rough, metal, emit, rim]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if rim > 0.0:
		m.rim_enabled = true
		m.rim = rim
		m.rim_tint = 0.3
	_mats[key] = m
	return m


static func flash_material() -> StandardMaterial3D:
	if not _mats.has("flash"):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.75)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mats["flash"] = m
	return _mats["flash"]


static func part(parent: Node3D, mesh: Mesh, material: Material, pos := Vector3.ZERO,
		rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = material
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	parent.add_child(mi)
	return mi


static func pivot(parent: Node3D, pos: Vector3, node_name := "") -> Node3D:
	var n := Node3D.new()
	n.position = pos
	if node_name != "":
		n.name = node_name
	parent.add_child(n)
	return n


static func sphere(r: float, segs := 16) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2
	m.radial_segments = segs
	m.rings = segs / 2
	return m


static func capsule(r: float, h: float) -> CapsuleMesh:
	var m := CapsuleMesh.new()
	m.radius = r
	m.height = h
	m.radial_segments = 12
	m.rings = 4
	return m


static func box(size: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = size
	return m


static func cylinder(r_top: float, r_bottom: float, h: float, segs := 16) -> CylinderMesh:
	var m := CylinderMesh.new()
	m.top_radius = r_top
	m.bottom_radius = r_bottom
	m.height = h
	m.radial_segments = segs
	m.rings = 1
	return m


static func set_flash(root: Node, on: bool) -> void:
	for c in root.get_children():
		if c is GeometryInstance3D:
			(c as GeometryInstance3D).material_overlay = flash_material() if on else null
		set_flash(c, on)


# --------------------------------------------------------------------------- Venom

const VENOM_BLACK := Color(0.03, 0.03, 0.045)
const VENOM_SHEEN := Color(0.12, 0.12, 0.2)
## How much bigger than a person Venom is (the model is built at ~2.7 m, then scaled).
const VENOM_SIZE := 1.4

static var _skin: StandardMaterial3D


static func venom_skin() -> StandardMaterial3D:
	## Wet, glossy symbiote skin: clearcoat, a blue-ish rim and a bumpy organic normal map.
	if _skin == null:
		var m := StandardMaterial3D.new()
		m.albedo_color = VENOM_BLACK
		m.roughness = 0.18
		m.metallic = 0.35
		m.clearcoat_enabled = true
		m.clearcoat = 1.0
		m.clearcoat_roughness = 0.08
		m.rim_enabled = true
		m.rim = 0.8
		m.rim_tint = 0.5
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_CELLULAR
		noise.frequency = 0.035
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.width = 256
		tex.height = 256
		tex.seamless = true
		tex.as_normal_map = true
		tex.bump_strength = 6.0
		tex.noise = noise
		m.normal_enabled = true
		m.normal_texture = tex
		m.normal_scale = 0.6
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(2.5, 2.5, 2.5)
		_skin = m
	return _skin


static func _muscle(parent: Node3D, r: float, material: Material, pos: Vector3, scl: Vector3, rot := Vector3.ZERO) -> void:
	part(parent, sphere(r, 14), material, pos, rot, scl)


static func venom() -> Dictionary:
	var root := Node3D.new()
	root.name = "VenomModel"
	root.scale = Vector3.ONE * VENOM_SIZE
	var black := venom_skin()
	var sheen := mat(VENOM_SHEEN, 0.15, 0.4, 0.0, 0.9)
	var white := mat(Color(0.97, 0.97, 1.0), 0.3, 0.0, 0.35)
	var tooth := mat(Color(0.95, 0.93, 0.85), 0.25, 0.0, 0.1)
	var mouth := mat(Color(0.28, 0.02, 0.06), 0.5)
	var red := mat(Color(0.8, 0.12, 0.3), 0.15, 0.0, 0.05, 0.4)
	var d := {"root": root}

	# legs: hip -> knee -> ankle, with thick thighs and calves
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.27 * side, 1.08, 0.02), "leg_" + s)
		_muscle(hip, 0.24, black, Vector3(0, -0.06, 0), Vector3(1.0, 0.9, 1.0))
		part(hip, capsule(0.21, 0.66), black, Vector3(0, -0.28, 0), Vector3.ZERO, Vector3(1.0, 1.0, 1.1))
		_muscle(hip, 0.17, black, Vector3(0.02 * side, -0.25, -0.1), Vector3(1.0, 1.7, 0.8))  # quad
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		_muscle(knee, 0.15, black, Vector3.ZERO, Vector3.ONE)
		part(knee, capsule(0.13, 0.6), black, Vector3(0, -0.25, 0))
		_muscle(knee, 0.13, black, Vector3(0, -0.15, 0.07), Vector3(1.0, 1.8, 1.0))  # calf
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.13, black, Vector3(0, -0.02, -0.12), Vector3(1.1, 0.55, 1.9))
		for c in 3:  # toe claws
			part(ankle, cylinder(0.0, 0.035, 0.16, 6), black,
				Vector3((c - 1) * 0.07, -0.05, -0.36), Vector3(-PI / 2 - 0.2, 0, 0))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: pelvis, narrow waist, ribbed abs, a huge V-shaped chest and back
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.3, black, Vector3(0, 0.08, 0.01), Vector3(1.15, 0.6, 0.85))  # pelvis
	part(torso, capsule(0.33, 0.85), black, Vector3(0, 0.38, 0.02), Vector3.ZERO, Vector3(1.05, 1.0, 0.78))
	for row in 3:  # six-pack
		for side: int in [-1, 1]:
			_muscle(torso, 0.085, black, Vector3(0.085 * side, 0.2 + row * 0.13, -0.2), Vector3(1.0, 0.75, 0.45))
	var chest := pivot(torso, Vector3(0, 0.82, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.5, black, Vector3(0, 0.02, 0.03), Vector3(1.22, 0.85, 0.72))
	_muscle(chest, 0.4, black, Vector3(0, 0.22, 0.06), Vector3(1.45, 0.45, 0.75))  # broad shoulders
	for side: int in [-1, 1]:
		_muscle(chest, 0.25, black, Vector3(0.21 * side, 0.08, -0.2), Vector3(1.15, 0.8, 0.6))      # pec
		_muscle(chest, 0.24, black, Vector3(0.38 * side, -0.12, 0.05), Vector3(0.7, 1.4, 1.0))      # lat
		_muscle(chest, 0.2, black, Vector3(0.24 * side, 0.3, 0.1), Vector3(1.4, 0.7, 1.0), Vector3(0, 0, -0.4 * side))  # trap
		_muscle(chest, 0.2, black, Vector3(0.18 * side, 0.05, 0.24), Vector3(1.0, 1.3, 0.6))       # back
	for k in 5:  # spine ridge down the back
		_muscle(chest, 0.05, sheen, Vector3(0, 0.25 - k * 0.17, 0.33 - k * 0.02), Vector3(1.0, 0.7, 0.6))
	part(chest, capsule(0.19, 0.45), black, Vector3(0, 0.4, -0.03))  # neck
	# white spider emblem: a body plus long legs wrapping round the chest and over the shoulders
	_muscle(chest, 0.11, white, Vector3(0, 0.06, -0.35), Vector3(0.8, 1.6, 0.35))
	for side: int in [-1, 1]:
		for k in 4:
			var y := 0.28 - k * 0.14
			var ang := (0.95 - k * 0.5) * side
			part(chest, box(Vector3(0.56, 0.05, 0.05)), white,
				Vector3(0.25 * side, y, -0.34 + abs(k - 1.5) * 0.03), Vector3(0, -0.5 * side, ang))

	# arms: shoulder -> elbow -> wrist, big deltoids and biceps, clawed hands
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.66 * side, 0.2, 0.02), "arm_" + s)
		_muscle(sh, 0.25, black, Vector3(0.03 * side, 0.02, 0), Vector3(1.0, 0.95, 1.1))  # deltoid
		part(sh, capsule(0.15, 0.6), black, Vector3(0, -0.3, 0))
		_muscle(sh, 0.13, black, Vector3(0, -0.28, -0.08), Vector3(1.0, 1.7, 1.0))  # bicep
		_muscle(sh, 0.13, black, Vector3(0, -0.25, 0.07), Vector3(1.0, 1.8, 1.0))   # tricep
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		part(elbow, capsule(0.12, 0.6), black, Vector3(0, -0.25, 0))
		_muscle(elbow, 0.12, black, Vector3(0, -0.12, -0.03), Vector3(1.1, 1.6, 1.0))
		var wrist := pivot(elbow, Vector3(0, -0.52, 0), "hand_" + s)
		wrist.scale = Vector3.ONE * 1.45  # big hands for a big lad
		_muscle(wrist, 0.11, black, Vector3(0, -0.06, 0), Vector3(1.0, 1.1, 0.6))
		for f in 4:  # long fingers ending in hooked claws
			var fx := (f - 1.5) * 0.055
			var finger := pivot(wrist, Vector3(fx, -0.13, -0.02))
			finger.rotation = Vector3(0.35, 0, (f - 1.5) * 0.1)
			part(finger, cylinder(0.025, 0.03, 0.16, 6), black, Vector3(0, -0.08, 0))
			part(finger, cylinder(0.0, 0.025, 0.14, 6), sheen, Vector3(0, -0.22, -0.03), Vector3(0.4, 0, 0))
		var thumb := pivot(wrist, Vector3(-0.08 * side, -0.07, -0.06))
		thumb.rotation = Vector3(0.6, 0, 0.6 * side)
		part(thumb, cylinder(0.0, 0.03, 0.16, 6), black, Vector3(0, -0.08, 0))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	# head: a long skull, enormous jaw full of fangs, jagged white eyes
	var head_mount := pivot(chest, Vector3(0, 0.6, -0.1))
	head_mount.scale = Vector3.ONE * 1.25
	var head := pivot(head_mount, Vector3.ZERO, "head")
	d["head"] = head
	_muscle(head, 0.33, black, Vector3(0, 0.12, 0.02), Vector3(0.88, 0.9, 1.15))  # skull
	_muscle(head, 0.3, black, Vector3(0, 0.0, -0.12), Vector3(0.95, 0.55, 1.0))   # upper jaw / snout
	part(head, sphere(0.27), mouth, Vector3(0, -0.1, -0.13), Vector3.ZERO, Vector3(0.9, 0.5, 1.0))  # inside the mouth
	for side: int in [-1, 1]:  # eyes: long jagged teardrops sweeping up and back
		part(head, sphere(0.17), white, Vector3(0.14 * side, 0.18, -0.31),
			Vector3(0.3, 0.45 * side, 0.6 * side), Vector3(1.3, 0.5, 0.3))
		part(head, cylinder(0.0, 0.07, 0.26, 6), white, Vector3(0.27 * side, 0.27, -0.24),
			Vector3(0.2, 0.55 * side, -1.05 * side), Vector3(1.0, 1.0, 0.4))
	var teeth_upper := 15
	for k in teeth_upper:  # upper fangs round the snout
		var a := lerpf(-1.25, 1.25, float(k) / (teeth_upper - 1))
		var long: float = 0.13 if abs(k - 7) in [3, 4] else 0.09 - 0.02 * abs(a)
		part(head, cylinder(0.0, 0.026, long, 5), tooth,
			Vector3(sin(a) * 0.27, -0.07 - long * 0.5, -0.13 - cos(a) * 0.27), Vector3(PI, 0, 0))
	var jaw := pivot(head, Vector3(0, -0.04, 0.05), "jaw")
	d["jaw"] = jaw
	_muscle(jaw, 0.27, black, Vector3(0, -0.14, -0.15), Vector3(0.95, 0.42, 1.05))
	for k in 13:  # lower fangs
		var a := lerpf(-1.15, 1.15, float(k) / 12.0)
		var long: float = 0.1 - 0.025 * abs(a)
		part(jaw, cylinder(0.0, 0.024, long, 5), tooth,
			Vector3(sin(a) * 0.25, -0.09 + long * 0.5, -0.17 - cos(a) * 0.25))
	# the long tongue: a chain of segments that whips about
	var tongue := pivot(jaw, Vector3(0, -0.1, -0.25), "tongue")
	d["tongue"] = tongue
	var segs: Array[Node3D] = []
	var prev := tongue
	for k in 6:
		var seg := pivot(prev, Vector3(0, 0, -0.09) if k > 0 else Vector3.ZERO)
		part(seg, capsule(0.05 - k * 0.006, 0.16), red, Vector3(0, 0, -0.05), Vector3(PI / 2, 0, 0), Vector3(1.4, 1.0, 0.6))
		segs.append(seg)
		prev = seg
	d["tongue_segs"] = segs

	# loose symbiote strands that drip and sway off his back and arms
	var strands: Array[Node3D] = []
	var spots: Array[Vector3] = [Vector3(0.3, 0.1, 0.28), Vector3(-0.32, 0.05, 0.26), Vector3(0.1, -0.2, 0.3),
		Vector3(-0.15, -0.35, 0.28), Vector3(0.45, 0.2, 0.15), Vector3(-0.48, 0.18, 0.12)]
	for p in spots:
		var st := pivot(chest, p)
		var len := randf_range(0.35, 0.6)
		part(st, cylinder(0.006, 0.03, len, 5), black, Vector3(0, -len * 0.5, 0))
		_muscle(st, 0.022, black, Vector3(0, -len, 0), Vector3(1, 1.5, 1))
		strands.append(st)
	d["strands"] = strands

	# symbiote wings, folded away until he flies
	var wings := pivot(chest, Vector3(0, 0.15, 0.32), "wings")
	wings.visible = false
	d["wings"] = wings
	for side: int in [-1, 1]:
		var w := pivot(wings, Vector3(0.2 * side, 0, 0), "wing_l" if side < 0 else "wing_r")
		w.rotation.y = 0.35 * side
		_build_wing(w, side)
		d["wing_l" if side < 0 else "wing_r"] = w
	return d


static func _build_wing(parent: Node3D, side: int) -> void:
	# bat-like membrane: (out, up) points from the root, as in the 2D game
	var shape: Array[Vector2] = [Vector2(0, 0), Vector2(0.45, 0.55), Vector2(1.05, 0.8), Vector2(1.0, 0.2),
		Vector2(0.75, -0.15), Vector2(0.35, -0.32), Vector2(0.05, -0.25)]
	var L := 2.3
	var pts: Array[Vector3] = []
	for p in shape:
		pts.append(Vector3(p.x * L * side, p.y * L, 0))
	var outline: Array[Vector3] = [pts[0], pts[1], pts[2]]
	for i in range(2, pts.size() - 1):
		var a := pts[i]
		var c := pts[i + 1]
		var mid := (a + c) * 0.5
		outline.append(mid.lerp(pts[0], 0.18))  # scallops between the fingers
		outline.append(c)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(1, outline.size() - 1):
		st.add_vertex(outline[0])
		st.add_vertex(outline[i])
		st.add_vertex(outline[i + 1])
	st.generate_normals()
	var membrane := StandardMaterial3D.new()
	membrane.albedo_color = Color(0.07, 0.07, 0.11)
	membrane.roughness = 0.35
	membrane.cull_mode = BaseMaterial3D.CULL_DISABLED
	membrane.rim_enabled = true
	membrane.rim = 0.5
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = membrane
	parent.add_child(mi)
	# bones along the leading edge and fingers
	var bone := mat(Color(0.2, 0.2, 0.32), 0.3)
	for i in [1, 2, 3, 4, 5]:
		var from: Vector3 = pts[0] if i != 2 else pts[1]
		_bone(parent, from, pts[i], bone, 0.035)
	_bone(parent, pts[0], pts[1], bone, 0.06)
	part(parent, sphere(0.06), mat(Color(0.95, 0.95, 1.0), 0.3, 0.0, 0.5), pts[2])


static func _bone(parent: Node3D, a: Vector3, b: Vector3, material: Material, r: float) -> void:
	var mi := part(parent, cylinder(r, r, a.distance_to(b), 6), material, (a + b) * 0.5)
	var dir := (b - a).normalized()
	mi.basis = Basis(Quaternion(Vector3.UP, dir))


# --------------------------------------------------------------------------- Supercity robots

static func robot(shooter: bool) -> Dictionary:
	var root := Node3D.new()
	var steel := mat(Color(0.62, 0.64, 0.7), 0.35, 0.6)
	var dark := mat(Color(0.22, 0.22, 0.26), 0.5, 0.4)
	var visor := mat(Color(1.0, 0.12, 0.12), 0.3, 0.0, 2.5)
	var bulb := mat(Color(1.0, 0.8, 0.15), 0.3, 0.0, 2.0)
	var body := pivot(root, Vector3(0, 0.75, 0), "body")
	part(body, box(Vector3(0.85, 1.0, 0.65)), steel, Vector3(0, 0.25, 0))
	part(body, box(Vector3(0.7, 0.16, 0.08)), visor, Vector3(0, 0.5, -0.33))
	part(body, box(Vector3(0.5, 0.3, 0.06)), dark, Vector3(0, 0.05, -0.33))
	part(body, cylinder(0.025, 0.025, 0.4, 6), dark, Vector3(0, 0.95, 0))
	part(body, sphere(0.08), bulb, Vector3(0, 1.17, 0))
	for side: int in [-1, 1]:
		part(body, cylinder(0.32, 0.32, 0.16), dark, Vector3(0.36 * side, -0.42, 0), Vector3(0, 0, PI / 2))
		part(body, box(Vector3(0.14, 0.55, 0.14)), steel, Vector3(0.52 * side, 0.15, 0), Vector3(0, 0, 0.15 * side))
	if shooter:
		part(body, box(Vector3(0.16, 0.16, 0.7)), dark, Vector3(0.55, 0.3, -0.3))
		part(body, cylinder(0.05, 0.05, 0.2), visor, Vector3(0.55, 0.3, -0.68), Vector3(PI / 2, 0, 0))
	return {"root": root, "body": body}


# --------------------------------------------------------------------------- Mr Poo

static func poo(size: float) -> Dictionary:
	## A swirly poo with a face, `size` metres wide at the base.
	var root := Node3D.new()
	var base := mat(Color(0.45, 0.28, 0.13), 0.55)
	var hi := mat(Color(0.6, 0.39, 0.19), 0.5)
	var white := mat(Color.WHITE, 0.3)
	var black := mat(Color(0.03, 0.03, 0.03), 0.4)
	var squash := pivot(root, Vector3.ZERO, "squash")
	var y := 0.0
	for layer in [[1.0, 0.36], [0.78, 0.3], [0.55, 0.26]]:
		var w: float = layer[0] * size
		var h: float = layer[1] * size
		part(squash, sphere(0.5, 24), base, Vector3(0, y + h * 0.5, 0), Vector3.ZERO, Vector3(w, h, w))
		part(squash, sphere(0.5, 12), hi, Vector3(-w * 0.12, y + h * 0.62, -w * 0.18), Vector3.ZERO,
			Vector3(w * 0.45, h * 0.4, w * 0.45))
		y += h * 0.75
	part(squash, cylinder(0.0, size * 0.13, size * 0.25), base, Vector3(0, y + size * 0.12, 0), Vector3(-0.3, 0, 0))
	var face := pivot(squash, Vector3(0, size * 0.22, -size * 0.43), "face")
	var pupils: Array = []
	var brows: Array = []
	for side: int in [-1, 1]:
		part(face, sphere(size * 0.1), white, Vector3(size * 0.15 * side, size * 0.08, 0))
		pupils.append(part(face, sphere(size * 0.05), black, Vector3(size * 0.15 * side, size * 0.08, -size * 0.07)))
		var brow := part(face, box(Vector3(size * 0.2, size * 0.04, size * 0.04)), black,
			Vector3(size * 0.15 * side, size * 0.21, -size * 0.06), Vector3(0, 0, -0.35 * side))
		brow.visible = false
		brows.append(brow)
	part(face, sphere(size * 0.17), mat(Color(0.25, 0.05, 0.05), 0.5), Vector3(0, -size * 0.1, -size * 0.02),
		Vector3.ZERO, Vector3(1.0, 0.45, 0.4))
	var flies := pivot(root, Vector3.ZERO, "flies")
	for k in 4:
		part(flies, sphere(max(0.05, size * 0.025), 6), black, Vector3.ZERO)
	return {"root": root, "squash": squash, "pupils": pupils, "brows": brows, "flies": flies, "size": size}


static func animate_poo(d: Dictionary, t: float, angry: bool, look_dir: Vector3) -> void:
	var size: float = d["size"]
	var s := 1.0 + sin(t * 6.0) * 0.04
	(d["squash"] as Node3D).scale = Vector3(s, 1.0 / s, s)
	for p in d["pupils"]:
		var pp := p as Node3D
		pp.position.x = (pp.position.x / abs(pp.position.x)) * size * 0.15 + clamp(look_dir.x, -1, 1) * size * 0.03
		pp.position.y = size * 0.08 + clamp(look_dir.y, -1, 1) * size * 0.03
	for b in d["brows"]:
		(b as Node3D).visible = angry
	var flies := d["flies"] as Node3D
	for k in flies.get_child_count():
		var a := t * (3.0 + k) + k * 2.0
		(flies.get_child(k) as Node3D).position = Vector3(cos(a) * size * 0.6, size * 0.95 + sin(a * 1.7) * size * 0.2,
			sin(a) * size * 0.6)
