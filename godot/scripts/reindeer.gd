class_name Reindeer
extends Node3D
## One of Santa's reindeer: gallops down out of the sky, charges at a target (or a spot),
## flattens every baddie it runs through on the way, then flies off into the sky.

const SPEED := 30.0

var game
var target = null      # Enemy or MrPoo, or null to charge at `goal`
var goal := Vector3.ZERO
var damage := 45.0
var boss_damage := 30.0
var state := "swoop"   # swoop down to the ground, charge along it, gallop through, fly off
var swoop := Vector3.ZERO
var t := 0.0
var leave_t := 0.0
var vel := Vector3.ZERO
var hit_ids := {}
var model: Dictionary


func setup(g, from: Vector3, tgt, at: Vector3, dmg: float, boss_dmg: float, deer_name := "", rudolph := false) -> void:
	game = g
	position = from
	target = tgt
	goal = at
	damage = dmg
	boss_damage = boss_dmg
	var aim_at: Vector3 = tgt.global_position if tgt != null else at
	var flat := Vector3(aim_at.x - from.x, 0, aim_at.z - from.z)
	var run_up: float = min(12.0, flat.length() * 0.6)
	swoop = aim_at - flat.normalized() * run_up  # land this far short, then charge along the ground
	swoop.y = aim_at.y
	if flat.length() < 4.0:
		state = "charge"
	model = Models.reindeer(rudolph)
	add_child(model["root"])
	if deer_name != "":
		var l := Label3D.new()
		l.text = deer_name
		l.font_size = 48
		l.outline_size = 10
		l.modulate = Color(1, 0.85, 0.4)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.008
		l.position.y = 2.2
		add_child(l)


func tick(dt: float) -> void:
	t += dt
	Models.animate_reindeer(model, t)
	match state:
		"swoop":
			var to := swoop - position
			vel = to.normalized() * SPEED if to.length() > 0.01 else vel
			position += vel * dt
			_hit_things()
			if to.length() < 1.0 or t > 2.0:
				state = "charge"
		"charge":
			if target != null and is_instance_valid(target) and not target.dead:
				goal = target.global_position
			var to := goal - position
			vel = to.normalized() * SPEED if to.length() > 0.01 else vel
			position += vel * dt
			_hit_things()
			var reached := Vector3(position.x - goal.x, 0, position.z - goal.z).length() < 1.0
			if target != null and is_instance_valid(target) and hit_ids.has(target.get_instance_id()):
				reached = true
			if reached or t > 3.5:
				state = "through"  # keep galloping on, flattening anything behind it
				leave_t = 0.0
				var flat := Vector3(vel.x, 0, vel.z).normalized()
				vel = (flat + Vector3.UP * max(-0.3, vel.normalized().y * 0.5)).normalized() * SPEED
		"through":
			leave_t += dt
			position += vel * dt
			position.y = max(position.y, 0.3)
			_hit_things()
			if leave_t > 0.6:
				state = "leave"
				leave_t = 0.0
				var flat := Vector3(vel.x, 0, vel.z).normalized()
				vel = (flat + Vector3.UP * 1.1).normalized() * SPEED
		"leave":  # off into the sky, getting smaller
			leave_t += dt
			position += vel * dt
			_hit_things()
			scale = Vector3.ONE * max(0.05, 1.0 - max(0.0, leave_t - 0.6))
			if leave_t > 1.6:
				queue_free()
				return
	if vel.length() > 0.1 and abs(vel.normalized().dot(Vector3.UP)) < 0.98:
		look_at(position + vel, Vector3.UP)


func _hit_things() -> void:
	for e in game.targets():
		var id: int = e.get_instance_id()
		if hit_ids.has(id):
			continue
		if (position + Vector3.UP * 0.9).distance_to(e.center()) < e.radius + 1.4:
			hit_ids[id] = true
			e.hurt(boss_damage if e == game.boss else damage, vel, 18.0)
			game.burst(e.center(), Color(1, 1, 1), 12, 7.0)
			game.audio.play("hit")
