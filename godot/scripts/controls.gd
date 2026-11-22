class_name Controls
extends RefCounted
## One frame of player intent, from the keyboard and mouse or from the selftest bot.

var move := Vector2.ZERO   # x: strafe right, y: forward (relative to the camera)
var jump_pressed := false
var jump_held := false
var down_held := false
var primary_pressed := false
var special_pressed := false
var alt_pressed := false
var alt_held := false
var ult_pressed := false
var aim_override = null    # Vector3 world point the bot aims at, or null to use the camera


static func from_input() -> Controls:
	var c := Controls.new()
	c.move = Input.get_vector("move_left", "move_right", "move_back", "move_forward")
	c.jump_pressed = Input.is_action_just_pressed("jump")
	c.jump_held = Input.is_action_pressed("jump")
	c.down_held = Input.is_action_pressed("descend")
	c.primary_pressed = Input.is_action_just_pressed("attack")
	c.special_pressed = Input.is_action_just_pressed("power")
	c.alt_pressed = Input.is_action_just_pressed("swing")
	c.alt_held = Input.is_action_pressed("swing")
	c.ult_pressed = Input.is_action_just_pressed("ultimate")
	return c


static func setup_input_map() -> void:
	var keys := {
		"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"jump": [KEY_SPACE], "descend": [KEY_CTRL, KEY_C],
		"attack": [KEY_J], "power": [KEY_K, KEY_Q], "swing": [KEY_SHIFT, KEY_E],
		"ultimate": [KEY_F, KEY_X], "pause": [KEY_ESCAPE, KEY_P],
		"restart": [KEY_R], "music": [KEY_M], "fullscreen": [KEY_F11],
	}
	var mouse := {"attack": MOUSE_BUTTON_LEFT, "power": MOUSE_BUTTON_RIGHT, "ultimate": MOUSE_BUTTON_MIDDLE}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in keys[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in mouse:
		var m := InputEventMouseButton.new()
		m.button_index = mouse[action]
		InputMap.action_add_event(action, m)
