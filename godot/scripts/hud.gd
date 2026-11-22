class_name Hud
extends Control
## Health/energy bars, progress to the boss, the boss bar, banners, crosshair and the
## title / pause / win / lose screens. Everything is drawn in _draw().

const CONTROLS := [
	["WASD / ARROWS", "Run (relative to the camera)"],
	["MOUSE", "Look around and aim"],
	["SPACE", "Jump. Press again in mid-air to FLY on symbiote wings"],
	["SPACE / CTRL (flying)", "Fly up / fly down"],
	["LEFT CLICK (J)", "Heavy punch"],
	["RIGHT CLICK (K)", "Symbiote blast at the crosshair"],
	["SHIFT (hold)", "Swing on a tendril (aim at a building, or up at the sky)"],
	["F (full energy)", "SYMBIOTE BLAST: wipes out every robot nearby"],
	["ESC", "Pause    F11 fullscreen    M music"],
]

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
	var p: Venom = game.player
	# hero panel
	var panel := Rect2(14, 14, 340, 100)
	draw_rect(panel, Color(0, 0, 0, 0.7))
	draw_rect(panel, Color(0.35, 0.35, 0.55), false, 3.0)
	text("VENOM", Vector2(30, 44), 26)
	bar(Rect2(30, 54, 300, 18), p.hp / Venom.MAX_HP, Color(0.9, 0.2, 0.25))
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
		text("WASD run   MOUSE look/aim   SPACE jump (again in the air: FLY)   LMB punch   RMB blast   SHIFT swing   F ultimate   ESC pause",
			Vector2(sz.x / 2, sz.y - 18), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
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
			text("Click or ESC: resume      R: restart      Q: quit", Vector2(sz.x / 2, sz.y / 2 + 10), 26,
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
				text("SPACE / ENTER: play again      ESC: quit", Vector2(sz.x / 2, sz.y / 2 + 100), 26,
					Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _draw_title(sz: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, sz), Color(0, 0, 0, 0.45))
	text("SPIDER", Vector2(sz.x / 2 - 8, 130), 110, Color(0.86, 0.1, 0.14), HORIZONTAL_ALIGNMENT_RIGHT, -1, 14)
	text("VENOMN", Vector2(sz.x / 2 + 8, 130), 110, Color(0.06, 0.06, 0.08), HORIZONTAL_ALIGNMENT_LEFT, -1, 0)
	_outline_white("VENOMN", Vector2(sz.x / 2 + 8, 130), 110)
	text("3D", Vector2(sz.x / 2, 200), 60, Color(1, 0.9, 0.3), HORIZONTAL_ALIGNMENT_CENTER, -1, 10)
	text("Venom vs Mr Poo in Supercity", Vector2(sz.x / 2, 250), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	var y := 310.0
	for row in CONTROLS:
		text(row[0], Vector2(sz.x / 2 - 30, y), 22, Color(1, 0.9, 0.45), HORIZONTAL_ALIGNMENT_RIGHT)
		text(row[1], Vector2(sz.x / 2 - 10, y), 22, Color.WHITE)
		y += 32
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() / 250.0)
	text("CLICK OR PRESS ANY KEY TO PLAY", Vector2(sz.x / 2, sz.y - 50), 34, Color(1, 1, 1, pulse),
		HORIZONTAL_ALIGNMENT_CENTER, -1, 8)


func _outline_white(s: String, pos: Vector2, size: int) -> void:
	draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 10, Color.WHITE)
	draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.06, 0.06, 0.08))
