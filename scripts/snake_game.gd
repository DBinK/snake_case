extends Node2D
## 贪吃蛇核心玩法：网格、蛇、食物、碰撞与计分。
## 视觉上整个棋盘是一块终端字符屏幕，蛇身由数据字符组成。

signal score_changed(score: int)
signal game_over(score: int)
signal game_started
signal cell_eaten(pos: Vector2i)

const MONO := preload("res://scripts/mono_font.gd")

const COLS := 24
const ROWS := 15
const CELL := 30
const GLYPH_SIZE := 20
const BASE_SPEED := 5.0  ## 每秒移动的格子数
const MAX_SPEED := 13.0
const WAVE_TIME := 0.55     ## 冲击波时长（秒）
const WAVE_RADIUS := 5      ## 冲击波最大半径（格）

enum Dir { UP, DOWN, LEFT, RIGHT }


var score := 0
var kills := 0
var running := false
var _dead := false  ## 是否已阵亡，决定蛇身是否显示为红色错误

var _snake: Array[Vector2i] = []
var _food := Vector2i.ZERO
var _dir := Dir.RIGHT
var _pending_dir := Dir.RIGHT
var _move_accum := 0.0
var _step_time := 1.0 / BASE_SPEED
var _font: Font

## 蛇身字符池：半角片假名与十六进制字符，像内存里游走的数据
const BODY_GLYPHS := "アイウエオｱｲｳ0123456789ABCDEF#@$%&*+-=<>[]{}"
## 空格子上的残留噪声字符
const NOISE_GLYPHS := "01アイウエオカキクケｱｲｳ0123456789ABCDEF/#@$%&"
## 冲击波字符池：十六进制与符号，像被扫描到的数据碎片
const WAVE_GLYPHS := "0123456789ABCDEF#$%&*+-/\\|<>[]{}"
const HEAD_GLYPH := "@"
const FOOD_GLYPH := "$"

# 配色
const COL_BG := Color(0.0, 0.03, 0.0)
const COL_GRID := Color(0.0, 0.16, 0.08)
const COL_BORDER := Color(0.0, 0.85, 0.32)
const COL_BODY := Color(0.2, 1.0, 0.35)
const COL_HEAD := Color(0.8, 1.0, 0.85)
const COL_FOOD := Color(1.0, 0.95, 0.2)
const COL_NOISE := Color(0.0, 0.5, 0.22)
const COL_ERROR := Color(1.0, 0.25, 0.2)
const COL_WAVE_FRONT := Color(1.0, 0.2, 0.8)  ## 冲击波前缘：洋红
const COL_WAVE_TAIL := Color(1.0, 0.15, 0.15)  ## 冲击波尾迹：红

## 每格固定一个噪声字符，模拟屏幕残留数据
var _noise: Array[String] = []
## 蛇身每节的字符
var _body_glyphs: Array[String] = []
## 冲击波特效：以吃食格为圆心，按格子扩散。_wave_t < 0 表示没有特效
var _wave_pos := Vector2i.ZERO
var _wave_t := -1.0


func _ready() -> void:
	_font = MonoFont.get_mono()
	for i in COLS * ROWS:
		_noise.append(NOISE_GLYPHS[randi() % NOISE_GLYPHS.length()])
	reset()
	_dead = false
	running = false  ## 等待玩家首次按键
	set_process(true)


func board_size() -> Vector2:
	return Vector2(COLS * CELL, ROWS * CELL)


func reset() -> void:
	score = 0
	kills = 0
	_dir = Dir.RIGHT
	_pending_dir = Dir.RIGHT
	_snake.clear()
	_body_glyphs.clear()
	_wave_t = -1.0
	var mid := Vector2i(COLS / 2, ROWS / 2)
	_snake.append(mid)
	_snake.append(mid - Vector2i(1, 0))
	_body_glyphs.append(BODY_GLYPHS[randi() % BODY_GLYPHS.length()])
	_body_glyphs.append(BODY_GLYPHS[randi() % BODY_GLYPHS.length()])
	_place_food()
	_move_accum = 0.0
	_step_time = 1.0 / BASE_SPEED
	running = true
	score_changed.emit(score)
	game_started.emit()
	queue_redraw()


func start() -> void:
	reset()


func _place_food() -> void:
	var free: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var p := Vector2i(x, y)
			if not _snake.has(p):
				free.append(p)
	if free.is_empty():
		return
	_food = free[randi() % free.size()]


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if not running:
		start()
		return
	match event.keycode:
		KEY_W, KEY_UP:
			_pending_dir = Dir.UP
		KEY_S, KEY_DOWN:
			_pending_dir = Dir.DOWN
		KEY_A, KEY_LEFT:
			_pending_dir = Dir.LEFT
		KEY_D, KEY_RIGHT:
			_pending_dir = Dir.RIGHT


func _process(delta: float) -> void:
	if _wave_t >= 0.0:
		_wave_t += delta
		if _wave_t >= WAVE_TIME:
			_wave_t = -1.0
		queue_redraw()
	if not running:
		return
	_move_accum += delta
	while _move_accum >= _step_time:
		_move_accum -= _step_time
		if not _step():
			return


func _delta_of(d: int) -> Vector2i:
	match d:
		Dir.UP:
			return Vector2i(0, -1)
		Dir.DOWN:
			return Vector2i(0, 1)
		Dir.LEFT:
			return Vector2i(-1, 0)
		_:
			return Vector2i(1, 0)


func _step() -> bool:
	var vec := _delta_of(_pending_dir)
	# 禁止 180 度掉头
	if vec != -_delta_of(_dir):
		_dir = _pending_dir
	var head: Vector2i = _snake[0] + _delta_of(_dir)

	if head.x < 0 or head.y < 0 or head.x >= COLS or head.y >= ROWS or _snake.has(head):
		running = false
		_dead = true
		game_over.emit(score)
		queue_redraw()
		return false

	_snake.insert(0, head)
	_body_glyphs.insert(0, BODY_GLYPHS[randi() % BODY_GLYPHS.length()])
	if head == _food:
		score += 10
		kills += 1
		_step_time = maxf(1.0 / MAX_SPEED, _step_time * 0.95)
		_wave_pos = head
		_wave_t = 0.0
		_place_food()
		score_changed.emit(score)
		cell_eaten.emit(head)
	else:
		_snake.pop_back()
		if _body_glyphs.size() > _snake.size():
			_body_glyphs.pop_back()
	queue_redraw()
	return true


func _draw() -> void:
	var size := board_size()
	var t := float(Time.get_ticks_msec()) * 0.001
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG)

	for x in range(1, COLS):
		draw_line(Vector2(x * CELL, 0), Vector2(x * CELL, size.y), COL_GRID, 1.0)
	for y in range(1, ROWS):
		draw_line(Vector2(0, y * CELL), Vector2(size.x, y * CELL), COL_GRID, 1.0)

	# 底层噪声字符
	for y in ROWS:
		for x in COLS:
			var p := Vector2i(x, y)
			if _snake.has(p) or p == _food:
				continue
			var a := 0.08 + 0.06 * sin(t * 2.0 + float(x * 3 + y))
			_draw_glyph(p, _noise[y * COLS + x], Color(COL_NOISE, a))

	# 食物：黄色数据包
	var pulse := 0.55 + 0.45 * sin(t * 6.0)
	_draw_glyph(_food, FOOD_GLYPH, Color(COL_FOOD, pulse))

	# 蛇身：字符组成，头部高亮、尾部渐暗；死亡后整条红色闪烁
	var dying := _dead
	var n := _snake.size()
	for i in n:
		var p: Vector2i = _snake[i]
		var glyph := HEAD_GLYPH if i == 0 else _body_glyphs[mini(i, _body_glyphs.size() - 1)]
		var col := COL_HEAD if i == 0 else COL_BODY
		if i > 0:
			col.a = 0.35 + 0.65 * (1.0 - float(i) / float(maxi(1, n)))
		if dying:
			col = Color(COL_ERROR, 0.35 + 0.65 * absf(sin(t * 12.0 + float(i) * 0.5)))
		_draw_glyph(p, glyph, col)


	_draw_wave()

	draw_rect(Rect2(Vector2.ZERO, size), COL_BORDER, false, 2.0)


func _cell_pos(p: Vector2i) -> Vector2:
	return Vector2(p) * CELL


## 字符在格子内居中：用等宽字体的近似半宽做偏移
func _glyph_origin(p: Vector2i) -> Vector2:
	return _cell_pos(p) + Vector2(CELL * 0.5 - GLYPH_SIZE * 0.3, CELL * 0.5 + GLYPH_SIZE * 0.36)


func _draw_glyph(p: Vector2i, glyph: String, color: Color) -> void:
	draw_string(_font, _glyph_origin(p), glyph, HORIZONTAL_ALIGNMENT_LEFT, CELL, GLYPH_SIZE, color)


## 冲击波：吃掉数据包时以该格为圆心，按格子扩散出一圈字符。
## 所有字符都落在格子中心、字号与棋盘一致，像棋盘本身被点亮了。
func _draw_wave() -> void:
	if _wave_t < 0.0:
		return
	var progress := _wave_t / WAVE_TIME
	# 波前从 0 扩散到 WAVE_RADIUS，环后拖一格厚度
	var radius := ease(progress, 0.6) * float(WAVE_RADIUS)
	var fade := 1.0 - progress
	var ri := int(ceil(radius))
	for dy in range(-ri, ri + 1):
		for dx in range(-ri, ri + 1):
			var p := _wave_pos + Vector2i(dx, dy)
			if p.x < 0 or p.y < 0 or p.x >= COLS or p.y >= ROWS:
				continue
			var dist := float(maxi(absi(dx), absi(dy)))  # 切比雪夫距离：方形波前
			if dist > radius:
				continue
			var lead := 1.0 - clampf(absf(dist - radius), 0.0, 1.0)
			var col := COL_WAVE_FRONT.lerp(COL_WAVE_TAIL, 1.0 - lead)
			col.a = fade * (0.3 + 0.7 * lead)
			var glyph := WAVE_GLYPHS[posmod(p.x * 7 + p.y * 13, WAVE_GLYPHS.length())]
			_draw_glyph(p, glyph, col)