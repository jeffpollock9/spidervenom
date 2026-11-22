class_name LevelSupercity
extends Node3D
## Supercity in 3D: a long avenue between skyscrapers running along +X, broken by two gaps
## you cross on moving sky-lifts (or by swinging and flying), ending in a plaza where Mr Poo waits.

const STREET_HALF := 12.0      # street + pavements span z in [-12, 12]
const GAP1 := Vector2(70, 92)
const GAP2 := Vector2(160, 188)
const ARENA_X0 := 262.0
const ARENA_X1 := 322.0
const ARENA_HALF_Z := 30.0
const GATE_X := 266.0

var spawns: Array = []     # [kind, Vector3]
var pickups: Array = []    # [kind, Vector3]
var start := Vector3(2, 0.2, 0)
var boss_pos := Vector3(305, 0.2, 0)
var arena_center := Vector3(292, 0, 0)
var gate: StaticBody3D
var arena_walls: Array[CollisionShape3D] = []
var lifts: Array = []
var rng := RandomNumberGenerator.new()
var t := 0.0


func _ready() -> void:
	rng.seed = 4242
	_environment()
	_ground()
	_buildings()
	_props()
	_sky_lifts()
	_arena()
	_bounds()


# ------------------------------------------------------------------ helpers

func solid_box(pos: Vector3, size: Vector3, material: Material, safe := true, parent: Node = self) -> StaticBody3D:
	## A box with collision. `safe` marks it as ground the hero may respawn on.
	var body := StaticBody3D.new()
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	if safe:
		body.add_to_group("safe")
	var shape := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = size
	shape.shape = b
	body.add_child(shape)
	if material:
		Models.part(body, Models.box(size), material)
	parent.add_child(body)
	return body


func deco(pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return Models.part(self, Models.box(size), material, pos)


static func window_material(wall: Color, glass: Color, lit: Color, seed_: int) -> StandardMaterial3D:
	## A skyscraper facade: a grid of windows, some lit, tiled in world space.
	var r := RandomNumberGenerator.new()
	r.seed = seed_
	var w := 64
	var h := 64
	var img := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	var emit := Image.create_empty(w, h, false, Image.FORMAT_RGBA8)
	img.fill(wall)
	emit.fill(Color.BLACK)
	for wy in range(4, h, 16):
		for wx in range(4, w, 16):
			var is_lit := r.randf() < 0.35
			img.fill_rect(Rect2i(wx, wy, 9, 11), lit if is_lit else glass)
			if is_lit:
				emit.fill_rect(Rect2i(wx, wy, 9, 11), lit)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.emission_enabled = true
	m.emission_texture = ImageTexture.create_from_image(emit)
	m.emission_energy_multiplier = 0.8
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.125, 0.125, 0.125)  # one texture tile per 8 m
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	m.roughness = 0.45
	m.metallic = 0.2
	return m


# ------------------------------------------------------------------ build

func _environment() -> void:
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.6, 0.98)
	sm.sky_horizon_color = Color(0.82, 0.9, 1.0)
	sm.ground_horizon_color = Color(0.75, 0.82, 0.92)
	sm.ground_bottom_color = Color(0.3, 0.35, 0.45)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.9
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.fog_enabled = true
	env.fog_light_color = Color(0.78, 0.86, 0.98)
	env.fog_density = 0.0025
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-35), 0)
	sun.light_energy = 1.25
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)


func _ground() -> void:
	var road := Models.mat(Color(0.3, 0.31, 0.35), 0.85)
	var pave := Models.mat(Color(0.72, 0.72, 0.75), 0.8)
	var kerb := Models.mat(Color(0.55, 0.55, 0.6), 0.7)
	var line := Models.mat(Color(0.98, 0.95, 0.85), 0.6, 0.0, 0.2)
	var yellow := Models.mat(Color(0.95, 0.75, 0.1), 0.5, 0.0, 0.3)
	var spans := [Vector2(-12, GAP1.x), Vector2(GAP1.y, GAP2.x), Vector2(GAP2.y, ARENA_X0)]
	for sp in spans:
		var len_x: float = sp.y - sp.x
		var cx: float = (sp.x + sp.y) / 2
		solid_box(Vector3(cx, -1, 0), Vector3(len_x, 2, 18), road)
		for side: int in [-1, 1]:
			solid_box(Vector3(cx, -0.9, side * 10.5), Vector3(len_x, 2.2, 3), pave)
			deco(Vector3(cx, 0.21, side * 9.0), Vector3(len_x, 0.06, 0.25), kerb)
		var x: float = sp.x + 2
		while x < sp.y - 3:
			deco(Vector3(x + 1.5, 0.01, 0), Vector3(3, 0.03, 0.25), line)
			x += 6
		# hazard stripes at the broken edges
		for edge in [sp.x, sp.y]:
			if edge > -12 and edge < ARENA_X0:
				var ex: float = edge + (0.4 if edge == sp.x else -0.4)
				for k in 6:
					deco(Vector3(ex, 0.02, -7.5 + k * 3), Vector3(0.6, 0.04, 1.4), yellow)
	# the gaps drop away into a deep construction pit: show girders far below
	var girder := Models.mat(Color(0.75, 0.35, 0.12), 0.6, 0.4)
	for gap in [GAP1, GAP2]:
		for k in 4:
			deco(Vector3((gap.x + gap.y) / 2, -14 - k * 6, -6 + k * 4), Vector3(gap.y - gap.x + 4, 0.6, 0.6), girder)


func _buildings() -> void:
	var mats: Array[StandardMaterial3D] = [
		window_material(Color(0.55, 0.66, 0.8), Color(0.25, 0.35, 0.5), Color(1.0, 0.95, 0.7), 1),
		window_material(Color(0.78, 0.8, 0.84), Color(0.3, 0.4, 0.55), Color(1.0, 0.9, 0.6), 2),
		window_material(Color(0.36, 0.44, 0.6), Color(0.15, 0.22, 0.35), Color(0.9, 0.95, 1.0), 3),
		window_material(Color(0.85, 0.75, 0.62), Color(0.3, 0.35, 0.45), Color(1.0, 0.85, 0.55), 4),
	]
	var roof := Models.mat(Color(0.4, 0.42, 0.46), 0.8)
	var antenna := Models.mat(Color(0.8, 0.82, 0.85), 0.3, 0.7)
	var beacon := Models.mat(Color(1, 0.15, 0.1), 0.3, 0.0, 4.0)
	for side: int in [-1, 1]:
		var x := -14.0
		while x < ARENA_X0 - 2:
			var w := rng.randf_range(12, 22)
			var d := rng.randf_range(14, 22)
			var h := rng.randf_range(18, 78)
			if x + w > ARENA_X0 - 2:
				w = ARENA_X0 - 2 - x
			var z: float = side * (STREET_HALF + 1 + d / 2)
			var cx := x + w / 2
			solid_box(Vector3(cx, (h - 40) / 2, z), Vector3(w, h + 40, d), mats[rng.randi() % mats.size()])
			solid_box(Vector3(cx, h + 0.4, z), Vector3(w - 1.5, 0.8, d - 1.5), roof)
			if rng.randf() < 0.3:
				deco(Vector3(cx, h + 5, z), Vector3(0.3, 9, 0.3), antenna)
				Models.part(self, Models.sphere(0.35), beacon, Vector3(cx, h + 9.6, z))
			if rng.randf() < 0.25 and h < 45:
				pickups.append(["energy", Vector3(cx, h + 1.6, z)])
			x += w + rng.randf_range(0.5, 3.0)


func _props() -> void:
	var shelter := Models.mat(Color(0.2, 0.45, 0.85), 0.4, 0.3)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.7, 0.85, 1.0, 0.35)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var car_cols := [Color(0.85, 0.15, 0.15), Color(0.95, 0.8, 0.15), Color(0.2, 0.55, 0.9), Color(0.95, 0.95, 0.95)]
	var tyre := Models.mat(Color(0.08, 0.08, 0.08), 0.9)
	var window := Models.mat(Color(0.15, 0.22, 0.32), 0.1, 0.3)
	# bus shelters with shooters on the roof
	for sx in [110.0, 205.0]:
		solid_box(Vector3(sx, 3.0, -9.5), Vector3(6, 0.3, 3), shelter)
		for px in [-2.8, 2.8]:
			solid_box(Vector3(sx + px, 1.45, -10.6), Vector3(0.2, 2.9, 0.2), shelter)
		deco(Vector3(sx, 1.5, -10.8), Vector3(5.4, 2.6, 0.08), glass)
		spawns.append(["shooter", Vector3(sx, 3.3, -9.5)])
	# parked cars and a delivery truck to jump on
	var car_spots := [Vector3(30, 0, 6.5), Vector3(52, 0, -6.5), Vector3(100, 0, 6.5), Vector3(125, 0, -6.5),
		Vector3(145, 0, 6), Vector3(215, 0, 6.5), Vector3(240, 0, -6.5)]
	for i in car_spots.size():
		var p: Vector3 = car_spots[i]
		var col: Color = car_cols[i % car_cols.size()]
		var body := Models.mat(col, 0.25, 0.5)
		solid_box(p + Vector3(0, 0.75, 0), Vector3(4.4, 1.0, 2.0), body)
		solid_box(p + Vector3(-0.3, 1.6, 0), Vector3(2.4, 0.8, 1.8), body)
		deco(p + Vector3(-0.3, 1.6, 0), Vector3(2.45, 0.6, 1.85), window)
		for wx in [-1.4, 1.4]:
			for wz in [-1.0, 1.0]:
				Models.part(self, Models.cylinder(0.4, 0.4, 0.3), tyre, p + Vector3(wx, 0.4, wz), Vector3(PI / 2, 0, 0))
	var truck := Models.mat(Color(0.95, 0.95, 0.97), 0.4)
	solid_box(Vector3(132, 2.0, 5.5), Vector3(8, 3.6, 3), truck)
	solid_box(Vector3(137, 1.4, 5.5), Vector3(2.4, 2.4, 2.8), Models.mat(Color(0.85, 0.2, 0.2), 0.3, 0.4))
	spawns.append(["shooter", Vector3(131, 4.0, 5.5)])
	# streetlights
	var pole := Models.mat(Color(0.25, 0.27, 0.3), 0.4, 0.6)
	var lamp := Models.mat(Color(1, 0.95, 0.75), 0.3, 0.0, 3.0)
	var lx := 6.0
	while lx < ARENA_X0:
		if not (lx > GAP1.x - 1 and lx < GAP1.y + 1) and not (lx > GAP2.x - 1 and lx < GAP2.y + 1):
			for side: int in [-1, 1]:
				deco(Vector3(lx, 3.5, side * 11.2), Vector3(0.2, 7, 0.2), pole)
				deco(Vector3(lx, 7.0, side * 10.4), Vector3(0.2, 0.2, 1.8), pole)
				deco(Vector3(lx, 6.85, side * 9.6), Vector3(0.6, 0.15, 0.4), lamp)
		lx += 24
	# robots on the street
	for x in [24.0, 44.0, 60.0, 98.0, 118.0, 140.0, 150.0, 196.0, 214.0, 232.0, 248.0]:
		spawns.append(["walker", Vector3(x, 0.3, rng.randf_range(-6, 6))])
	# pickups (energy also on some rooftops, from _buildings)
	pickups.append(["health", Vector3(64, 1.2, 0)])
	pickups.append(["energy", Vector3(104, 1.2, -3)])
	pickups.append(["health", Vector3(132, 5.0, 5.5)])
	pickups.append(["energy", Vector3(194, 1.2, 0)])
	pickups.append(["health", Vector3(252, 1.2, -3)])
	pickups.append(["energy", Vector3(256, 1.2, 3)])
	# Supercity sign over the street
	var sign := Label3D.new()
	sign.text = "SUPERCITY"
	sign.font_size = 360
	sign.outline_size = 48
	sign.modulate = Color(1, 0.85, 0.2)
	sign.position = Vector3(40, 14, 0)
	sign.rotation.y = -PI / 2
	add_child(sign)
	deco(Vector3(40, 12, 0), Vector3(0.5, 0.5, 24), pole)


func _sky_lifts() -> void:
	var plank := Models.mat(Color(0.9, 0.7, 0.15), 0.4, 0.3)
	var light := Models.mat(Color(1, 1, 0.8), 0.2, 0.0, 3.0)
	var defs := [
		[Vector3(GAP1.x + 3, -0.3, 0), Vector3(GAP1.y - 3, -0.3, 0), 4.5],
		[Vector3(GAP2.x + 3, -0.3, -3), Vector3(GAP2.x + 12, -0.3, -3), 3.5],
		[Vector3(GAP2.x + 15, -0.3, 3), Vector3(GAP2.y - 3, 4.0, 3), 4.0],
	]
	# a girder pillar to rest on halfway across the second gap
	solid_box(Vector3(GAP2.x + 13.5, -0.5, -3), Vector3(3, 1, 3), Models.mat(Color(0.75, 0.35, 0.12), 0.6, 0.4))
	solid_box(Vector3(GAP2.y + 4, 3.5, 3), Vector3(8, 1.0, 6), Models.mat(Color(0.72, 0.72, 0.75), 0.8))
	for i in defs.size():
		var d: Array = defs[i]
		var lift := AnimatableBody3D.new()
		lift.sync_to_physics = true
		lift.collision_layer = 1
		var shape := CollisionShape3D.new()
		var b := BoxShape3D.new()
		b.size = Vector3(5, 0.6, 5)
		shape.shape = b
		lift.add_child(shape)
		Models.part(lift, Models.box(b.size), plank)
		for k in 4:
			Models.part(lift, Models.sphere(0.15, 8), light, Vector3(-1.8 + k * 1.2, 0.32, 2.4))
		lift.position = d[0]
		add_child(lift)
		lifts.append({"body": lift, "a": d[0], "b": d[1], "period": d[2], "phase": i * 1.3})


func _arena() -> void:
	var tiles := StandardMaterial3D.new()
	var img := Image.create_empty(32, 32, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.8, 0.8, 0.82))
	img.fill_rect(Rect2i(0, 0, 16, 16), Color(0.62, 0.64, 0.7))
	img.fill_rect(Rect2i(16, 16, 16, 16), Color(0.62, 0.64, 0.7))
	tiles.albedo_texture = ImageTexture.create_from_image(img)
	tiles.uv1_triplanar = true
	tiles.uv1_world_triplanar = true
	tiles.uv1_scale = Vector3(0.25, 0.25, 0.25)
	tiles.roughness = 0.7
	var w := ARENA_X1 - ARENA_X0
	solid_box(Vector3((ARENA_X0 + ARENA_X1) / 2, -1, 0), Vector3(w, 2, ARENA_HALF_Z * 2), tiles)
	# ring of tall towers around the plaza
	var towers := [window_material(Color(0.6, 0.6, 0.68), Color(0.2, 0.25, 0.38), Color(1, 0.9, 0.6), 7),
		window_material(Color(0.45, 0.55, 0.72), Color(0.18, 0.26, 0.4), Color(0.95, 0.95, 1), 8)]
	for side: int in [-1, 1]:
		solid_box(Vector3((ARENA_X0 + ARENA_X1) / 2, 30, side * (ARENA_HALF_Z + 8)), Vector3(w + 16, 64, 16), towers[0])
	solid_box(Vector3(ARENA_X1 + 8, 30, 0), Vector3(16, 64, ARENA_HALF_Z * 2 + 32), towers[1])
	for side: int in [-1, 1]:  # corners beside the street entrance
		solid_box(Vector3(ARENA_X0 - 0.5, 30, side * (STREET_HALF + 1 + (ARENA_HALF_Z - STREET_HALF) / 2)),
			Vector3(3, 64, ARENA_HALF_Z - STREET_HALF - 2), towers[1])
	# platforms to get above the poo, like the 2D arena's planks
	var plat := Models.mat(Color(0.9, 0.7, 0.15), 0.4, 0.3)
	solid_box(Vector3(280, 3.2, -16), Vector3(8, 0.5, 5), plat)
	solid_box(Vector3(280, 3.2, 16), Vector3(8, 0.5, 5), plat)
	solid_box(Vector3(300, 6.4, 0), Vector3(6, 0.5, 8), plat)
	for p in [Vector3(276.5, 1.6, -16), Vector3(283.5, 1.6, -16), Vector3(276.5, 1.6, 16), Vector3(283.5, 1.6, 16)]:
		deco(p, Vector3(0.3, 3.2, 0.3), Models.mat(Color(0.3, 0.3, 0.35), 0.5, 0.5))
	pickups.append(["health", Vector3(300, 8.0, 0)])
	# fountain in the middle (low, so you can hop on it)
	solid_box(Vector3(292, 0.4, 0), Vector3(7, 0.8, 7), Models.mat(Color(0.85, 0.85, 0.88), 0.6))
	var water := Models.mat(Color(0.3, 0.6, 0.95), 0.05, 0.0, 0.3)
	deco(Vector3(292, 0.82, 0), Vector3(6, 0.05, 6), water)
	# the gate: invisible until the fight starts
	gate = solid_box(Vector3(GATE_X - 4, 30, 0), Vector3(1, 64, STREET_HALF * 2), null, false)
	var barrier := StandardMaterial3D.new()
	barrier.albedo_color = Color(0.4, 0.8, 1.0, 0.35)
	barrier.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	barrier.emission_enabled = true
	barrier.emission = Color(0.3, 0.7, 1.0)
	barrier.emission_energy_multiplier = 1.5
	barrier.cull_mode = BaseMaterial3D.CULL_DISABLED
	Models.part(gate, Models.box(Vector3(0.3, 64, STREET_HALF * 2)), barrier)
	gate.visible = false
	(gate.get_child(0) as CollisionShape3D).disabled = true
	# a lid over the arena so you can't fly out of the fight
	var lid := solid_box(Vector3((ARENA_X0 + ARENA_X1) / 2, 64, 0), Vector3(w + 40, 1, ARENA_HALF_Z * 2 + 40), null, false)
	arena_walls.append(lid.get_child(0) as CollisionShape3D)
	(lid.get_child(0) as CollisionShape3D).disabled = true


func _bounds() -> void:
	# invisible walls well outside the street so flying heroes can't leave the city
	var ends := [[Vector3(-30, 60, 0), Vector3(2, 200, 300)], [Vector3(345, 60, 0), Vector3(2, 200, 300)],
		[Vector3(160, 60, -95), Vector3(400, 200, 2)], [Vector3(160, 60, 95), Vector3(400, 200, 2)],
		[Vector3(160, 101, 0), Vector3(400, 2, 200)]]
	for e in ends:
		solid_box(e[0], e[1], null, false)


func close_gate() -> void:
	gate.visible = true
	(gate.get_child(0) as CollisionShape3D).disabled = false
	for w in arena_walls:
		w.disabled = false


func tick_lifts(dt: float) -> void:
	t += dt
	for l in lifts:
		var k: float = 0.5 - 0.5 * cos(TAU * (t + l["phase"]) / l["period"])
		(l["body"] as AnimatableBody3D).global_position = (l["a"] as Vector3).lerp(l["b"], k)


func progress(x: float) -> float:
	return clamp(x / GATE_X, 0.0, 1.0)


func in_arena(p: Vector3) -> bool:
	return p.x > GATE_X and p.x < ARENA_X1 and abs(p.z) < ARENA_HALF_Z
