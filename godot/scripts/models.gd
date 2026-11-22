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


# --------------------------------------------------------------------------- Spider-Man

const SPIDEY_SIZE := 0.7  # built on the same ~2.7 m skeleton as Venom, then scaled to ~1.9 m
const SPIDEY_RED := Color(0.8, 0.05, 0.08)
const SPIDEY_BLUE := Color(0.07, 0.14, 0.62)


static func spidey_red() -> StandardMaterial3D:
	## Red suit fabric with black web lines (a procedural texture, projected triplanar).
	if not _mats.has("spidey_red"):
		var n := 128
		var img := Image.create(n, n, false, Image.FORMAT_RGB8)
		img.fill(SPIDEY_RED)
		var line := Color(0.08, 0.02, 0.02)
		for i in n:
			for w in 2:
				img.set_pixel(i, w, line)                         # horizontal strand
				img.set_pixel(w, i, line)                         # vertical strand
				img.set_pixel(i, (i + w) % n, line)               # diagonals
				img.set_pixel(i, (n - 1 - i + w) % n, line)
		img.generate_mipmaps()
		var m := StandardMaterial3D.new()
		m.albedo_texture = ImageTexture.create_from_image(img)
		m.roughness = 0.55
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(3.5, 3.5, 3.5)
		m.rim_enabled = true
		m.rim = 0.3
		_mats["spidey_red"] = m
	return _mats["spidey_red"]


static func spiderman() -> Dictionary:
	var root := Node3D.new()
	root.name = "SpidermanModel"
	root.scale = Vector3.ONE * SPIDEY_SIZE
	var red := spidey_red()
	var blue := mat(SPIDEY_BLUE, 0.5, 0.0, 0.0, 0.3)
	var black := mat(Color(0.03, 0.03, 0.04), 0.4)
	var lens := mat(Color(0.95, 0.97, 1.0), 0.15, 0.0, 0.3)
	var d := {"root": root}

	# legs: blue tights, red boots
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.2 * side, 1.08, 0.0), "leg_" + s)
		_muscle(hip, 0.17, blue, Vector3(0, -0.05, 0), Vector3.ONE)
		part(hip, capsule(0.15, 0.66), blue, Vector3(0, -0.28, 0))
		_muscle(hip, 0.12, blue, Vector3(0, -0.24, -0.06), Vector3(1.0, 1.8, 0.8))
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		part(knee, capsule(0.11, 0.42), blue, Vector3(0, -0.12, 0))
		part(knee, capsule(0.115, 0.36), red, Vector3(0, -0.36, 0))  # boot
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.1, red, Vector3(0, -0.02, -0.08), Vector3(1.0, 0.6, 1.9))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a lean athlete. Red front and back, blue sides, red belt
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.22, blue, Vector3(0, 0.08, 0), Vector3(1.15, 0.65, 0.85))
	part(torso, cylinder(0.25, 0.25, 0.1, 16), red, Vector3(0, 0.17, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))  # belt
	part(torso, capsule(0.25, 0.7), blue, Vector3(0, 0.38, 0.0), Vector3.ZERO, Vector3(1.05, 1.0, 0.75))
	_muscle(torso, 0.2, red, Vector3(0, 0.4, -0.05), Vector3(0.75, 1.3, 0.8))  # red front panel
	var chest := pivot(torso, Vector3(0, 0.78, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.36, blue, Vector3(0, 0.0, 0.02), Vector3(1.15, 0.85, 0.7))
	_muscle(chest, 0.34, red, Vector3(0, 0.04, 0.0), Vector3(0.95, 0.85, 0.78))
	_muscle(chest, 0.28, red, Vector3(0, 0.18, 0.03), Vector3(1.35, 0.45, 0.8))  # shoulders
	for side: int in [-1, 1]:
		_muscle(chest, 0.16, red, Vector3(0.14 * side, 0.06, -0.15), Vector3(1.1, 0.75, 0.55))  # pecs
	# black spider emblem
	_muscle(chest, 0.05, black, Vector3(0, 0.1, -0.27), Vector3(0.7, 1.0, 0.4))
	_muscle(chest, 0.06, black, Vector3(0, -0.01, -0.26), Vector3(0.7, 1.4, 0.4))
	for side: int in [-1, 1]:
		for k in 4:
			part(chest, box(Vector3(0.14, 0.018, 0.02)), black,
				Vector3(0.07 * side, 0.12 - k * 0.05, -0.27), Vector3(0, 0, (0.7 - k * 0.45) * side))
	part(chest, capsule(0.12, 0.35), red, Vector3(0, 0.33, -0.02))  # neck

	# arms: blue, with red shoulders and gloves
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.45 * side, 0.18, 0.02), "arm_" + s)
		_muscle(sh, 0.15, red, Vector3(0.02 * side, 0.0, 0), Vector3.ONE)
		part(sh, capsule(0.1, 0.58), blue, Vector3(0, -0.3, 0))
		_muscle(sh, 0.085, blue, Vector3(0, -0.27, -0.05), Vector3(1.0, 1.8, 1.0))
		var elbow := pivot(sh, Vector3(0, -0.56, 0), "fore_" + s)
		part(elbow, capsule(0.085, 0.36), blue, Vector3(0, -0.12, 0))
		part(elbow, capsule(0.09, 0.3), red, Vector3(0, -0.36, 0))  # glove
		var wrist := pivot(elbow, Vector3(0, -0.5, 0), "hand_" + s)
		_muscle(wrist, 0.075, red, Vector3(0, -0.05, 0), Vector3(1.0, 1.2, 0.6))
		for f in 4:
			part(wrist, capsule(0.018, 0.12), red, Vector3((f - 1.5) * 0.035, -0.14, -0.01))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow
		d["hand_" + s] = wrist

	# head: the mask with big white lenses ringed in black
	var head := pivot(chest, Vector3(0, 0.55, -0.04), "head")
	d["head"] = head
	_muscle(head, 0.2, red, Vector3(0, 0.03, 0), Vector3(0.95, 1.15, 1.05))
	_muscle(head, 0.13, red, Vector3(0, -0.1, -0.08), Vector3(0.9, 0.8, 0.9))  # chin
	for side: int in [-1, 1]:
		part(head, sphere(0.078), black, Vector3(0.075 * side, 0.06, -0.17),
			Vector3(0, 0.4 * side, 0.55 * side), Vector3(1.5, 1.0, 0.4))
		part(head, sphere(0.064), lens, Vector3(0.078 * side, 0.06, -0.192),
			Vector3(0, 0.4 * side, 0.55 * side), Vector3(1.5, 1.0, 0.4))
	return d


# --------------------------------------------------------------------------- Jamie's Dad

const DAD_SIZE := 0.85  # same ~2.7 m skeleton, scaled to a big strong ~2.3 m dad
const DAD_SKIN := Color(0.88, 0.66, 0.5)


static func jamies_dad() -> Dictionary:
	var root := Node3D.new()
	root.name = "JamiesDadModel"
	root.scale = Vector3.ONE * DAD_SIZE
	var skin := mat(DAD_SKIN, 0.55, 0.0, 0.0, 0.25)
	var vest := mat(Color(0.97, 0.97, 0.98), 0.7)
	var jeans := mat(Color(0.18, 0.3, 0.55), 0.85)
	var shoe := mat(Color(0.95, 0.95, 0.95), 0.5)
	var sole := mat(Color(0.85, 0.2, 0.15), 0.5)
	var hair := mat(Color(0.3, 0.18, 0.09), 0.45, 0.0, 0.0, 0.2)
	var d := {"root": root}

	# legs: jeans over big thighs, white trainers
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.26 * side, 1.08, 0.0), "leg_" + s)
		_muscle(hip, 0.23, jeans, Vector3(0, -0.06, 0), Vector3.ONE)
		part(hip, capsule(0.21, 0.66), jeans, Vector3(0, -0.28, 0))
		_muscle(hip, 0.16, jeans, Vector3(0, -0.24, -0.07), Vector3(1.05, 1.7, 0.85))
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		part(knee, capsule(0.15, 0.56), jeans, Vector3(0, -0.22, 0))
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.13, shoe, Vector3(0, -0.01, -0.08), Vector3(1.0, 0.65, 1.9))
		part(ankle, box(Vector3(0.24, 0.05, 0.48)), sole, Vector3(0, -0.08, -0.08))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a white vest stretched over a massive chest, belt and jeans at the waist
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.3, jeans, Vector3(0, 0.06, 0.0), Vector3(1.15, 0.6, 0.85))
	part(torso, cylinder(0.32, 0.32, 0.08, 18), mat(Color(0.25, 0.15, 0.08), 0.5), Vector3(0, 0.17, 0),
		Vector3.ZERO, Vector3(1.05, 1.0, 0.82))  # belt
	part(torso, box(Vector3(0.1, 0.08, 0.04)), mat(Color(0.85, 0.75, 0.3), 0.3, 0.8), Vector3(0, 0.17, -0.27))
	part(torso, capsule(0.33, 0.8), vest, Vector3(0, 0.4, 0.02), Vector3.ZERO, Vector3(1.05, 1.0, 0.78))
	for row in 3:  # abs showing through the vest
		for side: int in [-1, 1]:
			_muscle(torso, 0.08, vest, Vector3(0.085 * side, 0.26 + row * 0.12, -0.21), Vector3(1.0, 0.75, 0.45))
	var chest := pivot(torso, Vector3(0, 0.82, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.5, vest, Vector3(0, 0.0, 0.03), Vector3(1.15, 0.8, 0.7))
	for side: int in [-1, 1]:
		_muscle(chest, 0.26, vest, Vector3(0.2 * side, 0.06, -0.18), Vector3(1.15, 0.8, 0.6))   # pecs
		_muscle(chest, 0.23, vest, Vector3(0.36 * side, -0.14, 0.05), Vector3(0.7, 1.4, 1.0))   # lats
		_muscle(chest, 0.2, skin, Vector3(0.26 * side, 0.3, 0.08), Vector3(1.4, 0.7, 1.0),
			Vector3(0, 0, -0.45 * side))  # huge traps
	part(chest, capsule(0.2, 0.42), skin, Vector3(0, 0.38, -0.02))  # thick neck

	# arms: enormous bare arms, bulging biceps and forearms
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.66 * side, 0.2, 0.02), "arm_" + s)
		_muscle(sh, 0.27, skin, Vector3(0.03 * side, 0.02, 0), Vector3(1.0, 0.95, 1.1))  # deltoid
		part(sh, capsule(0.16, 0.6), skin, Vector3(0, -0.3, 0))
		_muscle(sh, 0.16, skin, Vector3(0, -0.28, -0.09), Vector3(1.0, 1.5, 1.0))   # bicep
		_muscle(sh, 0.14, skin, Vector3(0, -0.24, 0.08), Vector3(1.0, 1.7, 1.0))    # tricep
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		part(elbow, capsule(0.14, 0.58), skin, Vector3(0, -0.24, 0))
		_muscle(elbow, 0.14, skin, Vector3(0, -0.12, -0.03), Vector3(1.1, 1.5, 1.0))
		var wrist := pivot(elbow, Vector3(0, -0.52, 0), "hand_" + s)
		_muscle(wrist, 0.13, skin, Vector3(0, -0.06, 0), Vector3(1.0, 1.0, 0.8))  # big fists
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	handsome_head(d, chest, Vector3(0, 0.62, -0.06), skin, hair, true)
	return d


static func handsome_head(d: Dictionary, chest: Node3D, at: Vector3, skin: Material, hair: Material,
		adult: bool) -> Node3D:
	## The good-looking family face (Jamie and his dad): square jaw, blue eyes, a quiff and a
	## smile that twinkles. Adds "head" and "sparkle" to d.
	var white := mat(Color(1, 1, 1), 0.2, 0.0, 0.25)
	var iris := mat(Color(0.15, 0.5, 0.95), 0.2, 0.0, 0.4)
	var dark := mat(Color(0.05, 0.04, 0.04), 0.4)
	var lip := mat(Color(0.75, 0.42, 0.38), 0.5)
	# head: strong square jaw, great hair, blue eyes and a dazzling smile
	var head := pivot(chest, at, "head")
	d["head"] = head
	_muscle(head, 0.21, skin, Vector3(0, 0.07, 0), Vector3(0.95, 1.1, 1.05))          # skull
	_muscle(head, 0.16, skin, Vector3(0, -0.06, -0.03), Vector3(0.98, 0.9, 1.0))      # cheeks and jaw
	for side: int in [-1, 1]:                                                          # jaw corners
		_muscle(head, 0.06, skin, Vector3(0.095 * side, -0.13, -0.03), Vector3(1.0, 0.9, 1.3))
	_muscle(head, 0.07, skin, Vector3(0, -0.165, -0.085), Vector3(1.3, 0.8, 0.9))    # chin
	if adult:
		_muscle(head, 0.025, mat(DAD_SKIN.darkened(0.12), 0.6), Vector3(0, -0.175, -0.18), Vector3(0.5, 1.0, 0.4))  # chin dimple
	for side: int in [-1, 1]:
		_muscle(head, 0.045, skin, Vector3(0.205 * side, 0.03, 0.0), Vector3(0.5, 1.2, 0.9))  # ears
		part(head, sphere(0.032), white, Vector3(0.075 * side, 0.065, -0.178), Vector3.ZERO, Vector3(1.35, 0.8, 0.6))
		part(head, sphere(0.018), iris, Vector3(0.075 * side, 0.065, -0.196))
		part(head, sphere(0.009), dark, Vector3(0.075 * side, 0.065, -0.21))
		_muscle(head, 0.036, skin, Vector3(0.075 * side, 0.088, -0.17), Vector3(1.35, 0.45, 0.7))  # eyelids
		part(head, capsule(0.012, 0.085), hair, Vector3(0.078 * side, 0.118, -0.185),
			Vector3(0, 0, PI / 2 - 0.15 * side))  # eyebrows
		if adult:
			part(head, capsule(0.025, 0.12), hair, Vector3(0.195 * side, 0.08, 0.0))  # sideburns
	part(head, capsule(0.022, 0.1), skin, Vector3(0, 0.03, -0.2), Vector3(-0.25, 0, 0))  # nose bridge
	_muscle(head, 0.03, skin, Vector3(0, -0.015, -0.215), Vector3(1.1, 0.8, 0.9))      # nose tip
	# the smile: a curve of white teeth between thin lips
	for k in 11:
		var f := (k - 5) / 5.0
		var y := -0.1 + f * f * 0.045
		var z: float = -0.188 + abs(f) * 0.035
		part(head, box(Vector3(0.016, 0.024 - f * f * 0.01, 0.012)), white, Vector3(f * 0.07, y, z), Vector3(0, f * 0.6, 0))
	for side: int in [-1, 1]:  # smile lines at the corners of his mouth
		part(head, capsule(0.006, 0.05), lip, Vector3(0.088 * side, -0.06, -0.15), Vector3(0, 0, 0.35 * side))
	# hair: short at the sides, with a swept-up quiff at the front
	_muscle(head, 0.215, hair, Vector3(0, 0.13, 0.03), Vector3(1.0, 0.7, 1.04))
	for k in 4:
		part(head, capsule(0.05, 0.2), hair, Vector3(-0.06 + k * 0.04, 0.24, -0.11 + k * 0.01),
			Vector3(-1.1 + k * 0.08, 0, 0.25 - k * 0.12))
	# a twinkle that flashes off his teeth now and then
	var sparkle := pivot(head, Vector3(0.06, -0.08, -0.23), "sparkle")
	var star := mat(Color(1, 1, 0.85), 0.1, 0.0, 6.0)
	part(sparkle, box(Vector3(0.16, 0.025, 0.01)), star)
	part(sparkle, box(Vector3(0.025, 0.16, 0.01)), star)
	part(sparkle, box(Vector3(0.09, 0.02, 0.01)), star, Vector3.ZERO, Vector3(0, 0, PI / 4))
	part(sparkle, box(Vector3(0.09, 0.02, 0.01)), star, Vector3.ZERO, Vector3(0, 0, -PI / 4))
	sparkle.visible = false
	d["sparkle"] = sparkle
	return head


# --------------------------------------------------------------------------- Jamie

const JAMIE_SIZE := 0.62  # same skeleton, scaled down to ~1.7 m


static func jamie() -> Dictionary:
	var root := Node3D.new()
	root.name = "JamieModel"
	root.scale = Vector3.ONE * JAMIE_SIZE
	var skin := mat(DAD_SKIN, 0.55, 0.0, 0.0, 0.25)
	var hoodie := mat(Color(0.06, 0.55, 0.5), 0.75, 0.0, 0.0, 0.25)
	var cuff := mat(Color(0.04, 0.4, 0.37), 0.8)
	var joggers := mat(Color(0.16, 0.16, 0.2), 0.85)
	var stripe := mat(Color(0.95, 0.95, 0.95), 0.6)
	var shoe := mat(Color(0.88, 0.12, 0.12), 0.45)
	var sole := mat(Color(0.97, 0.97, 0.97), 0.5)
	var gold := mat(Color(1.0, 0.78, 0.2), 0.25, 0.9, 0.4)
	var hair := mat(Color(0.38, 0.22, 0.1), 0.45, 0.0, 0.0, 0.2)
	var steel := mat(Color(0.75, 0.78, 0.82), 0.25, 0.85)
	var d := {"root": root}

	# legs: joggers with a white stripe, red trainers
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.21 * side, 1.08, 0.0), "leg_" + s)
		_muscle(hip, 0.19, joggers, Vector3(0, -0.06, 0), Vector3.ONE)
		part(hip, capsule(0.17, 0.66), joggers, Vector3(0, -0.28, 0))
		part(hip, box(Vector3(0.02, 0.6, 0.05)), stripe, Vector3(0.17 * side, -0.28, 0))
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		part(knee, capsule(0.13, 0.56), joggers, Vector3(0, -0.22, 0))
		part(knee, box(Vector3(0.02, 0.4, 0.05)), stripe, Vector3(0.13 * side, -0.2, 0))
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.12, shoe, Vector3(0, -0.0, -0.08), Vector3(1.0, 0.7, 1.9))
		part(ankle, box(Vector3(0.22, 0.05, 0.46)), sole, Vector3(0, -0.075, -0.08))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a hoodie with a gold J, over a strong build
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.25, joggers, Vector3(0, 0.06, 0.0), Vector3(1.1, 0.6, 0.85))
	part(torso, capsule(0.27, 0.8), hoodie, Vector3(0, 0.4, 0.02), Vector3.ZERO, Vector3(1.05, 1.0, 0.78))
	part(torso, cylinder(0.29, 0.29, 0.1, 18), cuff, Vector3(0, 0.13, 0.02), Vector3.ZERO, Vector3(1.05, 1.0, 0.8))
	_muscle(torso, 0.13, cuff, Vector3(0, 0.3, -0.19), Vector3(1.6, 0.8, 0.35))  # front pocket
	var chest := pivot(torso, Vector3(0, 0.8, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.4, hoodie, Vector3(0, 0.0, 0.03), Vector3(1.1, 0.8, 0.72))
	for side: int in [-1, 1]:
		_muscle(chest, 0.2, hoodie, Vector3(0.16 * side, 0.05, -0.15), Vector3(1.1, 0.8, 0.6))
	# the gold J
	# (he faces -Z, so his left (-x) is on the right as you look at him)
	part(chest, box(Vector3(0.05, 0.22, 0.03)), gold, Vector3(-0.03, 0.05, -0.29))
	part(chest, box(Vector3(0.12, 0.045, 0.03)), gold, Vector3(-0.03, 0.16, -0.29))
	part(chest, box(Vector3(0.1, 0.045, 0.03)), gold, Vector3(0.02, -0.06, -0.285))
	part(chest, box(Vector3(0.045, 0.07, 0.03)), gold, Vector3(0.065, -0.02, -0.285))
	# hood folded down at the back, drawstrings at the front
	_muscle(chest, 0.2, cuff, Vector3(0, 0.3, 0.2), Vector3(1.3, 0.6, 0.8))
	for side: int in [-1, 1]:
		part(chest, capsule(0.012, 0.2), stripe, Vector3(0.06 * side, 0.18, -0.25))
	part(chest, capsule(0.15, 0.35), skin, Vector3(0, 0.34, -0.02))  # neck
	# the jetpack he built himself
	var pack := pivot(chest, Vector3(0, -0.05, 0.32), "jetpack")
	part(pack, box(Vector3(0.36, 0.42, 0.14)), mat(Color(0.25, 0.27, 0.3), 0.4, 0.7))
	var flames: Array[Node3D] = []
	for side: int in [-1, 1]:
		part(pack, capsule(0.09, 0.5), steel, Vector3(0.14 * side, 0.0, 0.08))
		part(pack, cylinder(0.06, 0.08, 0.08, 10), mat(Color(0.2, 0.2, 0.22), 0.5, 0.6), Vector3(0.14 * side, -0.28, 0.08))
		_muscle(pack, 0.03, mat(Color(0.2, 1.0, 0.6), 0.2, 0.0, 4.0), Vector3(0.14 * side, 0.12, 0.17), Vector3.ONE)
		var flame := pivot(pack, Vector3(0.14 * side, -0.32, 0.08))
		part(flame, cylinder(0.065, 0.0, 0.4, 10), mat(Color(1.0, 0.6, 0.15), 0.2, 0.0, 5.0), Vector3(0, -0.2, 0))
		part(flame, cylinder(0.035, 0.0, 0.25, 8), mat(Color(1.0, 0.95, 0.6), 0.2, 0.0, 7.0), Vector3(0, -0.12, 0))
		flame.visible = false
		flames.append(flame)
	d["flames"] = flames

	# arms: hoodie sleeves, strong hands
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.48 * side, 0.18, 0.02), "arm_" + s)
		_muscle(sh, 0.18, hoodie, Vector3(0.02 * side, 0.0, 0), Vector3.ONE)
		part(sh, capsule(0.13, 0.6), hoodie, Vector3(0, -0.3, 0))
		_muscle(sh, 0.1, hoodie, Vector3(0, -0.27, -0.06), Vector3(1.0, 1.6, 1.0))
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		part(elbow, capsule(0.115, 0.5), hoodie, Vector3(0, -0.2, 0))
		part(elbow, cylinder(0.105, 0.105, 0.08, 12), cuff, Vector3(0, -0.42, 0))
		var wrist := pivot(elbow, Vector3(0, -0.5, 0), "hand_" + s)
		_muscle(wrist, 0.1, skin, Vector3(0, -0.04, 0), Vector3(1.0, 1.1, 0.8))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	# the family good looks (a slightly bigger head, he's still growing)
	var head := handsome_head(d, chest, Vector3(0, 0.58, -0.05), skin, hair, false)
	head.scale = Vector3.ONE * 1.25
	return d


# --------------------------------------------------------------------------- Charley

const CHARLEY_SIZE := 0.58  # same skeleton, scaled to a wee ~1.55 m


static func charley() -> Dictionary:
	var root := Node3D.new()
	root.name = "CharleyModel"
	root.scale = Vector3.ONE * CHARLEY_SIZE
	var skin := mat(Color(0.93, 0.7, 0.56), 0.65)
	var tee := mat(Color(1.0, 0.85, 0.25), 0.8)
	var shorts := mat(Color(0.35, 0.5, 0.3), 0.85)
	var sock := mat(Color(0.97, 0.97, 0.97), 0.8)
	var shoe := mat(Color(0.25, 0.35, 0.8), 0.5)
	var cap := mat(Color(0.85, 0.15, 0.15), 0.6)
	var hair := mat(Color(0.85, 0.45, 0.15), 0.6)
	var white := mat(Color(1, 1, 1), 0.3)
	var dark := mat(Color(0.08, 0.06, 0.05), 0.4)
	var pink := mat(Color(0.9, 0.5, 0.5), 0.6)
	var freckle := mat(Color(0.8, 0.5, 0.35), 0.7)
	var d := {"root": root}

	# legs: skinny, knobbly knees, baggy shorts, socks pulled up, big trainers
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.17 * side, 1.08, 0.0), "leg_" + s)
		part(hip, cylinder(0.17, 0.2, 0.42, 14), shorts, Vector3(0, -0.14, 0))
		part(hip, capsule(0.065, 0.6), skin, Vector3(0, -0.3, 0))
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		_muscle(knee, 0.085, skin, Vector3.ZERO, Vector3.ONE)  # knobbly knee
		part(knee, capsule(0.06, 0.5), skin, Vector3(0, -0.22, 0))
		part(knee, cylinder(0.07, 0.07, 0.2, 10), sock, Vector3(0, -0.38, 0))
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.12, shoe, Vector3(0, -0.01, -0.08), Vector3(1.0, 0.7, 2.0))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a skinny chest lost in a baggy t-shirt that's far too big for him
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	part(torso, cylinder(0.26, 0.3, 0.75, 16), tee, Vector3(0, 0.38, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	var chest := pivot(torso, Vector3(0, 0.78, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.27, tee, Vector3(0, -0.02, 0.0), Vector3(1.0, 0.75, 0.78))
	part(chest, capsule(0.06, 0.3), skin, Vector3(0, 0.25, -0.01))  # thin neck
	part(chest, box(Vector3(0.12, 0.12, 0.02)), mat(Color(0.3, 0.6, 1.0), 0.6), Vector3(0.0, 0.0, -0.22))  # a wee picture on his tee

	# arms: noodle arms in floppy sleeves
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.31 * side, 0.1, 0.0), "arm_" + s)
		part(sh, cylinder(0.1, 0.13, 0.3, 12), tee, Vector3(0.02 * side, -0.1, 0))
		part(sh, capsule(0.05, 0.6), skin, Vector3(0, -0.3, 0))
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		_muscle(elbow, 0.055, skin, Vector3.ZERO, Vector3.ONE)  # pointy elbow
		part(elbow, capsule(0.045, 0.5), skin, Vector3(0, -0.24, 0))
		var wrist := pivot(elbow, Vector3(0, -0.5, 0), "hand_" + s)
		_muscle(wrist, 0.065, skin, Vector3(0, -0.04, 0), Vector3(1.0, 1.1, 0.7))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	# head: round face, worried eyebrows, a little "o" mouth, freckles, cap on backwards
	var head := pivot(chest, Vector3(0, 0.55, -0.03), "head")
	head.scale = Vector3.ONE * 1.3
	d["head"] = head
	_muscle(head, 0.21, skin, Vector3(0, 0.02, 0), Vector3(1.0, 1.05, 1.0))
	for side: int in [-1, 1]:
		_muscle(head, 0.05, skin, Vector3(0.21 * side, 0.01, 0.0), Vector3(0.45, 1.0, 0.8))  # sticky-out ears
		part(head, sphere(0.04), white, Vector3(0.075 * side, 0.04, -0.18), Vector3.ZERO, Vector3(1.0, 1.15, 0.6))
		part(head, sphere(0.018), dark, Vector3(0.075 * side, 0.035, -0.205))
		part(head, capsule(0.009, 0.07), hair, Vector3(0.075 * side, 0.1, -0.19),
			Vector3(0, 0, PI / 2 + 0.4 * side))  # worried eyebrows
		for k in 3:
			part(head, sphere(0.008, 6), freckle, Vector3((0.07 + k * 0.022) * side, -0.025 - (k % 2) * 0.015, -0.19))
		part(head, sphere(0.022), pink, Vector3(0.11 * side, -0.04, -0.17), Vector3.ZERO, Vector3(1.4, 0.8, 0.5))  # rosy cheeks
	_muscle(head, 0.022, skin, Vector3(0, -0.005, -0.21), Vector3.ONE)  # button nose
	var mouth := pivot(head, Vector3(0, -0.085, -0.192), "mouth")
	var ring := TorusMesh.new()
	ring.inner_radius = 0.012
	ring.outer_radius = 0.022
	part(mouth, ring, mat(Color(0.55, 0.2, 0.2), 0.5), Vector3.ZERO, Vector3(PI / 2, 0, 0))
	d["mouth"] = mouth
	# ginger hair poking out under a cap worn backwards
	_muscle(head, 0.205, hair, Vector3(0, 0.06, 0.03), Vector3(1.04, 0.85, 1.04))
	_muscle(head, 0.2, cap, Vector3(0, 0.15, 0.01), Vector3(1.04, 0.62, 1.04))
	part(head, cylinder(0.15, 0.15, 0.02, 16), cap, Vector3(0, 0.15, 0.2), Vector3(0.2, 0, 0), Vector3(0.9, 1.0, 0.7))  # peak at the back
	for side: int in [-1, 1]:  # ginger tufts sticking out at the sides
		part(head, capsule(0.02, 0.09), hair, Vector3(0.19 * side, 0.09, -0.04), Vector3(0, 0, 0.9 * side))
	# beads of sweat when he's puffed out
	var sweat := pivot(head, Vector3(0, 0, 0), "sweat")
	for side: int in [-1, 1]:
		part(sweat, sphere(0.02, 8), mat(Color(0.6, 0.85, 1.0), 0.1, 0.0, 0.5), Vector3(0.2 * side, 0.12, -0.08),
			Vector3.ZERO, Vector3(1, 1.6, 1))
	sweat.visible = false
	d["sweat"] = sweat
	return d


# --------------------------------------------------------------------------- The Hacker

const HACKER_SIZE := 0.68  # same skeleton, ~1.85 m
const HACK_GREEN := Color(0.2, 1.0, 0.4)


static func hacker() -> Dictionary:
	var root := Node3D.new()
	root.name = "HackerModel"
	root.scale = Vector3.ONE * HACKER_SIZE
	var skin := mat(Color(0.86, 0.66, 0.52), 0.6)
	var hoodie := mat(Color(0.07, 0.07, 0.09), 0.85, 0.0, 0.0, 0.3)
	var trim := mat(Color(0.12, 0.12, 0.15), 0.85)
	var pants := mat(Color(0.2, 0.21, 0.23), 0.9)
	var shoe := mat(Color(0.05, 0.05, 0.06), 0.5)
	var glow := mat(HACK_GREEN, 0.2, 0.0, 3.5)
	var metal := mat(Color(0.55, 0.57, 0.6), 0.3, 0.8)
	var d := {"root": root}

	# legs: cargo trousers with pockets, black trainers with green soles
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.2 * side, 1.08, 0.0), "leg_" + s)
		_muscle(hip, 0.18, pants, Vector3(0, -0.06, 0), Vector3.ONE)
		part(hip, capsule(0.16, 0.66), pants, Vector3(0, -0.28, 0))
		part(hip, box(Vector3(0.08, 0.16, 0.2)), trim, Vector3(0.16 * side, -0.32, 0))  # cargo pocket
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		part(knee, capsule(0.13, 0.56), pants, Vector3(0, -0.22, 0))
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.12, shoe, Vector3(0, -0.0, -0.08), Vector3(1.0, 0.7, 1.9))
		part(ankle, box(Vector3(0.22, 0.04, 0.46)), glow, Vector3(0, -0.075, -0.08))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a black hoodie with a glowing green circuit pattern
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.25, pants, Vector3(0, 0.06, 0.0), Vector3(1.1, 0.6, 0.85))
	part(torso, capsule(0.28, 0.82), hoodie, Vector3(0, 0.4, 0.02), Vector3.ZERO, Vector3(1.05, 1.0, 0.8))
	var chest := pivot(torso, Vector3(0, 0.8, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.38, hoodie, Vector3(0, 0.0, 0.03), Vector3(1.1, 0.8, 0.75))
	# circuit lines and a green skull-and-keyboard... well, a glowing chip
	part(chest, box(Vector3(0.14, 0.14, 0.02)), glow, Vector3(0, 0.02, -0.28))
	part(chest, box(Vector3(0.09, 0.09, 0.025)), trim, Vector3(0, 0.02, -0.285))
	for k in 4:
		part(chest, box(Vector3(0.012, 0.012, 0.1 + k * 0.03)), glow,
			Vector3(-0.1 + k * 0.065, -0.08 - k * 0.02, -0.27), Vector3(PI / 2, 0, 0))
		part(chest, box(Vector3(0.18, 0.012, 0.012)), glow, Vector3(0.12 * (1 if k % 2 else -1), 0.12 - k * 0.07, -0.26))
	# backpack with an antenna
	part(chest, box(Vector3(0.34, 0.4, 0.15)), trim, Vector3(0, -0.05, 0.3))
	part(chest, cylinder(0.008, 0.012, 0.5, 6), metal, Vector3(0.13, 0.35, 0.33))
	_muscle(chest, 0.025, glow, Vector3(0.13, 0.6, 0.33), Vector3.ONE)

	# arms: hoodie sleeves; a glowing laptop in his left hand
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.46 * side, 0.16, 0.02), "arm_" + s)
		_muscle(sh, 0.16, hoodie, Vector3(0.02 * side, 0.0, 0), Vector3.ONE)
		part(sh, capsule(0.12, 0.6), hoodie, Vector3(0, -0.3, 0))
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		part(elbow, capsule(0.11, 0.5), hoodie, Vector3(0, -0.2, 0))
		var wrist := pivot(elbow, Vector3(0, -0.5, 0), "hand_" + s)
		_muscle(wrist, 0.09, skin, Vector3(0, -0.04, 0), Vector3(1.0, 1.1, 0.8))
		if side < 0:  # the laptop, open, held flat like a tray
			var laptop := pivot(wrist, Vector3(0, -0.1, -0.12), "laptop")
			part(laptop, box(Vector3(0.36, 0.02, 0.25)), metal)
			part(laptop, box(Vector3(0.3, 0.005, 0.18)), trim, Vector3(0, 0.012, 0.01))  # keyboard
			var lid := pivot(laptop, Vector3(0, 0.0, 0.125))
			lid.rotation.x = -1.9
			part(lid, box(Vector3(0.36, 0.02, 0.25)), metal, Vector3(0, 0, -0.125))
			for face in [-1.0, 1.0]:  # glowing screen (on both sides, so you can always see it)
				part(lid, box(Vector3(0.32, 0.005, 0.21)), glow, Vector3(0, 0.012 * face, -0.125))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	# head: hood up, glowing green visor, headset with a mic
	var head := pivot(chest, Vector3(0, 0.55, -0.04), "head")
	head.scale = Vector3.ONE * 1.15
	d["head"] = head
	_muscle(head, 0.2, skin, Vector3(0, 0.02, 0), Vector3(0.95, 1.1, 1.0))
	_muscle(head, 0.25, hoodie, Vector3(0, 0.06, 0.07), Vector3(1.05, 1.1, 1.0))  # the hood
	part(head, cylinder(0.2, 0.2, 0.05, 18), trim, Vector3(0, 0.04, -0.13), Vector3(PI / 2, 0, 0), Vector3(1.05, 1.0, 1.25))  # hood rim
	part(head, box(Vector3(0.3, 0.07, 0.06)), glow, Vector3(0, 0.06, -0.18))  # visor
	part(head, box(Vector3(0.32, 0.09, 0.05)), trim, Vector3(0, 0.06, -0.165))
	_muscle(head, 0.03, skin, Vector3(0, -0.02, -0.2), Vector3(0.8, 1.0, 0.9))  # nose
	part(head, box(Vector3(0.08, 0.012, 0.02)), mat(Color(0.5, 0.25, 0.25), 0.5), Vector3(0.015, -0.1, -0.185),
		Vector3(0, 0, -0.15))  # a sly smirk
	for side: int in [-1, 1]:
		part(head, cylinder(0.06, 0.06, 0.04, 12), trim, Vector3(0.2 * side, 0.02, -0.02), Vector3(0, 0, PI / 2))
	part(head, cylinder(0.01, 0.01, 0.2, 6), trim, Vector3(-0.17, -0.07, -0.11), Vector3(0.9, 0.6, 0))  # mic arm
	_muscle(head, 0.02, glow, Vector3(-0.1, -0.12, -0.18), Vector3.ONE)
	return d


# --------------------------------------------------------------------------- Santa and his reindeer

const SANTA_SIZE := 0.74  # same skeleton, ~2 m
const SANTA_RED := Color(0.8, 0.07, 0.1)


static func reindeer(rudolph := false) -> Dictionary:
	## A flying reindeer, facing -Z, hooves at y = 0, about 1.6 m tall at the antlers.
	var root := Node3D.new()
	var fur := mat(Color(0.48, 0.3, 0.16), 0.8)
	var belly := mat(Color(0.82, 0.7, 0.55), 0.8)
	var dark := mat(Color(0.18, 0.1, 0.05), 0.6)
	var antler := mat(Color(0.75, 0.65, 0.48), 0.6)
	var white := mat(Color(1, 1, 1), 0.3)
	var black := mat(Color(0.03, 0.03, 0.03), 0.3)
	var d := {"root": root}
	var body := pivot(root, Vector3(0, 0.95, 0), "body")
	d["body"] = body
	part(body, capsule(0.28, 1.15), fur, Vector3.ZERO, Vector3(PI / 2, 0, 0))
	_muscle(body, 0.24, belly, Vector3(0, -0.08, 0), Vector3(1.0, 0.8, 2.0))
	part(body, sphere(0.1), white, Vector3(0, 0.1, 0.58))  # fluffy tail
	var legs: Array[Node3D] = []
	for z: float in [-0.38, 0.38]:
		for side: int in [-1, 1]:
			var hip := pivot(body, Vector3(0.16 * side, -0.1, z))
			part(hip, capsule(0.06, 0.8), fur, Vector3(0, -0.38, 0))
			part(hip, cylinder(0.055, 0.06, 0.1, 8), dark, Vector3(0, -0.8, 0))  # hoof
			legs.append(hip)
	d["legs"] = legs
	# neck and head
	var neck := pivot(body, Vector3(0, 0.15, -0.5), "neck")
	part(neck, capsule(0.13, 0.6), fur, Vector3(0, 0.22, -0.08), Vector3(-0.45, 0, 0))
	var head := pivot(neck, Vector3(0, 0.5, -0.2), "head")
	_muscle(head, 0.15, fur, Vector3(0, 0, 0), Vector3(0.9, 0.9, 1.2))
	_muscle(head, 0.1, belly, Vector3(0, -0.05, -0.17), Vector3(0.9, 0.8, 1.2))  # muzzle
	var nose_mat := mat(Color(1.0, 0.08, 0.05), 0.2, 0.0, 5.0) if rudolph else black
	part(head, sphere(0.055 if rudolph else 0.04), nose_mat, Vector3(0, -0.03, -0.3))
	for side: int in [-1, 1]:
		part(head, sphere(0.03), black, Vector3(0.08 * side, 0.05, -0.1))
		part(head, sphere(0.045), fur, Vector3(0.13 * side, 0.1, 0.03), Vector3.ZERO, Vector3(0.5, 1.4, 0.8))  # ears
		# antlers: a main beam with a few tines
		var a := pivot(head, Vector3(0.07 * side, 0.12, 0.02))
		a.rotation = Vector3(-0.3, 0, -0.45 * side)
		part(a, cylinder(0.018, 0.028, 0.45, 6), antler, Vector3(0, 0.22, 0))
		for k in 3:
			var tine := pivot(a, Vector3(0, 0.12 + k * 0.11, 0))
			tine.rotation = Vector3(-0.6 + k * 0.3, 0, -0.8 * side if k % 2 == 0 else 0.7 * side)
			part(tine, cylinder(0.01, 0.018, 0.16, 5), antler, Vector3(0, 0.08, 0))
	# a red harness with a gold bell
	part(neck, cylinder(0.15, 0.15, 0.06, 12), mat(SANTA_RED, 0.5), Vector3(0, 0.05, 0), Vector3(0.6, 0, 0))
	part(neck, sphere(0.05), mat(Color(1.0, 0.8, 0.2), 0.25, 0.9), Vector3(0, -0.03, -0.14))
	return d


static func animate_reindeer(d: Dictionary, t: float) -> void:
	## Galloping through the air.
	var legs: Array = d["legs"]
	for i in legs.size():
		var front := i < 2
		var ph := t * 14.0 + (0.0 if front else PI) + (i % 2) * 0.4
		(legs[i] as Node3D).rotation.x = sin(ph) * 0.7 + (-0.5 if front else 0.5)
	(d["body"] as Node3D).position.y = 0.95 + sin(t * 28.0) * 0.05


static func santa() -> Dictionary:
	var root := Node3D.new()
	root.name = "SantaModel"
	root.scale = Vector3.ONE * SANTA_SIZE
	var red := mat(SANTA_RED, 0.75, 0.0, 0.0, 0.2)
	var fur := mat(Color(0.98, 0.98, 0.97), 0.95)
	var skin := mat(Color(0.96, 0.75, 0.62), 0.6)
	var black := mat(Color(0.05, 0.05, 0.05), 0.35)
	var gold := mat(Color(1.0, 0.8, 0.2), 0.25, 0.9, 0.2)
	var glove := mat(Color(0.12, 0.12, 0.12), 0.6)
	var rosy := mat(Color(0.95, 0.45, 0.45), 0.6)
	var d := {"root": root}

	# legs: red trousers, big black boots with white fur tops
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var hip := pivot(root, Vector3(0.24 * side, 1.08, 0.0), "leg_" + s)
		_muscle(hip, 0.22, red, Vector3(0, -0.06, 0), Vector3.ONE)
		part(hip, capsule(0.19, 0.66), red, Vector3(0, -0.28, 0))
		var knee := pivot(hip, Vector3(0, -0.56, 0), "shin_" + s)
		part(knee, capsule(0.16, 0.3), red, Vector3(0, -0.05, 0))
		part(knee, cylinder(0.19, 0.19, 0.1, 14), fur, Vector3(0, -0.2, 0))
		part(knee, capsule(0.16, 0.36), black, Vector3(0, -0.36, 0))
		var ankle := pivot(knee, Vector3(0, -0.5, 0), "foot_" + s)
		_muscle(ankle, 0.14, black, Vector3(0, -0.0, -0.09), Vector3(1.0, 0.7, 1.8))
		d["leg_" + s] = hip
		d["shin_" + s] = knee

	# torso: a big round jolly belly, belt with a gold buckle, fur down the front
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	_muscle(torso, 0.42, red, Vector3(0, 0.35, -0.06), Vector3(1.05, 1.0, 1.0))  # belly
	part(torso, cylinder(0.43, 0.43, 0.12, 20), black, Vector3(0, 0.25, -0.06), Vector3.ZERO, Vector3(1.05, 1.0, 1.0))
	part(torso, box(Vector3(0.18, 0.15, 0.04)), gold, Vector3(0, 0.25, -0.5))
	part(torso, box(Vector3(0.1, 0.07, 0.05)), black, Vector3(0, 0.25, -0.505))
	part(torso, cylinder(0.44, 0.4, 0.12, 20), fur, Vector3(0, -0.02, -0.04))  # fur hem
	part(torso, box(Vector3(0.12, 0.62, 0.05)), fur, Vector3(0, 0.45, -0.465), Vector3(-0.1, 0, 0))
	var chest := pivot(torso, Vector3(0, 0.8, 0), "chest")
	d["chest"] = chest
	_muscle(chest, 0.36, red, Vector3(0, 0.0, 0.0), Vector3(1.15, 0.8, 0.85))
	# the sack of presents on his back
	_muscle(chest, 0.32, mat(Color(0.55, 0.4, 0.25), 0.9), Vector3(0.05, 0.05, 0.42), Vector3(1.0, 1.25, 0.8))
	part(chest, box(Vector3(0.14, 0.14, 0.14)), mat(Color(0.2, 0.7, 0.3), 0.5), Vector3(0.12, 0.42, 0.38), Vector3(0.3, 0.4, 0))
	part(chest, box(Vector3(0.12, 0.12, 0.12)), mat(Color(0.3, 0.45, 0.95), 0.5), Vector3(-0.06, 0.4, 0.45), Vector3(-0.2, 0.7, 0.2))

	# arms: red sleeves, fur cuffs, black gloves
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(chest, Vector3(0.48 * side, 0.15, 0.0), "arm_" + s)
		_muscle(sh, 0.18, red, Vector3(0.02 * side, 0.0, 0), Vector3.ONE)
		part(sh, capsule(0.14, 0.6), red, Vector3(0, -0.3, 0))
		var elbow := pivot(sh, Vector3(0, -0.58, 0), "fore_" + s)
		part(elbow, capsule(0.13, 0.48), red, Vector3(0, -0.18, 0))
		part(elbow, cylinder(0.15, 0.15, 0.1, 12), fur, Vector3(0, -0.4, 0))
		var wrist := pivot(elbow, Vector3(0, -0.5, 0), "hand_" + s)
		_muscle(wrist, 0.11, glove, Vector3(0, -0.04, 0), Vector3(1.0, 1.1, 0.8))
		d["arm_" + s] = sh
		d["fore_" + s] = elbow

	# head: rosy cheeks, a big white beard and moustache, twinkly eyes, the hat
	var head := pivot(chest, Vector3(0, 0.52, -0.04), "head")
	head.scale = Vector3.ONE * 1.2
	d["head"] = head
	_muscle(head, 0.2, skin, Vector3(0, 0.03, 0), Vector3(0.95, 1.05, 1.0))
	_muscle(head, 0.22, fur, Vector3(0, -0.14, -0.06), Vector3(1.0, 1.15, 0.85))  # beard
	_muscle(head, 0.1, fur, Vector3(0, -0.32, -0.1), Vector3(1.1, 1.0, 0.8))      # beard tip
	for side: int in [-1, 1]:
		_muscle(head, 0.06, fur, Vector3(0.06 * side, -0.04, -0.2), Vector3(1.5, 0.6, 0.7), Vector3(0, 0, -0.3 * side))  # moustache
		_muscle(head, 0.045, rosy, Vector3(0.11 * side, 0.0, -0.15), Vector3.ONE)  # rosy cheeks
		part(head, sphere(0.022), black, Vector3(0.065 * side, 0.07, -0.18))
		part(head, sphere(0.008), mat(Color(1, 1, 1), 0.2, 0.0, 1.0), Vector3(0.06 * side, 0.078, -0.198))  # twinkle
		part(head, capsule(0.012, 0.07), fur, Vector3(0.067 * side, 0.115, -0.18), Vector3(0, 0, PI / 2))  # white eyebrows
	_muscle(head, 0.04, rosy, Vector3(0, 0.02, -0.2), Vector3.ONE)  # nose
	# the hat: fur band, red cone flopping over, white pompom
	part(head, cylinder(0.22, 0.22, 0.08, 18), fur, Vector3(0, 0.17, 0))
	var hat := pivot(head, Vector3(0, 0.2, 0))
	part(hat, cylinder(0.04, 0.2, 0.32, 14), red, Vector3(0, 0.15, 0.03), Vector3(0.3, 0, 0))
	part(hat, sphere(0.06), fur, Vector3(0, 0.29, 0.13))

	# the sleigh with two reindeer, only there while he flies
	var sleigh := pivot(root, Vector3(0, 0.3, 0), "sleigh")
	var wood := mat(SANTA_RED, 0.4, 0.2)
	part(sleigh, box(Vector3(1.2, 0.5, 1.6)), wood, Vector3(0, 0.15, 0.1))
	part(sleigh, box(Vector3(1.25, 0.6, 0.15)), wood, Vector3(0, 0.45, 0.85))  # seat back
	part(sleigh, box(Vector3(1.3, 0.08, 0.1)), gold, Vector3(0, 0.42, -0.7))
	for side: int in [-1, 1]:
		part(sleigh, box(Vector3(0.06, 0.06, 2.2)), gold, Vector3(0.55 * side, -0.25, 0))  # runners
		part(sleigh, cylinder(0.12, 0.12, 0.06, 12), gold, Vector3(0.55 * side, -0.13, -1.1), Vector3(0, 0, PI / 2))
		for k in 3:
			part(sleigh, cylinder(0.02, 0.02, 0.35, 5), gold, Vector3(0.55 * side, -0.1, -0.6 + k * 0.6))
	var team: Array = []
	for k in 2:
		var deer := reindeer(k == 0)
		var rd: Node3D = deer["root"]
		rd.position = Vector3(0, -0.3, -2.3 - k * 1.7)
		rd.scale = Vector3.ONE * 1.2
		sleigh.add_child(rd)
		team.append(deer)
		part(sleigh, cylinder(0.015, 0.015, 1.7, 4), mat(Color(0.3, 0.2, 0.1), 0.6), Vector3(0.2, 0.7, -1.5 - k * 1.7),
			Vector3(PI / 2, 0, 0))
	sleigh.visible = false
	d["sleigh"] = sleigh
	d["team"] = team
	return d


# --------------------------------------------------------------------------- Ms Cattoon

const STINK_GREEN := Color(0.55, 0.8, 0.2)


static func stink_material(alpha := 0.35) -> StandardMaterial3D:
	var key := "stink%s" % alpha
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(STINK_GREEN, alpha)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mats[key] = m
	return _mats[key]


static func fly() -> Node3D:
	var n := Node3D.new()
	part(n, sphere(0.07, 6), mat(Color(0.05, 0.05, 0.05), 0.3))
	for side: int in [-1, 1]:
		part(n, box(Vector3(0.12, 0.01, 0.06)), mat(Color(0.9, 0.95, 1.0, 1.0), 0.2), Vector3(0.07 * side, 0.04, 0))
	return n


static func cattoon() -> Dictionary:
	## Ms Cattoon: a giant stinky cartoon cat-lady, about 6 m tall, facing -Z.
	var root := Node3D.new()
	root.name = "CattoonModel"
	var fur := mat(Color(0.48, 0.45, 0.46), 0.9)
	var mould := mat(Color(0.42, 0.58, 0.12), 0.9)
	var pink := mat(Color(0.95, 0.55, 0.65), 0.7)
	var dress := mat(Color(0.5, 0.25, 0.55), 0.8)
	var dots := mat(Color(0.85, 0.7, 0.9), 0.8)
	var cardi := mat(Color(0.6, 0.48, 0.2), 0.9)
	var white := mat(Color(0.97, 0.97, 0.95), 0.6)
	var black := mat(Color(0.04, 0.04, 0.04), 0.4)
	var eye := mat(Color(0.85, 0.9, 0.2), 0.2, 0.0, 0.6)
	var frames := mat(Color(0.85, 0.1, 0.25), 0.3, 0.3)
	var bag := mat(Color(0.6, 0.1, 0.12), 0.35)
	var gold := mat(Color(1.0, 0.8, 0.2), 0.25, 0.9)
	var d := {"root": root}
	var body := pivot(root, Vector3.ZERO, "body")
	d["body"] = body
	# fluffy pink slippers and stumpy legs
	for side: int in [-1, 1]:
		part(body, capsule(0.28, 1.2), fur, Vector3(0.5 * side, 0.75, 0))
		_muscle(body, 0.35, pink, Vector3(0.5 * side, 0.22, -0.2), Vector3(1.0, 0.6, 1.5))
	# a huge pear-shaped polka-dot dress and a frumpy cardigan
	_muscle(body, 1.5, dress, Vector3(0, 2.1, 0), Vector3(1.0, 1.0, 0.9))
	for k in 14:
		var a := k * 2.4
		var y := 1.4 + (k % 5) * 0.3
		var rr := 1.5 * sqrt(max(0.1, 1.0 - pow((y - 2.1) / 1.5, 2)))
		part(body, sphere(0.1, 8), dots, Vector3(sin(a) * rr, y, cos(a) * rr * 0.9), Vector3.ZERO, Vector3(1, 1, 0.4))
	_muscle(body, 1.25, cardi, Vector3(0, 3.1, 0.05), Vector3(1.05, 0.8, 0.95))
	_muscle(body, 0.75, dress, Vector3(0, 3.1, -0.55), Vector3(0.7, 0.85, 0.6))  # dress showing at the front
	for k in 3:
		part(body, sphere(0.07, 8), gold, Vector3(0.48, 2.85 + k * 0.25, -1.05 + k * 0.05))
	# a long stripy tail curling up behind her
	var tail_segs: Array[Node3D] = []
	var prev := pivot(body, Vector3(0, 1.4, 1.2), "tail")
	for k in 7:
		var seg := pivot(prev, Vector3(0, 0.35, 0) if k > 0 else Vector3.ZERO)
		part(seg, capsule(0.16 - k * 0.012, 0.45), fur if k % 2 == 0 else mould, Vector3(0, 0.18, 0))
		tail_segs.append(seg)
		prev = seg
	d["tail"] = tail_segs
	# arms in cardigan sleeves; the right one swings a handbag
	for side: int in [-1, 1]:
		var s := "l" if side < 0 else "r"
		var sh := pivot(body, Vector3(1.15 * side, 3.4, 0), "arm_" + s)
		part(sh, capsule(0.3, 1.5), cardi, Vector3(0, -0.6, 0))
		_muscle(sh, 0.28, fur, Vector3(0, -1.4, 0), Vector3.ONE)  # paw
		for c in 3:
			part(sh, cylinder(0.0, 0.04, 0.16, 5), white, Vector3((c - 1) * 0.1, -1.68, -0.08), Vector3(0.3, 0, 0))
		d["arm_" + s] = sh
		if side > 0:
			var hb := pivot(sh, Vector3(0, -1.6, 0), "handbag")
			var handle := TorusMesh.new()
			handle.inner_radius = 0.2
			handle.outer_radius = 0.26
			part(hb, handle, bag, Vector3(0, -0.15, 0), Vector3(0, 0, PI / 2))
			part(hb, box(Vector3(0.7, 0.5, 0.3)), bag, Vector3(0, -0.6, 0))
			part(hb, box(Vector3(0.12, 0.1, 0.05)), gold, Vector3(0, -0.45, -0.17))
	# the head: a big round cat face
	var head := pivot(body, Vector3(0, 4.4, -0.1), "head")
	d["head"] = head
	_muscle(head, 1.0, fur, Vector3.ZERO, Vector3(1.15, 1.0, 1.0))
	for p: Vector3 in [Vector3(0.6, 0.45, -0.6), Vector3(-0.85, -0.2, -0.45), Vector3(0.2, 0.85, 0.3), Vector3(-0.5, 0.5, 0.65)]:
		_muscle(head, 0.25, mould, p, Vector3(1.0, 0.8, 0.5))  # mouldy patches
	for side: int in [-1, 1]:
		var ear := pivot(head, Vector3(0.65 * side, 0.75, 0.0))
		ear.rotation.z = -0.35 * side
		part(ear, cylinder(0.0, 0.38, 0.7, 4), fur, Vector3(0, 0.3, 0))
		part(ear, cylinder(0.0, 0.25, 0.5, 4), pink, Vector3(0, 0.25, -0.1))
		# big yellow cat eyes with slit pupils, behind red cat-eye glasses
		part(head, sphere(0.24), eye, Vector3(0.38 * side, 0.18, -0.82), Vector3.ZERO, Vector3(1.0, 0.85, 0.5))
		part(head, box(Vector3(0.06, 0.32, 0.05)), black, Vector3(0.38 * side, 0.18, -0.95))
		var ring := TorusMesh.new()
		ring.inner_radius = 0.24
		ring.outer_radius = 0.3
		part(head, ring, frames, Vector3(0.38 * side, 0.18, -0.95), Vector3(PI / 2, 0, 0), Vector3(1.1, 1.0, 0.9))
		part(head, box(Vector3(0.3, 0.07, 0.06)), frames, Vector3(0.68 * side, 0.36, -0.88), Vector3(0, 0, 0.5 * side))  # the pointy wings
		# muzzle and whiskers
		_muscle(head, 0.22, white, Vector3(0.15 * side, -0.3, -0.85), Vector3(1.0, 0.8, 0.6))
		for k in 3:
			part(head, cylinder(0.012, 0.012, 0.9, 4), black, Vector3(0.6 * side, -0.25 + k * 0.08, -0.85),
				Vector3(0, 0, PI / 2 + (k - 1) * 0.15 * side))
	part(head, box(Vector3(0.1, 0.04, 0.04)), frames, Vector3(0, 0.2, -0.98))  # bridge of the glasses
	_muscle(head, 0.12, pink, Vector3(0, -0.12, -0.98), Vector3(1.2, 0.8, 0.7))  # nose
	part(head, capsule(0.04, 0.5), black, Vector3(0, -0.55, -0.88), Vector3(0, 0, PI / 2))  # grumpy mouth
	part(head, cylinder(0.0, 0.05, 0.14, 5), white, Vector3(0.12, -0.62, -0.88), Vector3(PI, 0, 0))  # a fang
	# hair in a bun with curlers
	_muscle(head, 0.5, mat(Color(0.55, 0.45, 0.6), 0.8), Vector3(0, 0.95, 0.25), Vector3(1.0, 0.75, 1.0))
	for k in 3:
		part(head, cylinder(0.11, 0.11, 0.3, 10), pink, Vector3(-0.3 + k * 0.3, 1.3, 0.2), Vector3(0, 0, PI / 2))
	# stink wisps rising off her, and flies buzzing round her head
	var wisps: Array[Node3D] = []
	for k in 8:
		var w := part(body, sphere(0.5 + (k % 3) * 0.2, 10), stink_material(0.22), Vector3.ZERO)
		wisps.append(w)
	d["wisps"] = wisps
	var flies: Array[Node3D] = []
	for k in 6:
		var f := fly()
		body.add_child(f)
		flies.append(f)
	d["flies"] = flies
	# the stink zone on the ground round her
	var zone := MeshInstance3D.new()
	zone.mesh = cylinder(1.0, 1.0, 0.04, 32)
	zone.material_override = stink_material(0.18)
	zone.position.y = 0.06
	root.add_child(zone)
	d["zone"] = zone
	return d


static func animate_cattoon(d: Dictionary, t: float, angry: bool, puff: float, aura_r: float) -> void:
	var body: Node3D = d["body"]
	body.position.y = abs(sin(t * 2.2)) * 0.12
	body.scale = Vector3.ONE * (1.0 + puff * 0.18)
	(d["head"] as Node3D).rotation.z = sin(t * 1.3) * 0.08
	var tail: Array = d["tail"]
	for i in tail.size():
		(tail[i] as Node3D).rotation = Vector3(0.25 + 0.1 * i * 0.3, 0, sin(t * (3.0 if angry else 1.8) - i * 0.6) * 0.25)
	var wisps: Array = d["wisps"]
	for i in wisps.size():
		var ph := fmod(t * 0.35 + i / float(wisps.size()), 1.0)
		var a := i * 2.3 + t * 0.4
		var r := 1.8 + ph * 2.5
		var w := wisps[i] as Node3D
		w.position = Vector3(cos(a) * r, 1.0 + ph * 6.0, sin(a) * r)
		w.scale = Vector3.ONE * (0.6 + ph * 1.2) * (1.4 if angry else 1.0)
	var flies: Array = d["flies"]
	for i in flies.size():
		var a := t * (4.0 + i * 0.7) + i
		(flies[i] as Node3D).position = Vector3(cos(a) * (1.6 + 0.3 * sin(t * 3 + i)), 4.6 + sin(a * 1.7) * 0.6,
			sin(a) * (1.6 + 0.3 * cos(t * 2 + i)) - 0.1)
	var zone: Node3D = d["zone"]
	zone.scale = Vector3(aura_r, 1.0, aura_r)


static func web_cocoon(r: float, h: float) -> Node3D:
	## A white web wrapping round a stuck enemy.
	var n := Node3D.new()
	var web := StandardMaterial3D.new()
	web.albedo_color = Color(0.95, 0.95, 1.0, 0.55)
	web.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	web.roughness = 0.6
	part(n, sphere(1.0, 12), web, Vector3.ZERO, Vector3.ZERO, Vector3(r, h * 0.5, r))
	var strand := mat(Color(0.97, 0.97, 1.0), 0.5, 0.0, 0.2)
	for i in 5:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.95
		ring.outer_radius = 1.0
		ring.rings = 24
		ring.ring_segments = 4
		var mi := part(n, ring, strand, Vector3(0, (i - 2) * h * 0.17, 0))
		var w := sqrt(max(0.05, 1.0 - pow((i - 2) * 0.34, 2)))
		mi.scale = Vector3(r * w * 1.03, 1.0, r * w * 1.03)
		mi.rotation = Vector3(0.25 * ((i % 2) * 2 - 1), 0, 0.2)
	return n


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
