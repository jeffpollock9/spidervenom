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

const VENOM_BLACK := Color(0.045, 0.045, 0.065)
const VENOM_SHEEN := Color(0.17, 0.17, 0.27)


static func venom() -> Dictionary:
	var root := Node3D.new()
	root.name = "VenomModel"
	var black := mat(VENOM_BLACK, 0.22, 0.25, 0.0, 0.7)
	var sheen := mat(VENOM_SHEEN, 0.3, 0.2)
	var white := mat(Color(0.96, 0.96, 1.0), 0.4, 0.0, 0.25)
	var red := mat(Color(0.85, 0.15, 0.35), 0.4)
	var d := {"root": root}

	# legs (pivots at the hips, swing about X)
	for side: int in [-1, 1]:
		var hip := pivot(root, Vector3(0.24 * side, 1.02, 0), "leg_l" if side < 0 else "leg_r")
		part(hip, capsule(0.18, 1.05), black, Vector3(0, -0.5, 0))
		part(hip, box(Vector3(0.3, 0.16, 0.48)), black, Vector3(0, -0.98, -0.08))
		d["leg_l" if side < 0 else "leg_r"] = hip

	# torso: a broad muscular chest
	var torso := pivot(root, Vector3(0, 1.0, 0), "torso")
	d["torso"] = torso
	part(torso, capsule(0.46, 1.15), black, Vector3(0, 0.55, 0), Vector3.ZERO, Vector3(1.2, 1.0, 0.82))
	part(torso, sphere(0.36), sheen, Vector3(0, 0.78, -0.2), Vector3.ZERO, Vector3(1.25, 0.8, 0.5))
	# white spider emblem: body plus legs wrapping round the chest
	part(torso, sphere(0.12), white, Vector3(0, 0.72, -0.37), Vector3.ZERO, Vector3(0.9, 1.5, 0.4))
	for side: int in [-1, 1]:
		for k in 4:
			var y := 0.95 - k * 0.14
			var ang := (0.9 - k * 0.45) * side
			part(torso, box(Vector3(0.5, 0.045, 0.05)), white,
				Vector3(0.24 * side, y, -0.33 + abs(k - 1.5) * 0.02), Vector3(0, -0.45 * side, ang))

	# arms (pivots at the shoulders)
	for side: int in [-1, 1]:
		var sh := pivot(torso, Vector3(0.66 * side, 0.98, 0), "arm_l" if side < 0 else "arm_r")
		part(sh, sphere(0.25), black, Vector3.ZERO)
		part(sh, capsule(0.16, 0.95), black, Vector3(0, -0.45, 0))
		part(sh, sphere(0.2), black, Vector3(0, -0.95, 0))
		for c in 3:  # claws
			part(sh, box(Vector3(0.04, 0.16, 0.04)), white, Vector3((c - 1) * 0.08, -1.13, -0.08), Vector3(0.4, 0, 0))
		d["arm_l" if side < 0 else "arm_r"] = sh

	# head
	var head := pivot(torso, Vector3(0, 1.38, -0.05), "head")
	d["head"] = head
	part(head, sphere(0.37), black, Vector3.ZERO, Vector3.ZERO, Vector3(1.0, 1.05, 1.12))
	for side: int in [-1, 1]:  # big angular white eyes
		part(head, sphere(0.17), white, Vector3(0.16 * side, 0.08, -0.32), Vector3(0.2, 0.35 * side, 0.55 * side),
			Vector3(1.0, 0.48, 0.25))
	part(head, sphere(0.25), white, Vector3(0, -0.15, -0.31), Vector3(0.1, 0, 0), Vector3(1.05, 0.42, 0.3))
	for k in 7:  # gaps between the teeth
		part(head, box(Vector3(0.016, 0.11, 0.05)), black, Vector3(-0.21 + k * 0.07, -0.15, -0.39))
	var tongue := pivot(head, Vector3(0, -0.2, -0.36), "tongue")
	part(tongue, capsule(0.055, 0.5), red, Vector3(0, -0.2, -0.04), Vector3(0.3, 0, 0))
	d["tongue"] = tongue

	# symbiote wings, folded away until he flies
	var wings := pivot(torso, Vector3(0, 0.95, 0.32), "wings")
	wings.visible = false
	d["wings"] = wings
	for side: int in [-1, 1]:
		var w := pivot(wings, Vector3(0.18 * side, 0, 0), "wing_l" if side < 0 else "wing_r")
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
