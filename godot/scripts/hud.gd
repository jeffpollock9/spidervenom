class_name Hud
extends Control
## Health/energy bars, progress to the boss, the boss bar, banners, crosshair and the
## title / pause / win / lose screens. Everything is drawn in _draw().

const COMMON := [
	["WASD / ARROWS", "Run (relative to the camera)"],
	["MOUSE", "Look around and aim"],
	["LEFT CLICK (J)", "Punch"],
	["ESC", "Pause    F11 fullscreen    M music"],
]
const HERO_INFO := {
	"venom": {
		"title": "VENOM",
		"blurb": "A huge symbiote brute. Hits like a truck, flies on wings.",
		"colour": Color(0.75, 0.78, 1.0),
		"stats": [["POWER", 5], ["SPEED", 3], ["HEALTH", 4], ["SMART", 1], ["LOOKS", 1]],
		"controls": [
			["SPACE", "Jump. Press again in mid-air to FLY on symbiote wings"],
			["SPACE / CTRL", "Fly up / fly down"],
			["RIGHT CLICK (K)", "Symbiote blast at the crosshair"],
			["SHIFT (hold)", "Swing on a tendril"],
			["F (full energy)", "SYMBIOTE BLAST: wipes out every robot nearby"],
		],
	},
	"spiderman": {
		"title": "SPIDER-MAN",
		"blurb": "Fast and nimble. The best web-swinger in Supercity.",
		"colour": Color(1.0, 0.35, 0.35),
		"stats": [["POWER", 2], ["SPEED", 4], ["HEALTH", 3], ["SMART", 4], ["LOOKS", 3]],
		"controls": [
			["SPACE", "Jump. Press again in mid-air to SOMERSAULT"],
			["RUN INTO A WALL", "Crawl up it (SPACE leaps off, CTRL climbs down)"],
			["RIGHT CLICK (K)", "Web shot: robots get stuck fast"],
			["SHIFT (hold)", "Web-swing (aim at a building, or up at the sky)"],
			["F (full energy)", "WEB STORM: webs up every robot nearby"],
		],
	},
	"jamiesdad": {
		"title": "JAMIE'S DAD",
		"blurb": "Huge muscles, really good looking, super strong, super fast.",
		"colour": Color(1.0, 0.82, 0.35),
		"stats": [["POWER", 5], ["SPEED", 5], ["HEALTH", 5], ["SMART", 4], ["LOOKS", 5]],
		"controls": [
			["SHIFT (hold)", "SUPER-SPRINT: flatten anything you run into"],
			["SPACE", "Super jump"],
			["CTRL (in the air)", "GROUND POUND: smash everything round you"],
			["LEFT CLICK (J)", "Super punch: sends robots flying"],
			["RIGHT CLICK (K)", "Thunder clap: a shockwave through every robot"],
			["F (full energy)", "DAD SMASH: knocks out every robot nearby"],
			["SUPER HEALTH", "Tons of it, and it heals itself back up"],
		],
	},
	"jamie": {
		"title": "JAMIE",
		"blurb": "Invincible, very good looking, very smart, very strong.",
		"colour": Color(0.35, 1.0, 0.8),
		"stats": [["POWER", 4], ["SPEED", 4], ["HEALTH", 99], ["SMART", 5], ["LOOKS", 5]],
		"controls": [
			["INVINCIBLE", "Nothing can hurt him. Ever."],
			["SHIFT (hold)", "Jetpack he built himself (uses energy)"],
			["LEFT CLICK (J)", "Strong punch"],
			["RIGHT CLICK (K)", "Smart shot: it aims itself at the nearest robot"],
			["F (full energy)", "GENIUS HACK: every robot nearby shuts down and blows up"],
		],
	},
	"charley": {
		"title": "CHARLEY",
		"blurb": "Really, really weak. But very good at calling for help.",
		"colour": Color(1.0, 0.85, 0.3),
		"stats": [["POWER", 0], ["SPEED", 1], ["HEALTH", 1], ["SMART", 3], ["LOOKS", 3]],
		"controls": [
			["LEFT CLICK (J)", "Punch. It tickles."],
			["RIGHT CLICK (K)", "Throw a sock"],
			["RUNNING", "Gets puffed out after a few seconds"],
			["SHIFT (hold)", "HIDE: robots stop bothering with him"],
			["F (full energy)", "CALL FOR HELP: Jamie's Dad drops in and smashes everything"],
		],
	},
}

var game
var font: Font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_dt: float) -> void:
	queue_redraw()


func text(s: String, pos: Vector2, size: int, colour := Color.WHITE, align := HORIZONTAL_ALIGNMENT_LEFT,
		width := -1.0, outline := 6) -> void:
	if align != HORIZONTAL_ALIGNMENT_LEFT and width < 0:
		width = 2000.0
		pos.x -= 1000.0 if align == HORIZONTAL_ALIGNMENT_CENTER else 2000.0
	if outline > 0:
		draw_string_outline(font, pos, s, align, width, size, outline, Color(0, 0, 0, colour.a))
	draw_string(font, pos, s, align, width, size, colour)


func bar(rect: Rect2, frac: float, colour: Color) -> void:
	draw_rect(rect.grow(3), Color.BLACK)
	draw_rect(rect, Color(0.25, 0.25, 0.25))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clamp(frac, 0.0, 1.0), rect.size.y)), colour)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var sz := get_viewport_rect().size
	match game.state:
		"title":
			_draw_title(sz)
			return
		"select":
			_draw_select(sz)
			return
	var p: Hero = game.player
	# hero panel
	var panel := Rect2(14, 14, 340, 100)
	draw_rect(panel, Color(0, 0, 0, 0.7))
	draw_rect(panel, Color(0.35, 0.35, 0.55), false, 3.0)
	text(p.hero_name, Vector2(30, 44), 26, p.colour)
	if p.invincible:
		bar(Rect2(30, 54, 300, 18), 1.0, Color(1.0, 0.8, 0.25))
		text("INVINCIBLE", Vector2(36, 69), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	else:
		bar(Rect2(30, 54, 300, 18), p.hp / p.max_hp, Color(0.9, 0.2, 0.25))
		text(str(int(p.hp)), Vector2(36, 69), 16, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT, -1, 4)
	bar(Rect2(30, 80, 300, 10), p.energy / 100.0, Color(0.27, 0.67, 1.0))
	var info := p.info_line()
	if info != "":
		text(info, Vector2(30, 108), 18, Color(1, 0.9, 0.45))
	# city + score + progress
	text("SUPERCITY", Vector2(sz.x - 20, 44), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_RIGHT)
	text("SCORE %d" % game.score, Vector2(sz.x - 20, 74), 22, Color(1, 0.9, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
	var prog: float = game.level.progress(p.global_position.x)
	var pb := Rect2(sz.x / 2 - 200, 22, 400, 8)
	draw_rect(pb, Color.BLACK)
	draw_rect(Rect2(pb.position, Vector2(pb.size.x * prog, pb.size.y)), Color(1, 0.9, 0.45))
	draw_circle(Vector2(pb.end.x + 8, 26), 9, Color(0.9, 0.15, 0.15))
	text("BOSS", Vector2(pb.end.x + 8, 52), 14, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# boss bar
	var b = game.boss
	if game.gate_closed and is_instance_valid(b) and not b.dead:
		text("MR POO", Vector2(sz.x / 2, sz.y - 64), 28, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		bar(Rect2(sz.x / 2 - 350, sz.y - 50, 700, 22), b.hp / b.max_hp,
			Color(0.9, 0.15, 0.15) if b.phase == 1 else Color(1, 0.5, 0.1))
	# message over the hero
	if p.message_t > 0.0:
		text(p.message, Vector2(sz.x / 2, sz.y / 2 + 120), 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# crosshair
	if game.state == "play":
		var c := sz / 2
		draw_arc(c, 10, 0, TAU, 24, Color.BLACK, 4.0)
		draw_arc(c, 10, 0, TAU, 24, Color.WHITE, 2.0)
		for d in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
			draw_line(c + d * 6, c + d * 15, Color.WHITE, 2.0)
	# controls reminder for the first few seconds
	if game.t < 8.0 and game.state == "play":
		text(p.hint, Vector2(sz.x / 2, sz.y - 18), 17, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	# banner
	if game.banner_t > 0.0 and game.banner_text != "":
		var a: float = min(1.0, game.banner_t * 2.0)
		var col := Color(1, 0.3, 0.3, a) if game.state == "lost" else Color(1, 0.9, 0.3, a)
		text(game.banner_text, Vector2(sz.x / 2, sz.y / 2 - 90 - (1.0 - a) * 30), 72, col,
			HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
	match game.state:
		"paused":
			draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.6))
			text("PAUSED", Vector2(sz.x / 2, sz.y / 2 - 60), 80, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
			text("Click or ESC: resume      R: restart      H: change hero      Q: quit", Vector2(sz.x / 2, sz.y / 2 + 10), 26,
				Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
		"won", "lost":
			if game.finished != "":
				draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.6))
				var won: bool = game.state == "won"
				text("SUPERCITY IS SAVED!" if won else "DEFEATED!", Vector2(sz.x / 2, sz.y / 2 - 70), 80,
					Color(1, 0.9, 0.3) if won else Color(1, 0.3, 0.3), HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
				text("You beat Mr Poo!" if won else "Mr Poo rules Supercity... for now.", Vector2(sz.x / 2, sz.y / 2 - 10),
					34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
				text("SCORE %d     TIME %d:%02d" % [game.score, int(game.t) / 60, int(game.t) % 60],
					Vector2(sz.x / 2, sz.y / 2 + 40), 28, Color(1, 0.9, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
				text("SPACE / ENTER: play again      H: change hero      ESC: quit", Vector2(sz.x / 2, sz.y / 2 + 100), 26,
					Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_title(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.45))
	text("SPIDER", Vector2(sz.x / 2 - 8, 130), 110, Color(0.86, 0.1, 0.14), HORIZONTAL_ALIGNMENT_RIGHT, -1, 14)
	text("VENOMN", Vector2(sz.x / 2 + 8, 130), 110, Color(0.06, 0.06, 0.08), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	_outline_white("VENOMN", Vector2(sz.x / 2 + 8, 130), 110)
	text("3D", Vector2(sz.x / 2, 200), 60, Color(1, 0.9, 0.3), HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	text("Save Supercity from Mr Poo!", Vector2(sz.x / 2, 250), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	text("Play as VENOM, SPIDER-MAN, JAMIE'S DAD, JAMIE or CHARLEY", Vector2(sz.x / 2, 330), 30, Color(1, 0.9, 0.45), HORIZONTAL_ALIGNMENT_CENTER)
	var y := 400.0
	for row in COMMON:
		text(row[0], Vector2(sz.x / 2 - 30, y), 22, Color(1, 0.9, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
		text(row[1], Vector2(sz.x / 2 - 10, y), 22, Color.WHITE)
		y += 32
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
	text("CLICK OR PRESS ANY KEY TO PLAY", Vector2(sz.x / 2, sz.y - 50), 34, Color(1, 1, 1, pulse),
		HORIZONTAL_ALIGNMENT_CENTER, -1, 8)


func _draw_select(sz: Vector2) -> void:
	## The chosen hero stands on the right (it's the real 3D model); his details on the left.
	draw_rect(Rect2(0, 0, sz.x * 0.52, sz.y), Color(0, 0, 0, 0.62))
	text("CHOOSE YOUR HERO", Vector2(40, 62), 44, Color(1, 0.9, 0.3), HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	var heroes: Array = game.HEROES
	var x := 40.0
	for i in heroes.size():  # tabs
		var info: Dictionary = HERO_INFO[heroes[i]]
		var chosen: bool = heroes[i] == game.hero_id
		var w := 118.0
		var r := Rect2(x, 86, w, 44)
		draw_rect(r, Color(info["colour"], 0.35) if chosen else Color(0.15, 0.15, 0.2, 0.8))
		draw_rect(r, info["colour"] if chosen else Color(0.4, 0.4, 0.5), false, 3.0 if chosen else 1.5)
		text("%d %s" % [i + 1, info["title"]], Vector2(x + 6, 115), 14, Color.WHITE if chosen else Color(0.7, 0.7, 0.75))
		x += w + 6
	var hi: Dictionary = HERO_INFO[game.hero_id]
	text(hi["title"], Vector2(40, 200), 64, hi["colour"], HORIZONTAL_ALIGNMENT_LEFT, -1, 10)
	text(hi["blurb"], Vector2(40, 240), 22, Color.WHITE)
	var y := 284.0
	for st in hi["stats"]:
		text(st[0], Vector2(40, y + 16), 20, Color(1, 0.9, 0.45))
		if st[1] > 5:  # off the scale
			text("INVINCIBLE", Vector2(150, y + 17), 20, hi["colour"])
		else:
			for k in 5:
				draw_rect(Rect2(150 + k * 34, y, 28, 18), hi["colour"] if k < st[1] else Color(0.25, 0.25, 0.3))
		y += 28
	y += 24
	for row in hi["controls"]:
		text(row[0], Vector2(40, y), 19, Color(1, 0.9, 0.45))
		text(row[1], Vector2(250, y), 19, Color.WHITE)
		y += 30
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
	text("A / D or 1-%d: change hero      SPACE / CLICK: PLAY" % heroes.size(), Vector2(40, sz.y - 40), 24,
		Color(1, 1, 1, pulse))


func _outline_white(s: String, pos: Vector2, size: int) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color.WHITE)
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.06, 0.06, 0.08))
