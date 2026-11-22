class_name GameAudio
extends Node
## Synthesised sound effects and chiptune music, ported from the 2D game (no asset files).

const RATE := 22050
const SONGS := {
	# root note, scale, bpm, bass pattern, lead pattern
	"menu": [57, [0, 3, 5, 7, 10], 120, [0, 0, 3, 3, 4, 4, 2, 2], [4, 3, 2, 0, 2, 3, 4, 7]],
	"supercity": [62, [0, 2, 4, 5, 7, 9, 11], 150, [0, 0, 3, 3, 4, 4, 5, 4], [0, 2, 4, 6, 7, 6, 4, 2]],
	"boss": [52, [0, 1, 3, 5, 6, 8, 10], 165, [0, 0, 0, 1, 0, 0, 4, 3], [0, 3, 4, 3, 6, 4, 3, 1]],
}

var enabled := true
var music_on := true
var sounds := {}
var songs := {}
var current := ""
var music_player: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []


func _init(on := true) -> void:
	enabled = on


func _ready() -> void:
	if not enabled:
		return
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -5.0
	add_child(music_player)
	for i in 12:
		var p := AudioStreamPlayer.new()
		add_child(p)
		pool.append(p)
	_make_sfx()


static func note(n: float) -> float:
	return 440.0 * pow(2.0, (n - 69.0) / 12.0)


func _wav(samples: PackedFloat32Array, loop := false) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clamp(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = data
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = samples.size()
	return w


func _tone(f0: float, f1: float, dur: float, wave := "square", vol := 0.4, noise := 0.0,
		attack := 0.005) -> PackedFloat32Array:
	var n := int(RATE * dur)
	var out := PackedFloat32Array()
	out.resize(n)
	var phase := 0.0
	var rnd := RandomNumberGenerator.new()
	rnd.seed = int(f0 * 100 + dur * 1000)
	for i in n:
		var t := float(i) / n
		phase += (f0 + (f1 - f0) * t) / RATE
		var p := fposmod(phase, 1.0)
		var s: float
		match wave:
			"square": s = 1.0 if p < 0.5 else -1.0
			"saw": s = 2.0 * p - 1.0
			"tri": s = 4.0 * abs(p - 0.5) - 1.0
			_: s = sin(TAU * p)
		if noise > 0.0:
			s = s * (1.0 - noise) + rnd.randf_range(-1.0, 1.0) * noise
		var env: float = min(1.0, i / (RATE * attack + 1.0)) * pow(1.0 - t, 1.5)
		out[i] = s * vol * env
	return out


func _make_sfx() -> void:
	var defs := {
		"jump": [300, 600, 0.12, "square", 0.18, 0.0], "punch": [180, 60, 0.10, "square", 0.3, 0.6],
		"shoot": [900, 200, 0.08, "square", 0.22, 0.5], "blob": [200, 90, 0.2, "sine", 0.45, 0.2],
		"hit": [400, 100, 0.08, "square", 0.25, 0.4], "hurt": [500, 150, 0.25, "saw", 0.3, 0.0],
		"explode": [120, 30, 0.6, "square", 0.5, 0.85], "pickup": [600, 1300, 0.18, "tri", 0.3, 0.0],
		"roar": [140, 50, 0.9, "saw", 0.45, 0.5], "splat": [150, 50, 0.25, "sine", 0.5, 0.6],
		"select": [700, 1000, 0.06, "square", 0.2, 0.0], "flap": [120, 70, 0.12, "sine", 0.35, 0.4],
		"web": [1500, 500, 0.09, "saw", 0.16, 0.55],
	}
	for k in defs:
		var d: Array = defs[k]
		sounds[k] = _wav(_tone(d[0], d[1], d[2], d[3], d[4], d[5]))
	var win := PackedFloat32Array()
	for n in [72, 76, 79, 84]:
		win.append_array(_tone(note(n), note(n), 0.14, "square", 0.25))
	sounds["win"] = _wav(win)
	var lose := PackedFloat32Array()
	for n in [67, 63, 60, 55]:
		lose.append_array(_tone(note(n), note(n), 0.22, "tri", 0.35))
	sounds["lose"] = _wav(lose)


func play(name: String) -> void:
	if not enabled or not sounds.has(name):
		return
	for p in pool:
		if not p.playing:
			p.stream = sounds[name]
			p.play()
			return


func _make_song(key: String) -> AudioStreamWAV:
	var d: Array = SONGS[key]
	var root: int = d[0]
	var scale: Array = d[1]
	var bass: Array = d[3]
	var lead: Array = d[4]
	var n_step := int(RATE * 60.0 / d[2] / 2.0)
	var out := PackedFloat32Array()
	out.resize(4 * 16 * n_step)
	var idx := 0
	for bar in 4:
		var shift: int = [0, 0, 3, 4][bar]
		for i in 16:
			var fb := _deg(root, scale, bass[(i / 2) % bass.size()] + shift, -2)
			var fl := _deg(root, scale, lead[i % lead.size()] + shift + (2 if bar == 3 and i > 8 else 0), 0)
			var lead_on := (i + bar) % 3 != 2
			for s in n_step:
				var t := float(s) / RATE
				var env := pow(max(0.0, 1.0 - float(s) / n_step), 0.8)
				var v := (0.10 if fmod(t * fb, 1.0) < 0.5 else -0.10)
				if lead_on:
					v += (2.0 * fmod(t * fl, 1.0) - 1.0) * 0.06 * env
				if i % 4 == 0:
					v += sin(TAU * 60.0 * t) * 0.25 * max(0.0, 1.0 - s / (n_step * 0.4))
				out[idx] = v
				idx += 1
	return _wav(out, true)


func _deg(root: int, scale: Array, d: int, octave: int) -> float:
	var o := floori(float(d) / scale.size())
	var i := posmod(d, scale.size())
	return note(root + scale[i] + 12 * (o + octave))


func prepare(keys: Array) -> void:
	if not enabled:
		return
	for k in keys:
		if not songs.has(k):
			songs[k] = _make_song(k)


func music(key: String) -> void:
	if not enabled or key == current:
		return
	current = key
	if key == "" or not music_on:
		music_player.stop()
		return
	prepare([key])
	music_player.stream = songs[key]
	music_player.play()


func toggle_music() -> void:
	if not enabled:
		return
	music_on = not music_on
	var k := current
	current = ""
	if music_on:
		music(k)
	else:
		music_player.stop()
		current = k
