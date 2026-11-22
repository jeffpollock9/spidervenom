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
	match kind:
		"symbiote":
			var black := Models.mat(Models.VENOM_BLACK, 0.2, 0.3, 0.0, 0.8)
			Models.part(self, Models.sphere(r), black)
			for i in 3:
				Models.part(self, Models.sphere(r * 0.45, 8), black, Vector3(r, 0, 0))
			Models.part(self, Models.sphere(r * 0.25, 8), Models.mat(Color(0.4, 0.4, 0.65), 0.2), Vector3(-r * 0.4, r * 0.4, -r * 0.5))
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
	if kind == "symbiote":
		for i in range(1, 4):
			var c := get_child(i) as Node3D
			var a := age * 12.0 + i * 2.1
			c.position = Vector3(cos(a), sin(a), 0) * radius * (0.9 + 0.2 * sin(age * 30.0))
	if owner_side == "player":
		for e in game.targets():
			if hit_ids.has(e.get_instance_id()):
				continue
			if position.distance_to(e.center()) < radius + e.radius + 0.3:
				hit_ids[e.get_instance_id()] = true
				e.hurt(damage, vel, knock)
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
		_:
			game.burst(position, Color(1, 0.5, 0.2), 6, 5.0)
	queue_free()
