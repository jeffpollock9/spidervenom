extends Node
## Headless smoke test: drives Venom with a bot and checks every power, the sky-lifts,
## falling, the boss fight, winning and losing. Run with:
##   godot --headless --fixed-fps 60 --path godot -- --selftest
## Add `--shots DIR` (and drop --headless) to also save screenshots.

var game
var cur := Controls.new()
var failures: Array[String] = []
var shots_dir := ""


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var i := args.find("--shots")
	if i >= 0 and i + 1 < args.size() and not game.headless:
		shots_dir = args[i + 1]
		DirAccess.make_dir_recursive_absolute(shots_dir)
		RenderingServer.render_loop_enabled = false  # only render the frames we photograph
	game.bot = self
	run.call_deferred()


func controls() -> Controls:
	var c := cur
	var n := Controls.new()  # "pressed" lasts one frame, "held" carries on
	n.move = c.move
	n.jump_held = c.jump_held
	n.down_held = c.down_held
	n.alt_held = c.alt_held
	n.aim_override = c.aim_override
	cur = n
	return c


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func check(ok: bool, what: String) -> void:
	print(("  ok    " if ok else "  FAIL  ") + what)
	if not ok:
		failures.append(what)


func shot(name: String) -> void:
	if shots_dir == "":
		return
	RenderingServer.render_loop_enabled = true
	for i in 3:
		await RenderingServer.frame_post_draw
	game.get_viewport().get_texture().get_image().save_png(shots_dir.path_join(name + ".png"))
	RenderingServer.render_loop_enabled = false


func fresh() -> Venom:
	game.state = "play"
	game.new_game()
	cur = Controls.new()
	await frames(20)  # let him land after spawning
	var p: Venom = game.player
	game.rig.face_dir(Vector3.RIGHT)
	return p


func clear_enemies() -> void:
	for e in game.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()


func run() -> void:
	var t0 := Time.get_ticks_msec()
	if shots_dir != "":
		game.state = "title"
		await frames(10)
		await shot("title")

	# --- running and jumping
	var p := await fresh()
	clear_enemies()
	var x0 := p.global_position.x
	cur.move = Vector2(0, 1)
	await frames(60)
	check(p.global_position.x - x0 > 6.0, "Venom runs forward (%.1f m)" % (p.global_position.x - x0))
	cur.jump_pressed = true
	cur.jump_held = true
	var y0 := p.global_position.y
	var top := y0
	for i in 25:
		await frames(1)
		top = max(top, p.global_position.y)
	check(top - y0 > 1.8, "Venom jumps (%.1f m)" % (top - y0))
	cur = Controls.new()
	await frames(40)
	await shot("start")

	# --- heavy punch
	p = await fresh()
	clear_enemies()
	var foe: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(2.2, 0.3, 0))
	await frames(3)
	cur.aim_override = foe.center()
	cur.primary_pressed = true
	await frames(2)
	check(foe.hp < foe.max_hp, "punch hurts a robot (hp %d/%d)" % [foe.hp, foe.max_hp])
	for f in 120:  # chase it down and punch again
		if not is_instance_valid(foe) or foe.dead:
			break
		cur.aim_override = foe.center()
		var gap := foe.global_position - p.global_position
		game.rig.face_dir(Vector3(gap.x, 0, gap.z).normalized())
		cur.move = Vector2(0, 1) if Vector2(gap.x, gap.z).length() > 2.5 else Vector2.ZERO
		cur.primary_pressed = Vector2(gap.x, gap.z).length() < 3.0 and p.cd <= 0.0
		await frames(1)
	check(not is_instance_valid(foe) or foe.dead, "two punches finish a robot")
	cur = Controls.new()
	await frames(30)

	# --- symbiote blast
	clear_enemies()
	foe = game.spawn_enemy("shooter", p.global_position + Vector3(12, 0.3, 0))
	await frames(3)
	cur.aim_override = foe.center()
	cur.special_pressed = true
	await frames(30)
	check(not is_instance_valid(foe) or foe.hp < foe.max_hp, "symbiote blast hits a robot")
	cur = Controls.new()

	# --- tendril swing off a skyscraper
	p = await fresh()
	clear_enemies()
	cur.aim_override = p.global_position + Vector3(10, 28, -14)
	cur.alt_pressed = true
	cur.alt_held = true
	await frames(2)
	check(p.swinging and p.anchor.y > 10.0, "Venom swings on a tendril (anchor %s)" % [p.anchor])
	cur.move = Vector2(0, 1)
	var max_speed := 0.0
	var swung := 0
	var high := 0.0
	for i in 50:
		await frames(1)
		max_speed = max(max_speed, p.velocity.length())
		high = max(high, p.global_position.y)
		swung += int(p.swinging)
		if i == 30:
			await shot("swing")
	check(swung > 40 and high > 3.0, "the tendril lifts Venom off the street (%d frames, %.1f m up)" % [swung, high])
	check(max_speed > 10.0, "swinging builds speed (%.1f m/s)" % max_speed)
	cur = Controls.new()
	await frames(2)
	check(not p.swinging, "letting go of SHIFT drops the tendril")

	# --- flying on symbiote wings
	p = await fresh()
	clear_enemies()
	cur.jump_pressed = true
	cur.jump_held = true
	await frames(15)
	cur.jump_pressed = true
	await frames(2)
	check(p.flying, "jump in mid-air opens the wings")
	y0 = p.global_position.y
	cur.move = Vector2(0, 1)
	await frames(90)
	check(p.global_position.y - y0 > 8.0, "flying climbs (%.1f m)" % (p.global_position.y - y0))
	check(p.wing_open > 0.9, "wings are spread")
	await shot("fly")
	cur.jump_held = false
	cur.move = Vector2.ZERO
	cur.down_held = true
	await frames(240)
	check(not p.flying and p.is_on_floor(), "flying down lands and folds the wings")

	# --- the sky-lift carries you over the first gap
	p = await fresh()
	clear_enemies()
	var lift: AnimatableBody3D = game.level.lifts[0]["body"]
	p.global_position = lift.global_position + Vector3(0, 1.0, 0)
	p.velocity = Vector3.ZERO
	await frames(10)
	var lx := lift.global_position.x
	var px := p.global_position.x
	await frames(60)
	check(abs((p.global_position.x - px) - (lift.global_position.x - lx)) < 0.5 and p.is_on_floor(),
		"sky-lift carries Venom (lift moved %.1f m, Venom %.1f m)" % [lift.global_position.x - lx, p.global_position.x - px])

	# --- falling into the pit puts you back with a penalty
	p = await fresh()
	clear_enemies()
	await frames(5)
	var safe := p.safe_pos
	var hp0 := p.hp
	p.global_position = Vector3(81, 3, 5)
	await frames(120)
	check(p.hp == hp0 - 15.0 and p.global_position.distance_to(safe) < 3.0, "falling into the pit respawns (-15 hp)")

	# --- fly the whole street to the boss arena (proves the level can be finished)
	p = await fresh()
	p.hp = 1e6
	cur.jump_pressed = true
	cur.jump_held = true
	await frames(15)
	cur.jump_pressed = true
	await frames(60)
	cur.jump_held = false
	cur.move = Vector2(0, 1)
	var frames_used := 0
	while not game.gate_closed and frames_used < 60 * 40:
		var ahead := p.global_position.y
		cur.jump_held = ahead < 18.0
		await frames(1)
		frames_used += 1
		if frames_used == 60 * 6:
			await shot("street")
	check(game.gate_closed, "flew the street to the arena in %.0fs (x=%.0f)" % [frames_used / 60.0, p.global_position.x])

	# --- Venom's symbiote blast wipes out every robot nearby
	p = await fresh()
	clear_enemies()
	for k in 5:
		game.spawn_enemy("walker", p.global_position + Vector3(6 + k * 4, 0.3, -4 + k * 2))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(4)
	await shot("blast")
	var alive := 0
	for e in game.enemies:
		if is_instance_valid(e) and not e.dead:
			alive += 1
	check(alive == 0, "symbiote blast clears the robots (%d left)" % alive)

	# --- the boss fight
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(10)
	check(game.gate_closed, "entering the plaza closes the gate")
	await frames(140)
	var boss: MrPoo = game.boss
	check(boss.active, "Mr Poo wakes up")
	var hp_start := boss.hp
	var saw_poo := false
	var saw_puddle := false
	var saw_minipoo := false
	for f in 60 * 20:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = Venom.MAX_HP
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		cur.move = Vector2(0, 1) if Vector2(to.x, to.z).length() > 7.0 else Vector2(0, -0.6)
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		cur.special_pressed = f % 25 == 0
		cur.primary_pressed = f % 30 == 15
		await frames(1)
		for pr in game.projectiles:
			if is_instance_valid(pr) and pr.kind == "poo":
				saw_poo = true
		saw_puddle = saw_puddle or game.puddles.size() > 0
		for e in game.enemies:
			if is_instance_valid(e) and e.kind == "minipoo":
				saw_minipoo = true
		if f == 300:
			await shot("boss")
		if f == 400 and boss.phase == 1:
			boss.hurt(boss.hp - boss.max_hp * 0.45, Vector3.ZERO)  # skip ahead to the angry phase
	check(hp_start - boss.hp > 50.0, "bot hurt Mr Poo (%.0f damage)" % (hp_start - boss.hp))
	check(saw_poo and saw_puddle, "Mr Poo lobs poo that leaves puddles")
	check(boss.phase == 2, "Mr Poo gets angry at half health")
	print("  info  mini-poos spawned: %s" % saw_minipoo)
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "beating Mr Poo wins (%s)" % game.finished)
	await shot("won")

	# --- losing works
	p = await fresh()
	p.take_damage(1000.0, p.global_position)
	await frames(160)
	check(game.finished == "lost", "dying loses (%s)" % game.finished)

	print("selftest finished in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if failures.is_empty():
		print("ALL OK")
	else:
		print("FAILURES:")
		for f in failures:
			print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)
