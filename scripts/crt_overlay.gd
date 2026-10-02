extends Control
## CRT 终端叠加层：扫描线、随机噪点、屏幕闪烁、暗角、滚动条。
## 纯 _draw 实现，只做视觉效果，不参与玩法。

const LINE_GAP := 3
const COL_SCAN := Color(0.0, 0.0, 0.0, 0.22)
const COL_NOISE := Color(0.2, 1.0, 0.4, 0.10)
const NOISE_CHARS := "01アイウエオ0123456789ABCDEF/#@$%&"
const COL_VIGNETTE := Color(0.0, 0.02, 0.0, 0.55)

var _font: Font
var _flicker := 0.0
var _next_flicker := 0.0
var _noise: Array[Dictionary] = []
var _scroll_y := 0.0


func _ready() -> void:
	_font = preload("res://scripts/mono_font.gd").get_mono()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_spawn_noise()
	set_process(true)


func _spawn_noise() -> void:
	_noise.clear()
	for i in 26:
		_noise.append({
			"pos": Vector2(randf(), randf()),
			"ttl": randf_range(0.02, 0.14),
		})


func _process(delta: float) -> void:
	_scroll_y = fmod(_scroll_y + delta * 26.0, float(LINE_GAP))
	_next_flicker -= delta
	if _next_flicker <= 0.0:
		_flicker = randf_range(0.0, 0.05)
		_next_flicker = randf_range(0.05, 0.35)
	for n in _noise:
		n["ttl"] = float(n["ttl"]) - delta
		if float(n["ttl"]) <= 0.0:
			n["pos"] = Vector2(randf(), randf())
			n["ttl"] = randf_range(0.02, 0.14)
	queue_redraw()


func _draw() -> void:
	var s := size

	# 扫描线：随时间轻微上下滚动
	var y := -_scroll_y
	while y < s.y:
		draw_line(Vector2(0, y), Vector2(s.x, y), COL_SCAN, 1.0)
		y += LINE_GAP

	# 随机噪点字符
	for n in _noise:
		var p: Vector2 = n["pos"] * s
		var glyph := NOISE_CHARS[randi() % NOISE_CHARS.length()]
		draw_string(_font, p, glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, COL_NOISE)

	# 屏幕闪烁：整屏轻微压暗
	if _flicker > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, _flicker))

	# 暗角：四边叠加渐暗的窄带
	var steps := 8
	var span := 70.0
	for i in steps:
		var f := float(i + 1) / float(steps)
		var a := COL_VIGNETTE.a * f * 0.22
		var c := Color(COL_VIGNETTE, a)
		var inset := span * f
		draw_rect(Rect2(0, inset, s.x, 2), c)
		draw_rect(Rect2(0, s.y - inset - 2, s.x, 2), c)
		draw_rect(Rect2(inset, 0, 2, s.y), c)
		draw_rect(Rect2(s.x - inset - 2, 0, 2, s.y), c)