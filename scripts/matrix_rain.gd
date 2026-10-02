extends Node2D
## 黑客帝国风格的背景雨：随机列的绿色字符向下滚动。
## 纯 _draw 实现，无额外资源文件。
const MONO := preload("res://scripts/mono_font.gd")

const FONT_SIZE := 18
const GLYPH_POOL := "アイウエオカキクケコサシスセソタチツテトナニヌネノ0123456789"
const DENSE_COLOR := Color(0.0, 0.45, 0.2)
const HEAD_COLOR := Color(0.35, 1.0, 0.45)

var _font: Font
var _columns: Array[Dictionary] = []


func _ready() -> void:
	_font = MONO.get_mono()
	z_index = -10
	_build_columns(get_viewport_rect().size)
	get_viewport().size_changed.connect(_build_columns.bind(get_viewport_rect().size))
	set_process(true)


func _build_columns(view_size: Vector2) -> void:
	var count := maxi(1, int(view_size.x / float(FONT_SIZE)))
	_columns.clear()
	for i in count:
		_columns.append({
			"x": float(i * FONT_SIZE) + randf_range(0.0, 6.0),
			"head": randf_range(-view_size.y, view_size.y),
			"len": randi_range(6, 22),
			"speed": randf_range(35.0, 110.0),
			"chars": _random_glyphs(randi_range(8, 20)),
		})


func _random_glyphs(n: int) -> String:
	var s := ""
	for i in n:
		s += GLYPH_POOL[randi() % GLYPH_POOL.length()]
	return s


func _process(delta: float) -> void:
	var view_h := get_viewport_rect().size.y
	for col in _columns:
		col["head"] += float(col["speed"]) * delta
		if col["head"] - float(col["len"]) * float(FONT_SIZE + 6) > view_h:
			col["head"] = randf_range(-view_h, 0.0)
			col["len"] = randi_range(6, 22)
			col["speed"] = randf_range(35.0, 110.0)
			col["chars"] = _random_glyphs(randi_range(8, 20))
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	for col in _columns:
		var glyphs := String(col["chars"])
		for i in col["len"]:
			var y: float = col["head"] - float(i) * float(FONT_SIZE + 6)
			if y < -float(FONT_SIZE) or y > view.y:
				continue
			var ch := glyphs[i % glyphs.length()]
			var alpha := 1.0 - float(i) / float(col["len"])
			var color := HEAD_COLOR if i == 0 else DENSE_COLOR
			color.a = alpha * 0.55
			draw_string(_font, Vector2(col["x"], y), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE, color)