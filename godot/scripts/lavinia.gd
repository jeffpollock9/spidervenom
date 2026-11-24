class_name Lavinia
extends Hero
## Lavinia: she LOOKS strong (huge arms... they're blow-up ones) but she's not, and she LOOKS
## smart (big glasses, a big book) but she's not. Her punches go "boing". RIGHT CLICK she
## throws her book and says something clever (it's wrong). SHIFT she flexes, and the robots,
## who think she's really strong, run away scared. At full energy she has a BRILLIANT PLAN:
## throw everything she owns at them. It actually works.

const FLEX_COST := 15.0
const FACTS := [
	"2 + 2 = FISH!",
	"The sun is a big lemon!",
	"Robots are scared of Tuesdays!",
	"Gravity is optional!",
	"Clouds are sheep that float!",
	"A triangle has 7 sides!",
	"Water is just wet air!",
	"The moon is made of cheese. FACT!",
	"Robots can't count past 3!",
]
const BRAGS := ["Feel my STRENGTH!", "Ow, my wrist!", "Too strong for you!", "Did that hurt? No?"]

var fact_i := 0
var flex_t := 0.0
var bulb_t := 0.0


func _setup() -> void:
	hero_name = "Lavinia"
	colour = Color(0.8, 0.45, 1.0)
	size = Models.LAVINIA_SIZE
	max_hp = 70.0
	speed = 8.0
	jump = 11.0
	punch_damage = 5.0
	punch_reach = 2.0
	punch_cd = 0.45
	punch_knock = 1.0
	blast_cost = 12.0
	custom_shift = true
	ult_ready_text = "F: BRILLIANT PLAN READY!"
	hint = "WASD run   MOUSE look/aim   SPACE jump   LMB punch (boing)   RMB throw her book   SHIFT flex (scares robots)   F brilliant plan"


func _build_model() -> Dictionary:
	return Models.lavinia()


func info_line() -> String:
	if flex_t > 0.0:
		return "FLEXING"
	return super()


func _pre_tick(ctl: Controls, dt: float) -> void:
	flex_t = max(0.0, flex_t - dt)
	bulb_t = max(0.0, bulb_t - dt)
	if ctl.alt_pressed and not dead:
		flex()


func punch() -> int:
	var hits := super()
	if hits > 0:
		game.popup(hand() + Vector3.UP * 0.5, "boing!", Color(1, 0.75, 0.95))
		game.audio.play("boing")
		if randf() < 0.4:
			say(BRAGS[randi() % BRAGS.size()], 1.2)
	return hits


func special() -> void:
	## Throws her big clever book, and tells everyone something clever (it's wrong).
	_face_aim()
	energy -= blast_cost
	cd = 0.5
	shoot_t = 0.3
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 20.0 + Vector3.UP * 2.0, "player", "junk", 10.0, 0.3,
		{"gravity": 9.0, "life": 2.0, "knock": 3.0, "junk": 0})
	say("Did you know? " + FACTS[fact_i % FACTS.size()], 1.8)
	fact_i += 1
	game.audio.play("whoosh")


func flex() -> void:
	## Robots think she's really strong and run away scared. Bosses aren't fooled.
	if flex_t > 0.0:
		return
	if energy < FLEX_COST:
		say("Need energy!")
		return
	energy -= FLEX_COST
	flex_t = 1.0
	say("LOOK AT THESE MUSCLES!", 1.2)
	game.audio.play("boing")
	for e in game.targets():
		if e.center().distance_to(center()) > 12.0:
			continue
		if e == game.boss:
			game.popup(e.center() + Vector3.UP * 3.0, "...meh.", Color(0.8, 0.8, 0.8))
			continue
		e.scare(3.0)
		game.popup(e.center() + Vector3.UP * 1.5, "EEK!", Color(1, 1, 1))


func _ultimate_effect() -> void:
	## BRILLIANT PLAN: throw everything she's got. Somehow it works.
	bulb_t = 2.2
	say("I HAVE A BRILLIANT PLAN!", 2.0)
	game.banner("BRILLIANT PLAN!", 1.3)
	game.audio.play("ding")
	var fwd := Vector3(-sin(face_yaw), 0, -cos(face_yaw))
	var side := fwd.cross(Vector3.UP)
	var near: Array = []  # by sheer luck, everything lands on a baddie
	for e in game.targets():
		if e != game.boss and e.center().distance_to(center()) < 35.0:
			near.append(e)
	var boss_near: bool = game.boss and game.boss.active and not game.boss.dead \
		and game.boss.center().distance_to(center()) < 35.0
	var from := center() + Vector3.UP * 0.5
	for i in 16:
		var v: Vector3
		var at = null
		if boss_near and (near.is_empty() and i % 4 == 0 or i % 8 == 0):
			at = game.boss  # a few things even land on the boss
		elif not near.is_empty():
			at = near[i % near.size()]
		if at == null:
			var spread := (float(i) / 15.0 - 0.5) * 2.2
			v = (fwd + side * spread).normalized() * randf_range(14.0, 24.0) + Vector3.UP * randf_range(6.0, 10.0)
		else:
			var tp: Vector3 = at.center() + Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
			var tf := randf_range(0.8, 1.2)
			var g := 14.0
			v = Vector3((tp.x - from.x) / tf, (tp.y - from.y + 0.5 * g * tf * tf) / tf, (tp.z - from.z) / tf)
		game.spawn_projectile(from, v, "player", "junk", 36.0, 0.45,
			{"gravity": 14.0, "life": 3.0, "splash": 3.0, "knock": 10.0, "junk": i})


func _animate_extra(dt: float) -> void:
	var arm_l: Node3D = model["arm_l"]
	var arm_r: Node3D = model["arm_r"]
	var fore_l: Node3D = model["fore_l"]
	var fore_r: Node3D = model["fore_r"]
	if flex_t > 0.0:  # the double-bicep pose
		arm_l.rotation = Vector3(0, 0, -1.5)
		arm_r.rotation = Vector3(0, 0, 1.5)
		fore_l.rotation = Vector3(0, 0, -1.9)
		fore_r.rotation = Vector3(0, 0, 1.9)
	else:
		fore_l.rotation.z = 0.0
		fore_r.rotation.z = 0.0
	(model["book"] as Node3D).visible = shoot_t <= 0.0  # it's in the air
	var bulb: Node3D = model["bulb"]
	bulb.visible = bulb_t > 0.0
	if bulb.visible:
		bulb.scale = Vector3.ONE * (1.0 + 0.15 * sin(t * 20.0))
	(model["ponytail"] as Node3D).rotation.x = sin(t * 3.0 + walk_phase) * 0.25 - min(0.6, Vector2(velocity.x, velocity.z).length() * 0.05)
