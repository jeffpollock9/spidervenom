class_name Spiderman
extends Hero
## Spider-Man: smaller, faster and nimbler than Venom. The best web-swinger in Supercity,
## crawls up walls, somersaults in mid-air, webs robots up so they can't move, and at full
## energy unleashes a WEB STORM that webs up everything nearby.


func _setup() -> void:
	hero_name = "SPIDER-MAN"
	colour = Color(1.0, 0.35, 0.35)
	size = Models.SPIDEY_SIZE
	max_hp = 110.0
	speed = 11.5
	jump = 14.0
	punch_damage = 13.0
	punch_reach = 2.4
	punch_cd = 0.24
	blast_cost = 9.0
	swing_cost = 1.5
	swing_max_speed = 40.0
	swing_pull = 24.0
	rope_radius = 0.035
	can_climb = true
	air_jumps = 1
	ult_ready_text = "F: WEB STORM READY!"
	hint = "WASD run (into a wall: CLIMB)   MOUSE look/aim   SPACE jump (again: FLIP)   LMB punch   RMB web shot   SHIFT web-swing   F ultimate   ESC pause"


func _build_model() -> Dictionary:
	return Models.spiderman()


func _rope_material() -> Material:
	return Models.mat(Color(0.95, 0.95, 0.98), 0.4, 0.0, 0.2)


func _swing_sound() -> String:
	return "web"


func special() -> void:
	## Web shot: a sticky ball of web that leaves a robot stuck fast for a few seconds.
	_face_aim()
	energy -= blast_cost
	cd = 0.28
	shoot_t = 0.25
	var from := hand()
	var dir := (aim - from).normalized()
	game.spawn_projectile(from, dir * 46.0, "player", "web", 10.0, 0.35, {"knock": 3.0, "life": 1.2, "web": 3.5})
	game.audio.play("web")


func _ultimate_effect() -> void:
	game.web_storm(center())
