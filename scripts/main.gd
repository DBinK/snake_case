extends Node2D
## 主场景：终端风格的界面外壳。
## 布局背景雨、棋盘、CRT 叠加层与命令行 HUD。

const SNAKE_SCRIPT := preload("res://scripts/snake_game.gd")
const RAIN_SCRIPT := preload("res://scripts/matrix_rain.gd")
const CRT_SCRIPT := preload("res://scripts/crt_overlay.gd")
const MONO := preload("res://scripts/mono_font.gd")

const GREEN := Color(0.25, 1.0, 0.35)
const DIM_GREEN := Color(0.0, 0.7, 0.3)
const YELLOW := Color(1.0, 0.9, 0.2)
const RED := Color(1.0, 0.3, 0.25)

var _snake: Node2D
var _log_label: Label
var _score_label: Label
var _title_label: Label
var _status_label: Label
var _help_label: Label
var _typed := ""
var _typed_target := ""
var _type_timer := 0.0
var _font: Font


func _ready() -> void:
	_font = MONO.get_mono()

	var rain := Node2D.new()
	rain.set_script(RAIN_SCRIPT)
	rain.name = "MatrixRain"
	add_child(rain)

	_snake = Node2D.new()
	_snake.set_script(SNAKE_SCRIPT)
	_snake.name = "Snake"
	add_child(_snake)
	_snake.score_changed.connect(_on_score_changed)
	_snake.game_over.connect(_on_game_over)
	_snake.game_started.connect(_on_game_started)
	_snake.cell_eaten.connect(_on_cell_eaten)

	_build_hud()
	_layout()
	get_viewport().size_changed.connect(_layout)
	_on_score_changed(0)
	_set_status("> boot: snake.sys loaded... press any key to run")


func _make_label(text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	layer.name = "HUD"
	add_child(layer)

	_log_label = _make_label("", 14, Color(GREEN, 0.75))
	_log_label.name = "Log"
	layer.add_child(_log_label)

	_title_label = _make_label("S N A K E . S Y S", 26, GREEN)
	_title_label.name = "Title"
	layer.add_child(_title_label)

	_score_label = _make_label("SCORE 0000 | KILLS 0", 18, YELLOW)
	_score_label.name = "Score"
	layer.add_child(_score_label)

	_status_label = _make_label("", 18, DIM_GREEN)
	_status_label.name = "Status"
	layer.add_child(_status_label)

	_help_label = _make_label("WASD/ARROWS: MOVE PROCESS | ANY KEY: RESTART", 13, Color(GREEN, 0.5))
	_help_label.name = "Help"
	layer.add_child(_help_label)

	var crt := Control.new()
	crt.name = "CRT"
	crt.set_script(CRT_SCRIPT)
	layer.add_child(crt)


func _layout() -> void:
	var view := get_viewport_rect().size
	var board: Vector2 = _snake.board_size()
	# 上方留标题与分数，下方留提示行
	var top := 110.0
	var bottom := 80.0
	var origin := Vector2(
		roundf((view.x - board.x) * 0.5),
		roundf(clampf((view.y - board.y) * 0.5, top, view.y - board.y - bottom))
	)
	_snake.position = origin

	_title_label.position = Vector2(0, origin.y - 92)
	_title_label.size = Vector2(view.x, 36)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_score_label.position = Vector2(origin.x, origin.y - 46)
	_score_label.size = Vector2(board.x, 28)
	_score_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

	_status_label.position = Vector2(0, origin.y + board.y + 22)
	_status_label.size = Vector2(view.x, 28)
	_status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_help_label.position = Vector2(0, origin.y + board.y + 54)
	_help_label.size = Vector2(view.x, 24)
	_help_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	_log_label.position = Vector2(24, 16)
	_log_label.size = Vector2(view.x - 48, 40)

	# CRT 叠加层铺满整个视口；CanvasLayer 下的 Control 不会自动拉伸
	var crt := get_node("HUD/CRT") as Control
	if crt != null:
		crt.position = Vector2.ZERO
		crt.size = view


## 打字机效果：逐字吐出状态行
func _set_status(text: String) -> void:
	_typed_target = text
	_typed = ""
	_type_timer = 0.0


func _process(delta: float) -> void:
	if _typed == _typed_target:
		return
	_type_timer -= delta
	while _type_timer <= 0.0 and _typed.length() < _typed_target.length():
		_typed += _typed_target[_typed.length()]
		_type_timer += 0.012
	_status_label.text = _typed


func _on_score_changed(score: int) -> void:
	_score_label.text = "SCORE %04d | KILLS %d" % [score, _snake.kills]


func _on_cell_eaten(_pos: Vector2i) -> void:
	_log_label.text = "[OK] packet purged at %04d  //  integrity restored" % _snake.kills


func _on_game_started() -> void:
	_set_status("> scan: hostile packet acquired. terminate it.")
	_status_label.add_theme_color_override("font_color", DIM_GREEN)
	_log_label.add_theme_color_override("font_color", Color(GREEN, 0.75))


func _on_game_over(score: int) -> void:
	_set_status("> FATAL: process killed // SCORE %04d // press any key" % score)
	_status_label.add_theme_color_override("font_color", RED)
	_log_label.text = "[ERR] segfault at 0x%08X // threads leaked: %d" % [randi(), _snake.kills]
	_log_label.add_theme_color_override("font_color", Color(RED, 0.8))