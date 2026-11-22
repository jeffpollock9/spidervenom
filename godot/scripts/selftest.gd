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
	if OS.get_cmdline_user_args().has("--santa-only"):
		await santa_tests()
		_finish(t0)
		return
	if OS.get_cmdline_user_args().has("--hacker-only"):
		await hacker_tests()
		_finish(t0)
		return
	if OS.get_cmdline_user_args().has("--charley-only"):
		await charley_tests()
		_finish(t0)
		return
	if OS.get_cmdline_user_args().has("--jamie-only"):
		await jamie_tests()
		_finish(t0)
		return
	if OS.get_cmdline_user_args().has("--dad-only"):
		await dad_tests()
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
	await dad_tests()
	await jamie_tests()
	await charley_tests()
	await hacker_tests()
	await santa_tests()
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
	var classes := {"venom": Venom, "spiderman": Spiderman, "jamiesdad": JamiesDad, "jamie": Jamie,
		"charley": Charley, "hacker": Hacker, "santa": Santa}
	var n: int = game.HEROES.size()
	var right := true
	for i in range(2, n + 1):  # step through all of them and round to Venom again
		game.choose_hero(1)
		var want: String = game.HEROES[i % n]
		right = right and game.hero_id == want and is_instance_of(game.player, classes[want])
	check(right and game.player is Venom, "hero select steps through all %d heroes and wraps round" % n)
	game.choose_hero(-1)
	check(game.hero_id == game.HEROES[n - 1], "hero select wraps backwards")
	game.choose_hero(2)
	check(game.player is Spiderman, "hero select goes back to Spider-Man")
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


func dad_tests() -> void:
	print("  --- Jamie's Dad")
	game.state = "title"
	game.hero_id = "jamiesdad"
	game.new_game()
	game.open_select()
	await frames(40)
	await shot("dad_select")
	if shots_dir != "":  # a close look at that handsome face
		game.rig.height = 2.12
		game.rig.pitch = 0.0
		game.rig.shoulder = 0.0
		game.rig.arm.spring_length = 1.5
		await frames(5)
		await shot("dad_face")
	game.start_play()

	# --- super speed
	var p := await fresh()
	clear_enemies()
	check(p is JamiesDad and p.max_hp >= 300.0, "playing as Jamie's Dad (%d hp)" % p.max_hp)
	var x0 := p.global_position.x
	cur.move = Vector2(0, 1)
	await frames(60)
	var run := p.global_position.x - x0
	check(run > 11.0, "he runs fast (%.1f m in a second)" % run)
	cur.alt_held = true
	var top_speed := 0.0
	for i in 40:
		await frames(1)
		top_speed = max(top_speed, Vector2(p.velocity.x, p.velocity.z).length())
		if i == 30:
			await shot("dad_sprint")
	check(p.sprinting and top_speed > 28.0, "SHIFT super-sprints (%.1f m/s)" % top_speed)
	cur = Controls.new()
	await frames(40)

	# --- running into robots at super speed flattens them, and doesn't hurt him
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 3:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(14 + k * 5, 0.3, 0)))
	await frames(3)
	var hp0 := p.hp
	cur.move = Vector2(0, 1)
	cur.alt_held = true
	await frames(70)
	var flattened := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			flattened += 1
	check(flattened == 3 and p.hp >= hp0, "super-sprint flattens robots (%d/3, hp %d -> %d)" % [flattened, hp0, p.hp])
	cur = Controls.new()
	await frames(40)

	# --- one super punch is enough for a robot
	p = await fresh()
	clear_enemies()
	var foe: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(2.4, 0.3, 0))
	await frames(3)
	cur.aim_override = foe.center()
	cur.primary_pressed = true
	await frames(3)
	check(not is_instance_valid(foe) or foe.dead, "one super punch knocks out a robot")
	cur = Controls.new()
	await frames(30)

	# --- thunder clap blasts through a line of robots
	clear_enemies()
	foes.clear()
	for k in 3:
		foes.append(game.spawn_enemy("shooter", p.global_position + Vector3(7 + k * 3, 0.3, 0)))
	await frames(3)
	cur.aim_override = (foes[0] as Enemy).center()
	cur.special_pressed = true
	await frames(30)
	var clapped := 0
	for e in foes:
		if not is_instance_valid(e) or e.hp < e.max_hp:
			clapped += 1
	check(clapped == 3, "thunder clap hits every robot in a line (%d/3)" % clapped)
	cur = Controls.new()

	# --- ground pound
	p = await fresh()
	clear_enemies()
	foes.clear()
	for k in 4:
		var a := k * TAU / 4.0
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(cos(a) * 5.0, 0.3, sin(a) * 5.0)))
	cur.jump_pressed = true
	cur.jump_held = true
	await frames(25)
	cur = Controls.new()
	cur.down_held = true
	await frames(2)
	check(p.pounding, "CTRL in mid-air starts a ground pound")
	var pounded := false
	for i in 60:
		await frames(1)
		if not p.pounding:
			pounded = true
			break
	await shot("dad_pound")
	var squashed := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			squashed += 1
	check(pounded and squashed >= 3, "ground pound flattens the robots round him (%d/4)" % squashed)
	cur = Controls.new()

	# --- super health heals itself
	p = await fresh()
	clear_enemies()
	p.take_damage(100.0, p.global_position + Vector3.RIGHT)
	var low := p.hp
	await frames(60 * 4)
	check(p.hp > low + 10.0, "super health heals back up (%d -> %d)" % [low, p.hp])

	# --- DAD SMASH
	p = await fresh()
	clear_enemies()
	foes.clear()
	for k in 5:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(8 + k * 5, 0.3, -6 + k * 3)))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(5)
	await shot("dad_smash")
	var smashed := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			smashed += 1
	check(smashed == 5, "DAD SMASH knocks out every robot (%d/5)" % smashed)
	cur = Controls.new()

	# --- Jamie's Dad vs Mr Poo
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	var hp_start := boss.hp
	var damage := 0.0
	for f in 60 * 10:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = p.max_hp
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		cur.move = Vector2(0, 1) if Vector2(to.x, to.z).length() > 5.0 else Vector2.ZERO
		var close := Vector2(to.x, to.z).length() < p.punch_reach + boss.radius
		cur.primary_pressed = close and p.cd <= 0.0
		cur.special_pressed = not close and p.cd <= 0.0 and f % 30 == 0
		await frames(1)
		if is_instance_valid(boss):
			damage = hp_start - boss.hp
		if f == 150:
			await shot("dad_boss")
	check(damage > 150.0, "Jamie's Dad batters Mr Poo (%.0f damage)" % damage)
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "Jamie's Dad saves Supercity (%s)" % game.finished)


func jamie_tests() -> void:
	print("  --- Jamie")
	game.state = "title"
	game.hero_id = "jamie"
	game.new_game()
	game.open_select()
	await frames(40)
	await shot("jamie_select")
	if shots_dir != "":  # that face
		game.rig.height = 1.75
		game.rig.pitch = 0.0
		game.rig.shoulder = 0.0
		game.rig.arm.spring_length = 1.4
		await frames(5)
		await shot("jamie_face")
	game.start_play()

	# --- invincible: nothing hurts him, not even falling in the pit
	var p := await fresh()
	clear_enemies()
	check(p is Jamie and p.invincible, "playing as Jamie")
	var hp0 := p.hp
	p.take_damage(1000.0, p.global_position + Vector3.RIGHT)
	await frames(30)
	check(p.hp == hp0 and not p.dead, "1000 damage does nothing to him")
	p.global_position = Vector3(81, 3, 5)
	await frames(120)
	check(p.hp == hp0 and p.global_position.distance_to(p.safe_pos) < 3.0, "falling in the pit doesn't hurt him either")

	# --- strong punch
	p = await fresh()
	clear_enemies()
	var foe: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(2.0, 0.3, 0))
	await frames(3)
	cur.aim_override = foe.center()
	cur.primary_pressed = true
	await frames(3)
	check(not is_instance_valid(foe) or foe.hp <= foe.max_hp - 36.0, "a strong punch (hp left %d)" % (foe.hp if is_instance_valid(foe) else 0))
	cur = Controls.new()
	await frames(30)

	# --- smart shot steers itself into a robot he isn't even aiming at
	clear_enemies()
	foe = game.spawn_enemy("shooter", p.global_position + Vector3(14, 0.3, 7))
	await frames(3)
	cur.aim_override = p.global_position + Vector3(20, 2.0, -6)  # aiming well off to the side
	cur.special_pressed = true
	await frames(60)
	check(not is_instance_valid(foe) or foe.hp < foe.max_hp, "smart shot finds the robot by itself")
	cur = Controls.new()

	# --- jetpack
	p = await fresh()
	clear_enemies()
	var y0 := p.global_position.y
	cur.alt_held = true
	cur.move = Vector2(0, 1)
	var top := y0
	for i in 90:
		await frames(1)
		top = max(top, p.global_position.y)
		if i == 60:
			await shot("jamie_jetpack")
	check(top - y0 > 8.0 and p.energy < 90.0, "SHIFT jetpack flies him up (%.1f m, energy %d)" % [top - y0, p.energy])
	cur = Controls.new()
	await frames(150)
	check(p.is_on_floor(), "lets go of SHIFT and lands")

	# --- GENIUS HACK
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 5:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(8 + k * 5, 0.3, -6 + k * 3)))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(5)
	await shot("jamie_hack")
	var hacked := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			hacked += 1
	check(hacked == 5, "GENIUS HACK shuts down every robot (%d/5)" % hacked)
	cur = Controls.new()

	# --- Jamie vs Mr Poo: he can't lose
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	var hp_start := boss.hp
	var damage := 0.0
	for f in 60 * 12:  # stand right next to him the whole time
		if not is_instance_valid(boss) or boss.dead:
			break
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		var close := Vector2(to.x, to.z).length() < p.punch_reach + boss.radius
		cur.move = Vector2.ZERO if close else Vector2(0, 1)
		cur.primary_pressed = close and p.cd <= 0.0
		cur.special_pressed = not close and p.cd <= 0.0 and f % 20 == 0
		await frames(1)
		if is_instance_valid(boss):
			damage = hp_start - boss.hp
		if f == 200:
			await shot("jamie_boss")
	check(damage > 150.0, "Jamie batters Mr Poo (%.0f damage)" % damage)
	check(p.hp == p.max_hp and not p.dead and game.state == "play" or game.state == "won",
		"Mr Poo can't hurt him (hp %d, %s)" % [p.hp, game.state])
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "Jamie saves Supercity (%s)" % game.finished)


func charley_tests() -> void:
	print("  --- Charley")
	game.state = "title"
	game.hero_id = "charley"
	game.new_game()
	game.open_select()
	await frames(40)
	await shot("charley_select")
	if shots_dir != "":
		game.rig.height = 1.45
		game.rig.pitch = 0.0
		game.rig.shoulder = 0.0
		game.rig.arm.spring_length = 1.3
		await frames(5)
		await shot("charley_face")
	game.start_play()

	# --- slow, wee jumps, and he gets puffed out
	var p := await fresh()
	clear_enemies()
	check(p is Charley and p.max_hp <= 30.0, "playing as Charley (%d hp)" % p.max_hp)
	var x0 := p.global_position.x
	cur.move = Vector2(0, 1)
	await frames(60)
	var run := p.global_position.x - x0
	check(run < 7.0, "he's slow (%.1f m in a second)" % run)
	var puffed := false
	for i in 60 * 5:
		await frames(1)
		if p.puffed_t > 0.0:
			puffed = true
			break
	check(puffed, "running for a few seconds puffs him out")
	x0 = p.global_position.x
	await frames(60)
	check(p.global_position.x - x0 < 3.5, "puffed out he can barely walk (%.1f m)" % (p.global_position.x - x0))
	await shot("charley_puffed")
	cur = Controls.new()
	await frames(200)
	var y0 := p.global_position.y
	cur.jump_pressed = true
	cur.jump_held = true
	var top := y0
	for i in 40:
		await frames(1)
		top = max(top, p.global_position.y)
	check(top - y0 < 1.6, "only a wee jump (%.1f m)" % (top - y0))
	cur = Controls.new()
	await frames(30)

	# --- his punches only tickle
	p = await fresh()
	clear_enemies()
	var foe: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(1.4, 0.3, 0))
	await frames(3)
	var punches := 0
	for f in 200:
		if not is_instance_valid(foe) or foe.dead:
			break
		cur.aim_override = foe.center()
		var gap := foe.global_position - p.global_position
		game.rig.face_dir(Vector3(gap.x, 0, gap.z).normalized())
		cur.move = Vector2(0, 1) if Vector2(gap.x, gap.z).length() > 1.2 else Vector2.ZERO
		cur.primary_pressed = Vector2(gap.x, gap.z).length() < 1.8 and p.cd <= 0.0
		punches += int(cur.primary_pressed)
		p.hp = p.max_hp
		await frames(1)
	check(is_instance_valid(foe) and not foe.dead and foe.hp < foe.max_hp and foe.hp > foe.max_hp - 25,
		"%d punches barely tickle a robot (hp %d/%d)" % [punches, foe.hp if is_instance_valid(foe) else 0, foe.max_hp if is_instance_valid(foe) else 0])
	cur = Controls.new()

	# --- hiding: the robots stop bothering with him
	p = await fresh()
	clear_enemies()
	var walker: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(8, 0.3, 0))
	var shooter: Enemy = game.spawn_enemy("shooter", p.global_position + Vector3(12, 0.3, 5))
	cur.alt_held = true
	await frames(5)
	check(p.hiding, "SHIFT hides")
	await shot("charley_hide")
	var hp0 := p.hp
	var shots := 0
	var wd0 := walker.global_position.distance_to(p.global_position)
	for i in 60 * 4:
		await frames(1)
		for pr in game.projectiles:
			if is_instance_valid(pr) and pr.kind == "bolt":
				shots += 1
	check(shots == 0 and p.hp == hp0 and walker.global_position.distance_to(p.global_position) > 1.5,
		"robots don't chase or shoot him while he hides (shots %d, walker %.1f -> %.1f m)" % [shots, wd0, walker.global_position.distance_to(p.global_position)])
	cur = Controls.new()

	# --- he goes down easily
	p = await fresh()
	clear_enemies()
	p.take_damage(9.0, p.global_position + Vector3.RIGHT)
	await frames(60)
	p.take_damage(12.0, p.global_position + Vector3.RIGHT)
	await frames(60)
	p.take_damage(12.0, p.global_position + Vector3.RIGHT)
	await frames(160)
	check(game.finished == "lost", "three hits and he's done (%s)" % game.finished)

	# --- CALL FOR HELP: Jamie's Dad drops in and smashes everything
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 5:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(10 + k * 5, 0.3, -6 + k * 3)))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(12)
	await shot("charley_help_falling")
	var helped := false
	for i in 60:
		await frames(1)
		if p.helper_landed:
			helped = true
			break
	await frames(4)
	await shot("charley_help")
	var smashed := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			smashed += 1
	check(helped and smashed == 5, "Jamie's Dad drops in and smashes every robot (%d/5)" % smashed)
	cur = Controls.new()
	await frames(120)
	check(p.helper == null, "and then he goes home")

	# --- Charley can still beat Mr Poo, with a lot of help
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	var calls := 0
	for f in 60 * 60:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = p.max_hp
		if p.energy >= 100.0 and (p.helper == null):
			cur.ult_pressed = true
			calls += 1
		await frames(1)
	check(not is_instance_valid(boss) or boss.dead, "calling for help %d times beats Mr Poo" % calls)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "Charley saves Supercity (%s)" % game.finished)


func hacker_tests() -> void:
	print("  --- Hacker")
	game.state = "title"
	game.hero_id = "hacker"
	game.new_game()
	game.open_select()
	await frames(40)
	await shot("hacker_select")
	game.start_play()

	# --- hack a robot: it turns on its mate
	var p := await fresh()
	clear_enemies()
	check(p is Hacker, "playing as the Hacker")
	var pet: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(9, 0.3, 0))
	var other: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(16, 0.3, 3))
	await frames(3)
	cur.aim_override = pet.center()
	cur.special_pressed = true
	await frames(3)
	check(pet.hacked_t > 0.0 and not game.targets().has(pet), "RIGHT CLICK hacks the robot he points at")
	cur = Controls.new()
	var beaten := false
	for i in 60 * 8:
		await frames(1)
		p.hp = p.max_hp
		if i == 50:
			await shot("hacker_pet")
		if not is_instance_valid(other) or other.dead:
			beaten = true
			break
	check(beaten, "the hacked robot batters the other robot")
	check(is_instance_valid(pet) and not pet.dead, "and the hacked robot is still going")
	# it can't be hurt by the Hacker
	var php := pet.hp
	cur.aim_override = pet.center()
	game.rig.face_dir((pet.global_position - p.global_position).normalized())
	cur.primary_pressed = true
	await frames(3)
	check(not is_instance_valid(pet) or pet.hp == php, "zapping doesn't hurt your own hacked robot")
	cur = Controls.new()
	# battery runs out
	if is_instance_valid(pet):
		pet.hacked_t = 0.05
	await frames(10)
	check(not is_instance_valid(pet) or pet.dead, "when its battery runs out it shuts down")

	# --- a hacked shooter shoots robots
	p = await fresh()
	clear_enemies()
	var gun: Enemy = game.spawn_enemy("shooter", p.global_position + Vector3(10, 0.3, 0))
	var mark: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(22, 0.3, 0))
	await frames(3)
	gun.hack(10.0)
	var hit := false
	for i in 60 * 4:
		await frames(1)
		p.hp = p.max_hp
		if not is_instance_valid(mark) or mark.hp < mark.max_hp:
			hit = true
			break
	check(hit, "a hacked shooter shoots the other robots")

	# --- zap chains to a second robot
	p = await fresh()
	clear_enemies()
	var a: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(3.5, 0.3, 0))
	var b: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(7.5, 0.3, 1.5))
	await frames(3)
	cur.aim_override = a.center()
	cur.primary_pressed = true
	await frames(3)
	await shot("hacker_zap")
	check(is_instance_valid(a) and a.hp < a.max_hp and is_instance_valid(b) and b.hp < b.max_hp,
		"LEFT CLICK zap jumps to a second robot")
	cur = Controls.new()

	# --- can't hack Mr Poo or the mini-poos
	clear_enemies()
	var poo: Enemy = game.spawn_enemy("minipoo", p.global_position + Vector3(6, 0.3, 0))
	await frames(3)
	p.energy = 100.0
	cur.aim_override = poo.center()
	cur.special_pressed = true
	await frames(3)
	check(is_instance_valid(poo) and poo.hacked_t <= 0.0, "you can't hack a poo")
	cur = Controls.new()

	# --- glitch forward
	p = await fresh()
	clear_enemies()
	var x0 := p.global_position.x
	game.rig.face_dir(Vector3.RIGHT)
	cur.move = Vector2(0, 1)
	cur.alt_pressed = true
	await frames(1)
	cur.alt_pressed = false
	check(p.global_position.x - x0 > 6.0, "SHIFT glitches him forward (%.1f m in one frame)" % (p.global_position.x - x0))
	cur = Controls.new()

	# --- SYSTEM HACK
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 4:
		foes.append(game.spawn_enemy("walker", p.global_position + Vector3(8 + k * 5, 0.3, -6 + k * 3)))
	var mini: Enemy = game.spawn_enemy("minipoo", p.global_position + Vector3(9, 0.3, 6))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(5)
	await shot("hacker_system")
	var turned := 0
	for e in foes:
		if is_instance_valid(e) and e.hacked_t > 0.0:
			turned += 1
	check(turned == 4 and (not is_instance_valid(mini) or mini.dead), "SYSTEM HACK turns every robot and deletes the poo (%d/4)" % turned)
	cur = Controls.new()

	# --- the Hacker vs Mr Poo (with some hacked robots helping)
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	for k in 3:
		var helper: Enemy = game.spawn_enemy("shooter" if k == 0 else "walker", Vector3(278, 0.5, -4 + k * 4))
		helper.hack(30.0)
	var hp_start := boss.hp
	var damage := 0.0
	var denied := false
	for f in 60 * 12:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = p.max_hp
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		var close := Vector2(to.x, to.z).length() < p.punch_reach + boss.radius
		cur.move = Vector2(0, 1) if not close else Vector2.ZERO
		cur.primary_pressed = close and p.cd <= 0.0
		if f == 30:
			cur.special_pressed = true
			p.energy = 100.0
		await frames(1)
		if f == 31:
			denied = boss.hp < hp_start
		if is_instance_valid(boss):
			damage = hp_start - boss.hp
		if f == 200:
			await shot("hacker_boss")
	check(denied, "trying to hack Mr Poo: ACCESS DENIED")
	check(damage > 150.0, "the Hacker and his robots beat up Mr Poo (%.0f damage)" % damage)
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "the Hacker saves Supercity (%s)" % game.finished)


func santa_tests() -> void:
	print("  --- Santa")
	game.state = "title"
	game.hero_id = "santa"
	game.new_game()
	game.open_select()
	await frames(40)
	await shot("santa_select")
	game.start_play()

	# --- RIGHT CLICK: a reindeer comes and flattens the robot you point at
	var p := await fresh()
	clear_enemies()
	check(p is Santa, "playing as Santa")
	var foe: Enemy = game.spawn_enemy("shooter", p.global_position + Vector3(14, 0.3, 4))
	var other: Enemy = game.spawn_enemy("walker", p.global_position + Vector3(14, 0.3, -12))
	await frames(3)
	cur.aim_override = foe.center()
	cur.special_pressed = true
	await frames(2)
	check(game.reindeer.size() == 1, "RIGHT CLICK calls a reindeer")
	cur = Controls.new()
	var got := false
	for i in 120:
		await frames(1)
		if i == 14:
			await shot("santa_reindeer")
		if not is_instance_valid(foe) or foe.dead:
			got = true
			break
	check(got, "the reindeer defeats the robot")
	check(is_instance_valid(other) and other.hp == other.max_hp, "and leaves the one you weren't pointing at")
	await frames(170)
	check(game.reindeer.is_empty(), "then flies off home")

	# --- a reindeer flattens everything in its way
	clear_enemies()
	var line: Array = []
	for k in 3:
		line.append(game.spawn_enemy("walker", p.global_position + Vector3(8 + k * 4, 0.3, 0)))
	await frames(3)
	for e in line:
		e.daze(5.0)  # keep them standing in a line
	p.energy = 100.0
	cur.aim_override = (line[2] as Enemy).center()
	cur.special_pressed = true
	await frames(1)
	cur = Controls.new()
	await frames(120)
	var flat := 0
	for e in line:
		if not is_instance_valid(e) or e.dead:
			flat += 1
	var left := []
	for e in line:
		if is_instance_valid(e) and not e.dead:
			left.append("x=%.1f hp=%d" % [e.global_position.x - p.global_position.x, e.hp])
	check(flat == 3, "a reindeer flattens every robot in its way (%d/3) %s" % [flat, left])

	# --- LEFT CLICK: throw a present
	p = await fresh()
	clear_enemies()
	foe = game.spawn_enemy("shooter", p.global_position + Vector3(9, 0.3, 0))
	await frames(3)
	cur.aim_override = foe.center()
	cur.primary_pressed = true
	await frames(60)
	check(not is_instance_valid(foe) or foe.hp < foe.max_hp, "a thrown present bursts on a robot")
	cur = Controls.new()

	# --- SHIFT: ho ho ho
	clear_enemies()
	foe = game.spawn_enemy("walker", p.global_position + Vector3(5, 0.3, 0))
	await frames(3)
	p.energy = 100.0
	cur.alt_pressed = true
	await frames(2)
	check(foe.stun_t > 0.0, "HO HO HO stops a robot in its tracks")
	cur = Controls.new()

	# --- sleigh ride
	p = await fresh()
	clear_enemies()
	cur.jump_pressed = true
	cur.jump_held = true
	await frames(15)
	cur.jump_pressed = true
	await frames(2)
	check(p.flying and (p.model["sleigh"] as Node3D).visible, "jump in mid-air: the sleigh appears")
	var y0 := p.global_position.y
	cur.move = Vector2(0, 1)
	await frames(90)
	check(p.global_position.y - y0 > 8.0, "the sleigh flies (%.1f m up)" % (p.global_position.y - y0))
	await shot("santa_sleigh")
	cur = Controls.new()
	cur.down_held = true
	await frames(240)
	check(not p.flying and not (p.model["sleigh"] as Node3D).visible, "lands and the sleigh goes away")
	cur = Controls.new()

	# --- REINDEER STAMPEDE
	p = await fresh()
	clear_enemies()
	var foes: Array = []
	for k in 6:
		foes.append(game.spawn_enemy("walker" if k % 2 else "shooter", p.global_position + Vector3(8 + k * 4, 0.3, -8 + k * 3)))
	await frames(3)
	p.energy = 100.0
	cur.ult_pressed = true
	await frames(2)
	check(game.reindeer.size() >= 9, "REINDEER STAMPEDE brings all the reindeer (%d)" % game.reindeer.size())
	cur = Controls.new()
	await frames(16)
	await shot("santa_stampede")
	for i in 150:
		await frames(1)
	var down := 0
	for e in foes:
		if not is_instance_valid(e) or e.dead:
			down += 1
	check(down == 6, "the stampede defeats every robot (%d/6)" % down)

	# --- Santa vs Mr Poo
	p = await fresh()
	clear_enemies()
	p.global_position = Vector3(275, 0.3, 0)
	await frames(150)
	var boss: MrPoo = game.boss
	var hp_start := boss.hp
	var damage := 0.0
	for f in 60 * 12:
		if not is_instance_valid(boss) or boss.dead:
			break
		p.hp = p.max_hp
		cur.aim_override = boss.center()
		var to := boss.global_position - p.global_position
		game.rig.face_dir(Vector3(to.x, 0, to.z).normalized())
		cur.move = Vector2(0, 1) if Vector2(to.x, to.z).length() > 9.0 else Vector2(0, -0.5)
		cur.special_pressed = p.cd <= 0.0 and p.energy >= 16.0 and f % 30 == 0
		cur.primary_pressed = p.cd <= 0.0 and f % 30 == 15
		await frames(1)
		if is_instance_valid(boss):
			damage = hp_start - boss.hp
		if f == 120:
			await shot("santa_boss")
	check(damage > 150.0, "Santa's reindeer batter Mr Poo (%.0f damage)" % damage)
	if is_instance_valid(boss) and not boss.dead:
		boss.hurt(1e6, Vector3.ZERO)
	cur = Controls.new()
	await frames(220)
	check(game.finished == "won", "Santa saves Supercity (%s)" % game.finished)
