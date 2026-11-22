class_name Projectile
extends Node3D
## Symbiote blasts, robot bolts and Mr Poo's poo. Moves itself and hits the world with a ray.

var game
var vel := Vector3.ZERO
var owner_side := "player"  # player | enemy
var kind := "symbiote"
var damage := 10.0
var radius := 0.4
var grav := 0.0
var life := 2.0
var knock := 8.0
var pierce := false
var web_secs := 0.0
var homing := false
var dead := false
var age := 0.0
var hit_ids := {}


func setup(g, pos: Vector3, v: Vector3, side: String, k: String, dmg: float, r: float, opts: Dictionary) -> void:
	game = g
	position = pos
	vel = v
	owner_side = side
	kind = k
	damage = dmg
	radius = r
	grav = opts.get("gravity", 0.0)
	life = opts.get("life", 2.0)
	knock = opts.get("knock", 8.0)
	pierce = opts.get("pierce", false)
	web_secs = opts.get("web", 0.0)
	homing = opts.get("homing", false)
	match kind:
		"symbiote":
			var black := Models.mat(Models.VENOM_BLACK, 0.2, 0.3, 0.0, 0.8)
			Models.part(self, Models.sphere(r), black)
			for i in 3:
				Models.part(self, Models.sphere(r * 0.45, 8), black, Vector3(r, 0, 0))
			Models.part(self, Models.sphere(r * 0.25, 8), Models.mat(Color(0.4, 0.4, 0.65), 0.2), Vector3(-r * 0.4, r * 0.4, -r * 0.5))
		"web":
			var white := Models.mat(Color(0.96, 0.96, 1.0), 0.4, 0.0, 0.3)
			Models.part(self, Models.sphere(r * 0.6, 10), white)
			for i in 4:  # strands trailing out behind
				var a := i * TAU / 4.0
				var mi := Models.part(self, Models.cylinder(0.015, 0.015, r * 3.0, 4), white,
					Vector3(cos(a), sin(a), 0) * r * 0.6 + Vector3(0, 0, r * 1.2))
				mi.rotation = Vector3(PI / 2 + sin(a) * 0.35, 0, 0)
				mi.rotation.y = -cos(a) * 0.35
		"sock":
			var white := Models.mat(Color(0.97, 0.97, 0.97), 0.8)
			Models.part(self, Models.capsule(r * 0.6, r * 3.0), white, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			Models.part(self, Models.sphere(r * 0.7, 8), white, Vector3(0, -r * 0.6, -r * 1.2))
			Models.part(self, Models.box(Vector3(r * 1.3, r * 0.3, r * 0.4)), Models.mat(Color(0.85, 0.2, 0.2), 0.8),
				Vector3(0, 0, r * 1.3))
		"hackbolt":
			Models.part(self, Models.capsule(r * 0.6, r * 4.0), Models.mat(Color(0.2, 1.0, 0.4), 0.3, 0.0, 3.0),
				Vector3.ZERO, Vector3(PI / 2, 0, 0))
		"smart":
			Models.part(self, Models.sphere(r, 12), Models.mat(Color(0.3, 1.0, 0.7), 0.2, 0.0, 4.0))
			var ring := TorusMesh.new()
			ring.inner_radius = r * 1.3
			ring.outer_radius = r * 1.6
			Models.part(self, ring, Models.mat(Color(0.8, 1.0, 0.9), 0.2, 0.0, 3.0))
		"clap":
			var ring := TorusMesh.new()
			ring.inner_radius = r * 0.7
			ring.outer_radius = r
			var air := StandardMaterial3D.new()
			air.albedo_color = Color(1, 0.95, 0.8, 0.5)
			air.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			air.emission_enabled = true
			air.emission = Color(1, 0.9, 0.6)
			air.emission_energy_multiplier = 0.8
			Models.part(self, ring, air, Vector3.ZERO, Vector3(PI / 2, 0, 0))
			Models.part(self, ring, air, Vector3(0, 0, 0.6), Vector3(PI / 2, 0, 0), Vector3.ONE * 0.6)
		"bolt":
			Models.part(self, Models.capsule(r * 0.6, r * 4.0), Models.mat(Color(1, 0.2, 0.15), 0.3, 0.0, 3.0),
				Vector3.ZERO, Vector3(PI / 2, 0, 0))
		"poo":
			Models.part(self, Models.sphere(r, 12), Models.mat(Color(0.43, 0.27, 0.12), 0.5))
			Models.part(self, Models.sphere(r * 0.5, 8), Models.mat(Color(0.58, 0.38, 0.18), 0.5), Vector3(-r * 0.3, r * 0.4, 0))


func tick(dt: float) -> void:
	age += dt
	life -= dt
	if life <= 0.0:
		kill(false)
		return
	vel.y -= grav * dt
	if homing:  # smart shot: steer towards the nearest target ahead
		var best = null
		var best_d := 40.0
		for e in game.targets():
			var to: Vector3 = e.center() - position
			if to.length() < best_d and to.normalized().dot(vel.normalized()) > -0.2:
				best_d = to.length()
				best = e
		if best != null:
			var want: Vector3 = (best.center() - position).normalized() * vel.length()
			vel = vel.lerp(want, min(1.0, 7.0 * dt))
	var nxt := position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(position, nxt, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit:
		position = hit.position
		kill(true)
		return
	position = nxt
	if vel.length() > 0.1:
		var f := vel.normalized()
		if abs(f.dot(Vector3.UP)) < 0.99:
			look_at(position + f, Vector3.UP)
	if kind == "clap":
		scale = Vector3.ONE * (1.0 + age * 1.5)
	if kind == "symbiote":
		for i in range(1, 4):
			var c := get_child(i) as Node3D
			var a := age * 12.0 + i * 2.1
			c.position = Vector3(cos(a), sin(a), 0) * radius * (0.9 + 0.2 * sin(age * 30.0))
	if owner_side == "player":
		for e in game.targets():
			if hit_ids.has(e.get_instance_id()):
				continue
			if position.distance_to(e.center()) < radius * scale.x + e.radius + 0.3:
				hit_ids[e.get_instance_id()] = true
				e.hurt(damage, vel, knock)
				if web_secs > 0.0 and is_instance_valid(e) and not e.dead:
					e.web(web_secs)
				if not pierce:
					kill(false)
					return
	else:
		var p = game.player
		if not p.dead and position.distance_to(p.center()) < radius + p.radius + 0.2:
			p.take_damage(damage, position, knock)
			kill(false)


func kill(hit_ground: bool) -> void:
	if dead:
		return
	dead = true
	match kind:
		"poo":
			game.burst(position, Color(0.45, 0.28, 0.12), 10, 6.0)
			game.audio.play("splat")
			if hit_ground:
				game.add_puddle(position)
		"symbiote":
			game.burst(position, Color(0.08, 0.08, 0.12), 8, 6.0)
		"smart":
			game.burst(position, Color(0.3, 1.0, 0.7), 8, 6.0)
		"web":
			game.burst(position, Color(0.95, 0.95, 1.0), 8, 5.0)
		_:
			game.burst(position, Color(1, 0.5, 0.2), 6, 5.0)
	queue_free()
