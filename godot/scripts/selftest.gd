extends Node
## Headless smoke test: drives each hero with a bot and checks every power, the sky-lifts,
## falling, the boss fight, winning and losing, and the hero select screen. Run with:
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


func fresh() -> Hero:
	game.state = "play"
	game.new_game()
	cur = Controls.new()
	await frames(20)  # let him land after spawning
	var p: Hero = game.player
	game.rig.face_dir(Vector3.RIGHT)
	return p


func clear_enemies() -> void:
	for e in game.enemies:
		if is_instance_valid(e):
			e.queue_free()
	game.enemies.clear()


func run() -> void:
	var t0 := Time.get_ticks_msec()
	game.hero_id = "venom"
	if OS.get_cmdline_user_args().has("--spiderman-only"):
		await spiderman_tests()
		_finish(t0)
		return
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
	if shots_dir != "":  # a close look at the big man from the front and the side
		clear_enemies()
		var arm_len: float = game.rig.arm.spring_length
		game.rig.arm.spring_length = 5.5 * p.size
		game.rig.pitch = -0.1
		game.rig.face_dir(Vector3.LEFT)
		await frames(20)
		await shot("venom_front")
		game.rig.face_dir(Vector3(-1, 0, 1).normalized())
		await frames(20)
		await shot("venom_side")
		game.rig.arm.spring_length = arm_len
		game.rig.pitch = -0.18

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
	var bot_damage := 0.0
	var angry := false
	for f in 60 * 20:
		if not is_instance_valid(boss) or boss.dead:
			break
		angry = angry or boss.phase == 2
		if f < 400:
			bot_damage = hp_start - boss.hp
		p.hp = p.max_hp
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
	check(bot_damage > 50.0, "bot hurt Mr Poo (%.0f damage)" % bot_damage)
	check(saw_poo and saw_puddle, "Mr Poo lobs poo that leaves puddles")
	check(angry or not is_instance_valid(boss) or boss.phase == 2, "Mr Poo gets angry at half health")
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

	await spiderman_tests()
	_finish(t0)


func _finish(t0: int) -> void:
	print("selftest finished in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	if failures.is_empty():
		print("ALL OK")
	else:
		print("FAILURES:")
		for f in failures:
			print("  - " + f)
	get_tree().quit(0 if failures.is_empty() else 1)


func spiderman_tests() -> void:
	print("  --- Spider-Man")
	# --- the hero select screen swaps the hero standing in front of the camera
	game.state = "title"
	game.new_game()
	game.open_select()
	game.choose_hero(1)
	await frames(30)
	check(game.state == "select" and game.hero_id == "spiderman" and game.player is Spiderman,
		"hero select picks Spider-Man (%s)" % game.hero_id)
	await shot("select")
	game.choose_hero(1)
	check(game.player is Venom, "hero select wraps round to Venom")
	game.choose_hero(-1)
	game.start_play()

	# --- quicker than Venom, and a somersault for a second jump
	var p := await fresh()
	clear_enemies()
	check(p is Spiderman, "playing as Spider-Man")
	var x0 := p.global_position.x
	cur.move = Vector2(0, 1)
	await frames(60)
	check(p.global_position.x - x0 > 8.0, "Spider-Man runs (%.1f m in a second)" % (p.global_position.x - x0))
	cur = Controls.new()
	await frames(30)
	var y0 := p.global_position.y
	cur.jump_pressed = true
	cur.jump_held = true
	await frames(18)
	cur.jump_pressed = true
	await frames(2)
	check(p.flip_t > 0.0 and not p.flying, "jumping in mid-air does a somersault, not flying")
	var top := y0
	for i in 40:
		await frames(1)
		top = max(top, p.global_position.y)
	check(top - y0 > 4.5, "double jump goes high (%.1f m)" % (top - y0))
	cur = Controls.new()
	await frames(60)

	# --- web shot sticks a robot in place
	p = await fresh()
	clear_enemies()
	var foe: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(10, 0.3, 0))
	await frames(5)
	cur.aim_override = foe.center()
	cur.special_pressed = true
	await frames(20)
	check(is_instance_valid(foe) and foe.stun_t > 0.0 and foe.cocoon != null and foe.cocoon.visible,
		"web shot wraps a robot in web")
	if is_instance_valid(foe):
		var fp := foe.global_position
		await frames(60)
		check(is_instance_valid(foe) and foe.global_position.distance_to(fp) < 0.5, "a webbed robot can't move")
	cur = Controls.new()

	# --- punches: quick jabs finish a robot
	clear_enemies()
	foe = game.spawn_enemy("walker", p.global_position + Vector3(1.6, 0.3, 0))
	await frames(3)
	for f in 150:
		if not is_instance_valid(foe) or foe.dead:
			break
		cur.aim_override = foe.center()
		var gap := foe.global_position - p.global_position
		game.rig.face_dir(Vector3(gap.x, 0, gap.z).normalized())
		cur.move = Vector2(0, 1) if Vector2(gap.x, gap.z).length() > 1.8 else Vector2.ZERO
		cur.primary_pressed = Vector2(gap.x, gap.z).length() < 2.4 and p.cd <= 0.0
		await frames(1)
	check(not is_instance_valid(foe) or foe.dead, "Spider-Man punches a robot to bits")
	cur = Controls.new()

	# --- web-swinging
	p = await fresh()
	clear_enemies()
	cur.aim_override = p.global_position + Vector3(10, 28, -14)
	cur.alt_pressed = true
	cur.alt_held = true
	await frames(2)
	check(p.swinging, "Spider-Man web-swings")
	cur.move = Vector2(0, 1)
	var max_speed := 0.0
	var high := 0.0
	for i in 50:
		await frames(1)
		max_speed = max(max_speed, p.velocity.length())
		high = max(high, p.global_position.y)
		if i == 25:
			await shot("webswing")
	check(high > 3.0 and max_speed > 12.0, "web-swing lifts and speeds him up (%.1f m, %.1f m/s)" % [high, max_speed])
	cur = Controls.new()
	await frames(90)

	# --- wall-crawling up a skyscraper
	p = await fresh()
	clear_enemies()
	var best := Vector3.ZERO
	var best_d := 1e9
	for side in [Vector3.BACK, Vector3.FORWARD]:
		for dx in [0.0, 6.0, 12.0, 18.0]:
			var from: Vector3 = p.global_position + Vector3(dx, 1.0, 0)
			var q := PhysicsRayQueryParameters3D.create(from, from + side * 40.0, 1, [p.get_rid()])
			var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
			if hit and (hit.collider as Node3D).global_position.y > -1.0:
				var up := PhysicsRayQueryParameters3D.create(hit.position + side * -0.3 + Vector3.UP * 12.0,
					hit.position + side * -0.3 + Vector3.UP * 12.0 + side * 2.0, 1)
				if p.get_world_3d().direct_space_state.intersect_ray(up) and from.distance_to(hit.position) < best_d:
					best_d = from.distance_to(hit.position)  # a wall at least 12 m tall
					best = hit.position - side * 1.5
					best.y = p.global_position.y
	check(best_d < 1e9, "found a tall wall to climb (%.1f m away)" % best_d)
	p.global_position = best
	await frames(5)
	var wall_dir := Vector3.BACK if best.z > 0 else Vector3.FORWARD
	game.rig.face_dir(wall_dir)
	cur.move = Vector2(0, 1)
	var climbed := false
	for i in 90:
		await frames(1)
		if p.climbing:
			climbed = true
			break
	check(climbed, "running into a wall starts wall-crawling")
	y0 = p.global_position.y
	await frames(90)
	check(p.climbing and p.global_position.y - y0 > 6.0, "crawls up the wall (%.1f m)" % (p.global_position.y - y0))
	game.rig.face_dir((wall_dir + Vector3.RIGHT * 1.2).normalized())
	game.rig.pitch = 0.3
	await frames(10)
	await shot("climb")
	game.rig.face_dir(wall_dir)
	game.rig.pitch = -0.18
	cur.move = Vector2.ZERO
	cur.down_held = true
	await frames(20)
	check(p.climbing and p.velocity.y < -1.0, "CTRL climbs down the wall")
	cur.down_held = false
	cur.jump_pressed = true
	await frames(3)
	check(not p.climbing and p.velocity.length() > 5.0, "SPACE leaps off the wall")
	cur = Controls.new()
	await frames(150)
	p.global_position = best  # climb a bit, then all the way back down
	p.velocity = Vector3.ZERO
	await frames(5)
	cur.move = Vector2(0, 1)
	await frames(50)
	cur.move = Vector2.ZERO
	cur.down_held = true
	for i in 200:
		await frames(1)
		if not p.climbing:
			break
	check(not p.climbing and p.is_on_floor(), "climbing down to the street lets go of the wall (climbing %s, floor %s, y %.1f)" % [p.climbing, p.is_on_floor(), p.global_position.y])
	cur = Controls.new()

	# --- WEB STORM webs up every robot nearby
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 5:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(6 + k * 4, 0.3, -4 + k * 2)))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(4)
	await shot("webstorm")
	var webbed := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead or e.stun_t > 0.0:
			webbed += 1
	check(webbed == 5 and p.energy < 50.0, "WEB STORM webs up the robots (%d/5)" % webbed)
	cur = Controls.new()

	# --- Spider-Man vs Mr Poo
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	check(boss.active, "Mr Poo wakes up for Spider-Man")
	var hp_start := boss.hp
	var damage := 0.0
	var stuck := false
	for f in 60 * 12:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = p.max_hp
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		cur.move = Vector2(0, 1) if Vector2(to.x, to.z).length() > 7.0 else Vector2(0, -0.6)
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		cur.special_pressed = f % 20 == 0
		await frames(1)
		damage = hp_start - boss.hp
		stuck = stuck or boss.stun_t > 0.0
		if f == 200:
			await shot("spidey_boss")
	check(damage > 40.0, "Spider-Man hurts Mr Poo (%.0f damage)" % damage)
	check(stuck, "webs hold Mr Poo for a moment")
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "Spider-Man saves Supercity (%s)" % game.finished)
