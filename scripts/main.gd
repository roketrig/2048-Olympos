extends Control

const SAVE_PATH := "user://save.cfg"
const SWIPE_MIN_DISTANCE := 12.0
const SCREEN := Vector2(180, 320) # game area; extra space on tall phones shows the night sky
const BOARD_SIZE := 168.0

var board: Board
var zeus: Zeus
var sfx: Sfx

var score := 0
var hiscore := 0
var sound_on := true
var busy := false
var over := false

var _screen: Control
var _shaker: Control
var _score_label: PixelLabel
var _hiscore_label: PixelLabel
var _sound_button: PixelButton
var _game_over: Control
var _game_over_box: Control
var _final_score: PixelLabel
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	_load_save()

	sfx = Sfx.new()
	sfx.enabled = sound_on
	add_child(sfx)

	_build_ui()
	get_viewport().size_changed.connect(_layout)
	_layout()
	new_game()


func new_game() -> void:
	score = 0
	over = false
	busy = false
	_update_score_labels()

	_game_over.visible = false
	_game_over.modulate.a = 0.0

	zeus.reset()
	board.clear()
	board.spawn_tile()
	board.spawn_tile()


func try_move(dir: Vector2i) -> void:
	if busy or over or not board.move(dir):
		return

	if board.merge_levels.is_empty():
		sfx.play("move")
	else:
		sfx.play("merge", 1.0 + 0.06 * board.merge_levels.max())

	busy = true
	await get_tree().create_timer(Board.MOVE_TIME + 0.02).timeout

	board.spawn_tile()
	await zeus.after_move()

	if not board.can_move():
		var rescued: bool = await zeus.try_rescue()
		if not rescued or not board.can_move():
			_show_game_over()

	busy = false


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				try_move(Vector2i.UP)
			KEY_DOWN, KEY_S:
				try_move(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				try_move(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				try_move(Vector2i.RIGHT)
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_swipe_start = event.position
			_swiping = true
		elif _swiping:
			_swiping = false
			var delta: Vector2 = event.position - _swipe_start
			if delta.length() < SWIPE_MIN_DISTANCE:
				return
			if absf(delta.x) > absf(delta.y):
				try_move(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
			else:
				try_move(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)


func _on_score_gained(points: int) -> void:
	score += points
	if score > hiscore:
		hiscore = score
		_save()
	_update_score_labels()


func _on_tile_merged(tile: Tile) -> void:
	var center := tile.global_position + tile.size / 2.0
	var local := _shaker.get_global_transform().affine_inverse() * center
	Fx.sparks(_shaker, local, Palette.tile_color(tile.level), 6, 14.0)


func _update_score_labels() -> void:
	_score_label.text = str(score)
	_hiscore_label.text = str(hiscore)


func _show_game_over() -> void:
	over = true
	sfx.play("over")
	_final_score.text = "SCORE %d" % score
	_game_over.visible = true
	var tween := create_tween()
	tween.tween_interval(0.8)
	tween.tween_property(_game_over, "modulate:a", 1.0, 0.3)


func _toggle_sound() -> void:
	sound_on = not sound_on
	sfx.enabled = sound_on
	_sound_button.text = "SFX ON" if sound_on else "SFX OFF"
	sfx.play("click")
	_save()


func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	hiscore = config.get_value("game", "hiscore", 0)
	sound_on = config.get_value("settings", "sound", true)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "hiscore", hiscore)
	config.set_value("settings", "sound", sound_on)
	config.save(SAVE_PATH)


# --- UI ---------------------------------------------------------------------

func _layout() -> void:
	var origin := ((get_viewport_rect().size - SCREEN) / 2.0).floor()
	_screen.position = origin
	_game_over_box.position = origin


func _build_ui() -> void:
	add_child(Stars.new())

	_screen = Control.new()
	_screen.size = SCREEN
	add_child(_screen)

	_shaker = Control.new()
	_shaker.size = SCREEN
	_screen.add_child(_shaker)

	# header: title + score boxes
	_place(_shaker, PixelLabel.new("2048", 3, Palette.GOLD, Palette.GOLD_DARK), Vector2(6, 8))
	_place(_shaker, PixelLabel.new("OLYMPOS", 1, Palette.DIM), Vector2(7, 33))
	_score_label = _score_box(Vector2(80, 8), "SCORE")
	_hiscore_label = _score_box(Vector2(128, 8), "BEST")

	# Zeus, hint and buttons
	zeus = Zeus.new()
	_place(_shaker, zeus, Vector2(6, 46))

	var hints := ["ZEUS MAY STRIKE", "A TILE: x2 x4!"]
	for i in hints.size():
		_place(_shaker, _centered(hints[i], 1, Palette.LIGHT, 116), Vector2(58, 52 + i * 10))

	var new_button := PixelButton.new("NEW GAME", 64, 16)
	new_button.pressed.connect(func() -> void:
		sfx.play("click")
		new_game()
	)
	_place(_shaker, new_button, Vector2(60, 78))

	_sound_button = PixelButton.new("SFX ON" if sound_on else "SFX OFF", 46, 16, Palette.CELL.lightened(0.15))
	_sound_button.pressed.connect(_toggle_sound)
	_place(_shaker, _sound_button, Vector2(128, 78))

	# board
	board = Board.new()
	board.setup(BOARD_SIZE)
	board.score_gained.connect(_on_score_gained)
	board.merged.connect(_on_tile_merged)
	_place(_shaker, board, Vector2(6, 112))

	_place(_shaker, _centered("SWIPE TO MERGE TILES", 1, Palette.DIM, SCREEN.x), Vector2(0, 294))

	# effects layer above the board (lightning, sparks, texts)
	var effects := Control.new()
	effects.size = SCREEN
	_shaker.add_child(effects)

	# full-screen strobe for the lightning
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	zeus.board = board
	zeus.effects = effects
	zeus.shaker = _shaker
	zeus.flash = flash
	zeus.sfx = sfx

	# game over overlay
	_game_over = Dim.new()
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game_over)

	_game_over_box = Control.new()
	_game_over_box.size = SCREEN
	_game_over.add_child(_game_over_box)

	var panel := Box.new()
	panel.size = Vector2(136, 80)
	_place(_game_over_box, panel, Vector2(22, 128))
	_place(_game_over_box, _centered("GAME OVER", 2, Palette.GOLD, SCREEN.x, Palette.INK), Vector2(0, 140))
	_final_score = _centered("SCORE 0", 1, Palette.LIGHT, SCREEN.x)
	_place(_game_over_box, _final_score, Vector2(0, 164))

	var again := PixelButton.new("TRY AGAIN", 70, 16)
	again.pressed.connect(func() -> void:
		sfx.play("click")
		new_game()
	)
	_place(_game_over_box, again, Vector2(55, 184))

	_ignore_mouse(self)


func _score_box(at: Vector2, caption: String) -> PixelLabel:
	var box := Box.new()
	box.size = Vector2(46, 24)
	_place(_shaker, box, at)
	_place(box, _centered(caption, 1, Palette.DIM, box.size.x), Vector2(0, 3))

	var value := _centered("0", 1, Palette.LIGHT, box.size.x)
	_place(box, value, Vector2(0, 13))
	return value


func _centered(text: String, px: int, color: Color, width: float, shadow := Color.TRANSPARENT) -> PixelLabel:
	var label := PixelLabel.new(text, px, color, shadow)
	label.fixed_width = width
	return label


func _place(parent: Control, child: Control, at: Vector2) -> void:
	child.position = at
	parent.add_child(child)


# Everything except buttons lets touches through, so swipes work anywhere.
func _ignore_mouse(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# Score panel background.
class Box extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Palette.BOARD)
		draw_rect(Rect2(1, 1, size.x - 2, 1), Palette.BOARD.lightened(0.15))


# Darkened scanline backdrop for the game over screen.
class Dim extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.6))
		for y in range(0, int(size.y), 2):
			draw_rect(Rect2(0, y, size.x, 1), Color(Palette.INK, 0.35))


# Twinkling night sky behind the game.
class Stars extends Control:
	var _stars: Array[Vector3] = [] # x, y, brightness
	var _timer := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(_scatter)
		_scatter()

	func _scatter() -> void:
		_stars.clear()
		for i in int(size.x * size.y / 900.0):
			_stars.append(Vector3(randi() % maxi(int(size.x), 1), randi() % maxi(int(size.y), 1), randf()))
		queue_redraw()

	func _process(delta: float) -> void:
		_timer += delta
		if _timer < 0.4 or _stars.is_empty():
			return
		_timer = 0.0
		for i in 3:
			var index := randi() % _stars.size()
			var star := _stars[index]
			star.z = randf()
			_stars[index] = star
		queue_redraw()

	func _draw() -> void:
		for star in _stars:
			draw_rect(Rect2(star.x, star.y, 1, 1), Palette.LIGHT if star.z > 0.8 else Palette.DIM.darkened(0.3))
