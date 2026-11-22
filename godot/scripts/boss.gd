class_name Boss
extends CharacterBody3D
## What every boss shares: health and the angry phase, getting hurt, webbed (Spider-Man) and
## dazed (Jamie, the Hacker), and being defeated. Mr Poo and Ms Cattoon extend this.

const GRAVITY := 30.0

var game
var boss_name := "BOSS"
var max_hp := 610.0
var hp := 610.0
var contact := 16.0
var radius := 2.3
var height := 4.4
var model: Dictionary
var state := "idle"
var timer := 1.0
var t := 0.0
var flash := 0.0
var phase := 1
var active := false
var dead := false
var face_yaw := PI / 2
var rng := RandomNumberGenerator.new()
var stun_t := 0.0
var cocoon: Node3D


func _init(g) -> void:
	game = g
	collision_layer = 8
	collision_mask = 1 | 16  # the world, plus the plaza platforms (layer 16)
	rng.randomize()


func center() -> Vector3:
	return global_position + Vector3(0, height * 0.45, 0)


func hurt(dmg: float, _push: Vector3, _knock := 0.0) -> void:
	if not active or dead:
		return
	hp -= dmg
	flash = 0.1
	game.popup(center() + Vector3.UP * (height * 0.55), str(int(dmg)), Color(1, 0.9, 0.3))
	if phase == 1 and hp <= max_hp / 2:
		phase = 2
		game.audio.play("roar")
		game.shake(0.5)
		game.banner("%s is ANGRY!" % boss_name, 1.5)
		_angry()
	if hp <= 0.0:
		hp = 0.0
		dead = true
		game.boss_defeated(self)


func _angry() -> void:
	pass


func web(secs: float) -> void:
	## Webs only hold a boss for a moment.
	if not active or dead:
		return
	stun_t = max(stun_t, secs * 0.35)
	if cocoon == null:
		cocoon = Models.web_cocoon(radius * 1.15, height * 1.05)
		cocoon.position.y = height * 0.5
		add_child(cocoon)
	cocoon.visible = true


func daze(secs: float) -> void:
	## Frozen on the spot for a moment, no web.
	if active and not dead:
		stun_t = max(stun_t, secs)


func _tick_stun(dt: float) -> bool:
	## Counts down a web / daze. True while the boss is stuck.
	if stun_t <= 0.0:
		return false
	stun_t -= dt
	if stun_t <= 0.0 and cocoon:
		cocoon.visible = false
	return true


func _go(s: String, tm: float) -> void:
	state = s
	timer = tm


func tick(_dt: float) -> void:
	pass
