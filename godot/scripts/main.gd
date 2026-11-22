extends Node3D
## SpiderVenomn 3D: pick a hero (Venom, Spider-Man, Jamie's Dad, Jamie, Charley, the Hacker or
## Santa) and save Supercity from Mr Poo.
## Owns the level, the hero, enemies, projectiles and effects, and runs the game states.

var audio: GameAudio
var level: LevelSupercity
var world: Node3D
const HEROES := ["venom", "spiderman", "jamiesdad", "jamie", "charley", "hacker", "santa"]

var player: Hero
var hero_id := "venom"
var rig: CameraRig
var hud: Hud
var boss: MrPoo
var enemies: Array = []
var projectiles: Array = []
var puddles: Array = []     # {node, pos, radius, life}
var waves: Array = []       # expanding ground shockwaves from an angry Mr Poo
var pickups: Array = []     # {node, kind, pos}
var particles: Array = []
var popups: Array = []
var reindeer: Array = []    # Santa's reindeer charging about
var state := "title"        # title | select | play | paused | won | lost
var state_t := 0.0
var finished := ""
var gate_closed := false
var intro_t := 0.0
var score := 0
var t := 0.0
var banner_text := ""
var banner_t := 0.0
var bot = null              # the selftest drives the hero when set
var headless := false


func _ready() -> void:
	Controls.setup_input_map()
	var args := OS.get_cmdline_user_args()
	headless = DisplayServer.get_name() == "headless"
	audio = GameAudio.new(not headless and not args.has("--mute"))
	add_child(audio)
	var hud_layer := CanvasLayer.new()
	add_child(hud_layer)
	hud = Hud.new()
	hud.game = self
	hud_layer.add_child(hud)
	new_game()
	if args.has("--selftest"):
		var script: GDScript = load("res://scripts/selftest.gd")
		if script == null or not script.can_instantiate():
			printerr("selftest failed to load")
			get_tree().quit(1)
			return
		var st: Node = script.new()
		st.game = self
		add_child(st)
	else:
		audio.prepare(["supercity", "boss"])
		audio.music("menu")


func new_game() -> void:
	if world:
		world.queue_free()
	enemies.clear()
	projectiles.clear()
	puddles.clear()
	waves.clear()
	pickups.clear()
	particles.clear()
	popups.clear()
	reindeer.clear()
	world = Node3D.new()
	add_child(world)
	level = LevelSupercity.new()
	world.add_child(level)
	rig = CameraRig.new()
	world.add_child(rig)
	_spawn_player()
	for s in level.spawns:
		spawn_enemy(s[0], s[1])
	for p in level.pickups:
		_add_pickup(p[0], p[1])
	boss = MrPoo.new(self)
	boss.position = level.boss_pos
	world.add_child(boss)
	rig.follow(0.0, true)
	gate_closed = false
	finished = ""
	score = 0
	t = 0.0
	state_t = 0.0
	if state != "title":
		start_play()


static func make_hero(id: String, g) -> Hero:
	match id:
		"spiderman":
			return Spiderman.new(g)
		"jamiesdad":
			return JamiesDad.new(g)
		"jamie":
			return Jamie.new(g)
		"charley":
			return Charley.new(g)
		"hacker":
			return Hacker.new(g)
		"santa":
			return Santa.new(g)
	return Venom.new(g)


func _spawn_player() -> void:
	## (Re)build the chosen hero at the start of the street, and fit the camera to his size.
	if player and is_instance_valid(player):
		player.queue_free()
	player = make_hero(hero_id, self)
	player.position = level.start
	world.add_child(player)
	rig.target = player
	rig.exclude(player)
	player.rig = rig
	_camera_for_play()


func _camera_for_play() -> void:
	rig.height = 2.0 * player.size
	rig.shoulder = 1.0 * player.size
	rig.arm.spring_length = 6.5 * player.size
	rig.yaw = -PI / 2
	rig.pitch = -0.18


func _camera_for_select() -> void:
	## Look at the hero from the front, with him off to the right of the menu text.
	rig.height = 1.55 * player.size
	rig.shoulder = -1.6 * player.size
	rig.arm.spring_length = 4.6 * player.size
	rig.face_dir(Vector3.LEFT)
	rig.pitch = -0.08


func open_select() -> void:
	state = "select"
	_camera_for_select()
	rig.follow(0.0, true)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func choose_hero(step: int) -> void:
	var i := (HEROES.find(hero_id) + step + HEROES.size()) % HEROES.size()
	hero_id = HEROES[i]
	_spawn_player()
	_camera_for_select()
	rig.follow(0.0, true)
	audio.play("select")


func start_play() -> void:
	_camera_for_play()
	state = "play"
	banner("SUPERCITY", 2.2)
	audio.music("supercity")
	if not headless and bot == null:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


# ------------------------------------------------------------------ spawning and helpers

func spawn_enemy(kind: String, pos: Vector3) -> Enemy:
	var e := Enemy.new(self, kind)
	e.position = pos
	e.dir = Vector3.LEFT if kind != "shooter" else Vector3.LEFT
	world.add_child(e)
	enemies.append(e)
	return e


func spawn_projectile(pos: Vector3, v: Vector3, side: String, kind: String, dmg: float, r: float,
		opts := {}) -> Projectile:
	var p := Projectile.new()
	world.add_child(p)
	p.setup(self, pos, v, side, kind, dmg, r, opts)
	projectiles.append(p)
	return p


func targets() -> Array:
	var out: Array = []
	for e in enemies:
		if is_instance_valid(e) and not e.dead and e.hacked_t <= 0.0:  # hacked robots are on your side
			out.append(e)
	if boss and boss.active and not boss.dead:
		out.append(boss)
	return out


func _add_pickup(kind: String, pos: Vector3) -> void:
	var n := Node3D.new()
	n.position = pos
	var colour := Color(0.95, 0.15, 0.2) if kind == "health" else Color(0.3, 0.75, 1.0)
	Models.part(n, Models.sphere(0.5), Models.mat(Color(1, 1, 1, 1), 0.2, 0.0, 0.5))
	if kind == "health":
		var red := Models.mat(colour, 0.3, 0.0, 1.5)
		Models.part(n, Models.box(Vector3(0.22, 0.7, 0.3)), red)
		Models.part(n, Models.box(Vector3(0.7, 0.22, 0.3)), red)
	else:
		var blue := Models.mat(colour, 0.3, 0.0, 2.0)
		Models.part(n, Models.box(Vector3(0.18, 0.5, 0.3)), blue, Vector3(0.08, 0.18, 0), Vector3(0, 0, -0.5))
		Models.part(n, Models.box(Vector3(0.18, 0.5, 0.3)), blue, Vector3(-0.08, -0.18, 0), Vector3(0, 0, -0.5))
	world.add_child(n)
	pickups.append({"node": n, "kind": kind, "pos": pos})


func add_puddle(pos: Vector3) -> void:
	var q := PhysicsRayQueryParameters3D.create(pos + Vector3.UP, pos + Vector3.DOWN * 3.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit:
		return
	var p: Vector3 = hit.position
	var n := Node3D.new()
	n.position = p + Vector3.UP * 0.03
	Models.part(n, Models.cylinder(2.2, 2.2, 0.06, 20), Models.mat(Color(0.4, 0.25, 0.1), 0.15))
	Models.part(n, Models.cylinder(1.3, 1.3, 0.08, 16), Models.mat(Color(0.55, 0.36, 0.17), 0.1), Vector3(0.3, 0.01, -0.2))
	world.add_child(n)
	puddles.append({"node": n, "pos": p, "radius": 2.2, "life": 6.0})


func in_puddle(body: Node3D) -> bool:
	for p in puddles:
		var d: Vector3 = body.global_position - p["pos"]
		if Vector2(d.x, d.z).length() < p["radius"] and abs(d.y) < 0.6:
			return true
	return false


func ground_wave(pos: Vector3, max_r: float, speed: float) -> void:
	## A ring of muck racing out across the ground. Jump over it!
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.8
	torus.outer_radius = 1.0
	n.mesh = torus
	n.material_override = Models.mat(Color(0.5, 0.32, 0.12), 0.4, 0.0, 0.3)
	n.position = pos + Vector3.UP * 0.2
	world.add_child(n)
	waves.append({"node": n, "pos": pos, "r": 1.0, "max": max_r, "speed": speed, "hit": false})


func burst(pos: Vector3, colour: Color, n: int, speed := 6.0) -> void:
	if particles.size() > 300:
		return
	var m := Models.mat(colour, 0.5)
	for i in n:
		var mi := MeshInstance3D.new()
		mi.mesh = Models.box(Vector3.ONE * 0.16)
		mi.material_override = m
		mi.position = pos
		world.add_child(mi)
		var v := Vector3(randf_range(-1, 1), randf_range(-0.2, 1.2), randf_range(-1, 1)).normalized() * randf_range(0.3, 1.0) * speed
		var life := randf_range(0.35, 0.8)
		particles.append({"node": mi, "vel": v, "life": life, "max": life})


func popup(pos: Vector3, text: String, colour: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 72
	l.outline_size = 14
	l.modulate = colour
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.008
	l.position = pos
	world.add_child(l)
	popups.append({"node": l, "life": 0.9})


func shake(amount: float) -> void:
	rig.shake = max(rig.shake, amount)


func banner(text: String, secs := 2.0) -> void:
	banner_text = text
	banner_t = secs


func symbiote_blast(at: Vector3) -> void:
	## Venom's ultimate: symbiotes explode everywhere, wiping out every robot nearby.
	for e in targets():
		if e == boss:
			continue
		if e.center().distance_to(at) < 45.0:
			e.hurt(e.hp, e.center() - at, 14.0)
	if boss and boss.active and not boss.dead and boss.center().distance_to(at) < 45.0:
		boss.hurt(boss.max_hp * 0.2, Vector3.ZERO)
	for i in 24:
		var a := i * TAU / 24.0
		var dir := Vector3(cos(a), 0.15 * sin(a * 3.0), sin(a))
		spawn_projectile(at + dir * 1.5, dir * 30.0, "player", "symbiote", 15.0, 0.45, {"life": 1.0, "pierce": true})
	burst(at, Color(0.05, 0.05, 0.08), 60, 18.0)
	ground_wave_fx(at)
	audio.play("roar")
	audio.play("explode")
	shake(1.0)
	banner("SYMBIOTE BLAST!", 1.2)


func web_storm(at: Vector3) -> void:
	## Spider-Man's ultimate: webs fly everywhere, wrapping up every robot nearby.
	for e in targets():
		if e.center().distance_to(at) >= 45.0:
			continue
		if e == boss:
			boss.hurt(boss.max_hp * 0.15, Vector3.ZERO)
			if not boss.dead:
				boss.web(8.0)
		else:
			e.hurt(18.0, e.center() - at, 4.0)
			if is_instance_valid(e) and not e.dead:
				e.web(7.0)
	for i in 32:
		var a := i * TAU / 32.0
		var dir := Vector3(cos(a), 0.35 * sin(a * 3.0) + 0.1, sin(a))
		spawn_projectile(at + dir * 1.0, dir * 38.0, "player", "web", 8.0, 0.35,
			{"life": 1.0, "pierce": true, "web": 7.0})
	burst(at, Color(0.95, 0.95, 1.0), 60, 18.0)
	audio.play("web")
	audio.play("explode")
	shake(0.7)
	banner("WEB STORM!", 1.2)


func ground_wave_fx(at: Vector3, colour := Models.VENOM_BLACK, max_r := 40.0, spd := 60.0) -> void:
	## A harmless (to the hero) ring racing out across the ground.
	var n := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.7
	torus.outer_radius = 1.0
	n.mesh = torus
	n.material_override = Models.mat(colour, 0.2, 0.3, 0.3, 0.8)
	n.position = at
	world.add_child(n)
	waves.append({"node": n, "pos": at, "r": 1.0, "max": max_r, "speed": spd, "hit": true})


func shockwave(at: Vector3, r: float, dmg: float) -> void:
	## Jamie's Dad's ground-pound: everything close by gets smashed and thrown back.
	for e in targets():
		var d: Vector3 = e.center() - at
		if Vector2(d.x, d.z).length() < r + e.radius and abs(d.y) < 4.0:
			e.hurt(dmg * (0.6 if e == boss else 1.0), d, 16.0)
	burst(at + Vector3.UP * 0.3, Color(0.75, 0.7, 0.6), 30, 10.0)
	ground_wave_fx(at + Vector3.UP * 0.2, Color(0.95, 0.85, 0.6), r, 40.0)
	audio.play("explode")
	shake(0.6)


func dad_smash(at: Vector3) -> void:
	## Jamie's Dad's ultimate: he leaps and punches the ground so hard every robot nearby is
	## knocked out, and Mr Poo loses a quarter of his health.
	for e in targets():
		if e == boss:
			continue
		if e.center().distance_to(at) < 45.0:
			e.hurt(e.hp, e.center() - at, 22.0)
	if boss and boss.active and not boss.dead and boss.center().distance_to(at) < 45.0:
		boss.hurt(boss.max_hp * 0.25, Vector3.ZERO)
	for k in 3:
		ground_wave_fx(at + Vector3.UP * (0.2 + k * 0.4), Color(1, 0.8, 0.35), 45.0, 45.0 + k * 15.0)
	burst(at, Color(0.8, 0.72, 0.6), 70, 20.0)
	audio.play("explode")
	audio.play("roar")
	shake(1.3)
	banner("DAD SMASH!", 1.3)


func genius_hack(at: Vector3) -> void:
	## Jamie's ultimate: he hacks every robot nearby so they shut down and blow up, and
	## scrambles Mr Poo's brain so he freezes for a few seconds.
	for e in targets():
		if e == boss or e.center().distance_to(at) >= 45.0:
			continue
		popup(e.center() + Vector3.UP * 1.5, "HACKED!", Color(0.3, 1.0, 0.6))
		e.hurt(e.hp, Vector3.ZERO, 0.0)
	if boss and boss.active and not boss.dead and boss.center().distance_to(at) < 45.0:
		popup(boss.center() + Vector3.UP * 4.0, "HACKED!", Color(0.3, 1.0, 0.6))
		boss.hurt(boss.max_hp * 0.2, Vector3.ZERO)
		if not boss.dead:
			boss.daze(3.0)
	for k in 3:
		ground_wave_fx(at + Vector3.UP * (0.5 + k * 1.2), Color(0.2, 1.0, 0.55), 45.0, 40.0 + k * 10.0)
	burst(at, Color(0.3, 1.0, 0.6), 50, 14.0)
	audio.play("hack")
	audio.play("explode")
	shake(0.8)
	banner("GENIUS HACK!", 1.3)


func system_hack(at: Vector3) -> void:
	## The Hacker's ultimate: every robot nearby is hacked onto your side at once, the
	## mini-poos get deleted, and Mr Poo crashes.
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dead or e.center().distance_to(at) >= 45.0:
			continue
		if e.hackable():
			e.hack(15.0)
		else:
			popup(e.center() + Vector3.UP * 1.5, "DELETED", Color(0.3, 1.0, 0.5))
			e.hurt(e.hp, Vector3.ZERO, 0.0)
	if boss and boss.active and not boss.dead and boss.center().distance_to(at) < 45.0:
		popup(boss.center() + Vector3.UP * 4.5, "MR_POO.EXE HAS STOPPED WORKING", Color(1, 0.4, 0.4))
		boss.hurt(boss.max_hp * 0.15, Vector3.ZERO)
		if not boss.dead:
			boss.daze(4.0)
	for k in 2:
		ground_wave_fx(at + Vector3.UP * (0.4 + k), Models.HACK_GREEN, 45.0, 50.0 + k * 10.0)
	burst(at, Models.HACK_GREEN, 50, 14.0)
	audio.play("hack")
	audio.play("glitch")
	shake(0.6)
	banner("SYSTEM HACKED!", 1.4)


func spawn_reindeer(from: Vector3, tgt, at: Vector3, dmg: float, boss_dmg: float, deer_name := "",
		rudolph := false) -> Reindeer:
	var r := Reindeer.new()
	world.add_child(r)
	r.setup(self, from, tgt, at, dmg, boss_dmg, deer_name, rudolph)
	reindeer.append(r)
	return r


func reindeer_stampede(santa: Hero) -> void:
	## Santa's ultimate: all nine reindeer gallop in, one for every robot nearby (and the
	## rest go for Mr Poo). Every robot is knocked out.
	var at := santa.center()
	var foes: Array = []
	for e in targets():
		if e != boss and e.center().distance_to(at) < 45.0:
			foes.append(e)
	var boss_near: bool = boss and boss.active and not boss.dead and boss.center().distance_to(at) < 45.0
	var n: int = max(9, min(foes.size(), 16))
	var back := Vector3(sin(santa.face_yaw), 0, cos(santa.face_yaw))
	var side := back.cross(Vector3.UP)
	for i in n:
		var tgt = null
		if i < foes.size():
			tgt = foes[i]
		elif boss_near:
			tgt = boss
		var goal: Vector3 = santa.global_position - back * 30.0 + side * (i - n / 2.0) * 3.0
		var start := santa.global_position + back * 8.0 + side * (i - n / 2.0) * 2.5 + Vector3.UP * (8.0 + (i % 3) * 2.0)
		var deer_name: String = Santa.NAMES[i % 9]
		spawn_reindeer(start, tgt, goal, 999.0, 16.0, deer_name, deer_name == "RUDOLPH")
	audio.play("bells")
	audio.play("hohoho")
	shake(0.6)
	banner("REINDEER STAMPEDE!", 1.6)


func beam(a: Vector3, b: Vector3, colour: Color) -> void:
	## A quick zig-zag line of electricity from a to b.
	var n := Node3D.new()
	n.position = a  # the fx loop shrinks it towards here as it fades
	world.add_child(n)
	var m := Models.mat(colour, 0.2, 0.0, 4.0)
	var steps := 6
	var prev := a
	var side := (b - a).cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	for i in steps:
		var f := float(i + 1) / steps
		var p := a.lerp(b, f)
		if i < steps - 1:
			p += side * randf_range(-0.35, 0.35) + Vector3.UP * randf_range(-0.3, 0.3)
		var seg := Models.part(n, Models.cylinder(0.04, 0.04, 1.0, 5), m)
		var dir := p - prev
		seg.position = (prev + p) * 0.5 - a
		if dir.length() > 0.01:
			seg.basis = Basis(Quaternion(Vector3.UP, dir.normalized())) * Basis.from_scale(Vector3(1, dir.length(), 1))
		prev = p
	particles.append({"node": n, "vel": Vector3.ZERO, "life": 0.18, "max": 0.18})


func streak(pos: Vector3, dir: Vector3) -> void:
	## A white speed line, left hanging in the air behind a super-sprint.
	if particles.size() > 300:
		return
	var mi := MeshInstance3D.new()
	mi.mesh = Models.box(Vector3(0.06, 0.06, 1.8))
	mi.material_override = Models.mat(Color(1, 1, 1), 0.3, 0.0, 1.5)
	mi.position = pos
	world.add_child(mi)
	mi.look_at(pos + dir, Vector3.UP)
	particles.append({"node": mi, "vel": Vector3(0, 0.1, 0), "life": 0.25, "max": 0.25})


func boss_defeated(b: MrPoo) -> void:
	for i in 6:
		burst(b.center() + Vector3(randf_range(-2, 2), randf_range(-2, 2), randf_range(-2, 2)), Color(1, 0.8, 0.3), 20, 12.0)
	b.queue_free()
	audio.play("explode")
	audio.play("win")
	audio.music("")
	shake(1.0)
	score += 5000
	banner("MR POO DEFEATED!", 3.0)
	state = "won"
	state_t = 3.2
	player.invuln = 99.0


# ------------------------------------------------------------------ main loop

func _unhandled_input(event: InputEvent) -> void:
	if bot != null:
		return
	if event.is_action_pressed("fullscreen"):
		var full := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif event.is_action_pressed("music"):
		audio.toggle_music()
	match state:
		"title":
			if event is InputEventMouseButton and event.pressed or event is InputEventKey and event.pressed \
					and not event.is_action("pause"):
				audio.play("select")
				open_select()
			elif event.is_action_pressed("pause"):
				get_tree().quit()
		"select":
			if event.is_action_pressed("move_left"):
				choose_hero(-1)
			elif event.is_action_pressed("move_right"):
				choose_hero(1)
			elif event is InputEventKey and event.pressed and event.physical_keycode >= KEY_1 \
					and event.physical_keycode < KEY_1 + HEROES.size():
				var want: String = HEROES[event.physical_keycode - KEY_1]
				if want != hero_id:
					choose_hero(HEROES.find(want) - HEROES.find(hero_id))
			elif event.is_action_pressed("jump") or event is InputEventMouseButton and event.pressed \
					and event.button_index == MOUSE_BUTTON_LEFT \
					or event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER:
				audio.play("select")
				start_play()
			elif event.is_action_pressed("pause"):
				state = "title"
		"play":
			if event.is_action_pressed("pause"):
				state = "paused"
				Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			elif event is InputEventMouseButton and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		"paused":
			if event.is_action_pressed("pause") or event is InputEventMouseButton and event.pressed:
				state = "play"
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			elif event.is_action_pressed("restart"):
				state = "play"
				new_game()
			elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
				state = "title"
				new_game()
				open_select()
			elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_Q:
				get_tree().quit()
		"won", "lost":
			if finished != "" and (event.is_action_pressed("jump") or event.is_action_pressed("restart")
					or event is InputEventKey and event.pressed and event.physical_keycode == KEY_ENTER):
				state = "play"
				new_game()
			elif finished != "" and event is InputEventKey and event.pressed and event.physical_keycode == KEY_H:
				state = "title"
				new_game()
				open_select()
			elif finished != "" and event.is_action_pressed("pause"):
				get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and state == "play" and bot == null:
		state = "paused"
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(dt: float) -> void:
	if state == "select":  # let the chosen hero stand and breathe
		var idle := Controls.new()
		idle.aim_override = player.global_position + Vector3(10, 1, 0)
		player.tick(idle, dt)
		return
	if state == "title" or state == "paused":
		level.tick_lifts(0.0)
		return
	t += dt
	banner_t = max(0.0, banner_t - dt)
	level.tick_lifts(dt)
	var ctl: Controls
	if state == "play":
		ctl = bot.controls() if bot != null else Controls.from_input()
	else:
		ctl = Controls.new()
		ctl.aim_override = player.aim
	player.tick(ctl, dt)
	if state != "play":
		state_t -= dt
		if state_t <= 0.0 and finished == "":
			finished = state

	_update_arena(dt)
	var pp := player.global_position
	for e in enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			enemies.erase(e)
		elif abs(e.global_position.x - pp.x) < 70.0:
			e.tick(dt)
	if boss and is_instance_valid(boss) and not boss.dead:
		boss.tick(dt)
	for p in projectiles.duplicate():
		if not is_instance_valid(p) or p.dead:
			projectiles.erase(p)
		else:
			p.tick(dt)
	for r in reindeer.duplicate():
		if not is_instance_valid(r) or r.is_queued_for_deletion():
			reindeer.erase(r)
		else:
			r.tick(dt)
	_update_hazards(dt)
	_contact_damage()
	_update_pickups(dt)
	_update_fx(dt)

	if player.dead and state == "play":
		state = "lost"
		state_t = 2.2
		audio.music("")
		audio.play("lose")
		burst(player.center(), Color(1, 0.3, 0.3), 30, 8.0)
		banner("DEFEATED!", 3.0)


func _process(dt: float) -> void:
	rig.follow(dt)
	player.camera_close = rig.arm.get_hit_length() < 1.8 * player.size and state != "select"


func _update_arena(dt: float) -> void:
	if not boss or not is_instance_valid(boss):
		return
	if gate_closed:
		if not boss.active and not boss.dead:
			intro_t -= dt
			if intro_t <= 0.0:
				boss.active = true
		return
	if level.in_arena(player.global_position) and player.global_position.x > LevelSupercity.GATE_X + 4.0:
		gate_closed = true
		level.close_gate()
		intro_t = 2.0
		banner("BOSS: MR POO", 2.0)
		audio.play("roar")
		audio.music("boss")
		shake(0.6)


func _update_hazards(dt: float) -> void:
	for p in puddles.duplicate():
		p["life"] -= dt
		if p["life"] <= 0.0:
			(p["node"] as Node3D).queue_free()
			puddles.erase(p)
		elif p["life"] < 1.0:
			(p["node"] as Node3D).scale = Vector3(p["life"], 1, p["life"])
	for w in waves.duplicate():
		w["r"] += w["speed"] * dt
		var n: Node3D = w["node"]
		n.scale = Vector3(w["r"], 1.0 + w["r"] * 0.05, w["r"])
		if not w["hit"]:
			var d: Vector3 = player.global_position - w["pos"]
			var flat := Vector2(d.x, d.z).length()
			if abs(flat - w["r"]) < 1.2 and d.y < 1.0:
				w["hit"] = true
				player.take_damage(14.0, w["pos"], 10.0)
		if w["r"] >= w["max"]:
			n.queue_free()
			waves.erase(w)


func _contact_damage() -> void:
	if player.dead or state != "play" or player.hiding:
		return
	var pc := player.center()
	var feet := player.global_position
	var hits: Array = targets()
	for e in hits:
		var ec: Vector3 = e.center()
		var flat := Vector2(pc.x - ec.x, pc.z - ec.z).length()
		var top: float = e.global_position.y + e.height
		if flat > e.radius + 0.5 + player.radius * 0.5 or feet.y > top + 0.2 or pc.y + 1.2 * player.size < e.global_position.y:
			continue
		if player.rams():  # super-sprint: whatever he runs into gets flattened
			if player.ram_cd <= 0.0:
				var push := Vector3(player.velocity.x, 0, player.velocity.z).normalized()
				e.hurt(30.0 if e == boss else e.hp + 1.0, push + Vector3.UP * 0.4, 22.0)
				audio.play("hit")
				shake(0.3)
				if e == boss:  # bounces off the big lad
					player.velocity = -push * 14.0 + Vector3.UP * 7.0
					player.ram_cd = 0.4
			continue
		if player.velocity.y < -3.0 and feet.y > top - 0.7:
			e.hurt(15.0 if e == boss else 25.0, Vector3.ZERO, 0.0)
			player.velocity.y = 16.0 if e == boss else 13.0
			audio.play("hit")
		else:
			player.take_damage(e.contact, ec, 11.0 if e == boss else 8.0)


func _update_pickups(dt: float) -> void:
	for p in pickups.duplicate():
		var n: Node3D = p["node"]
		n.rotation.y += dt * 2.5
		n.position.y = p["pos"].y + sin(t * 3.0 + p["pos"].x) * 0.2
		if n.global_position.distance_to(player.center()) < 1.6:
			audio.play("pickup")
			if p["kind"] == "health":
				player.heal(45.0)
				popup(n.global_position + Vector3.UP, "+HP", Color(0.5, 1, 0.5))
			else:
				player.energy = 100.0
				popup(n.global_position + Vector3.UP, "+ENERGY", Color(0.5, 0.8, 1))
			n.queue_free()
			pickups.erase(p)


func _update_fx(dt: float) -> void:
	for p in particles.duplicate():
		p["life"] -= dt
		var n: Node3D = p["node"]
		if p["life"] <= 0.0:
			n.queue_free()
			particles.erase(p)
			continue
		p["vel"].y -= 18.0 * dt
		n.position += p["vel"] * dt
		n.scale = Vector3.ONE * (p["life"] / p["max"])
	for p in popups.duplicate():
		p["life"] -= dt
		var l: Label3D = p["node"]
		if p["life"] <= 0.0:
			l.queue_free()
			popups.erase(p)
			continue
		l.position.y += 1.6 * dt
		l.modulate.a = min(1.0, p["life"] * 2.0)
