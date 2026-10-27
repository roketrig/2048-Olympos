extends Control

const SAVE_PATH := "user://save.cfg"
const SWIPE_MIN_DISTANCE := 60.0
const BOARD_SIZE := 640.0
const TEXT_COLOR := Color(0.467, 0.431, 0.396)
const BUTTON_COLOR := Color(0.561, 0.478, 0.4)

var board: Board
var zeus: Zeus

var score := 0
var hiscore := 0
var busy := false
var over := false

var _score_label: Label
var _hiscore_label: Label
var _game_over: Control
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	hiscore = _load_hiscore()
	_build_ui()
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
		_save_hiscore()
	_update_score_labels()


func _update_score_labels() -> void:
	_score_label.text = str(score)
	_hiscore_label.text = str(hiscore)


func _show_game_over() -> void:
	over = true
	_game_over.visible = true
	var tween := create_tween()
	tween.tween_interval(1.0)
	tween.tween_property(_game_over, "modulate:a", 1.0, 0.5)


func _load_hiscore() -> int:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return 0
	return config.get_value("game", "hiscore", 0)


func _save_hiscore() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "hiscore", hiscore)
	config.save(SAVE_PATH)


# --- UI ---------------------------------------------------------------------

func _build_ui() -> void:
	var background := ColorRect.new()
	background.color = Color(0.98, 0.973, 0.937)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)

	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.offset_left = 40
	layout.offset_right = -40
	layout.offset_top = 60
	layout.offset_bottom = -40
	layout.add_theme_constant_override("separation", 24)
	add_child(layout)

	# header: title + score boxes
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 12)
	layout.add_child(header)

	var title := _label("2048", 96, TEXT_COLOR)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	header.add_child(title)

	_score_label = _score_box(header, "SCORE")
	_hiscore_label = _score_box(header, "BEST")

	# Zeus + new game button
	var middle := HBoxContainer.new()
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 40)
	layout.add_child(middle)

	zeus = Zeus.new()
	middle.add_child(zeus)

	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 14)
	middle.add_child(side)

	var hint := _label("Zeus may strike a tile\nand multiply it!", 26, TEXT_COLOR)
	side.add_child(hint)
	side.add_child(_button("New Game", new_game))

	# board
	var board_holder := CenterContainer.new()
	board_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(board_holder)

	board = Board.new()
	board.setup(BOARD_SIZE)
	board.score_gained.connect(_on_score_gained)
	board_holder.add_child(board)

	layout.add_child(_label("Swipe to join the numbers and reach 2048", 24, TEXT_COLOR))

	# effects layer above everything (lightning, flashes, multiplier text)
	var effects := Control.new()
	effects.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(effects)

	zeus.board = board
	zeus.effects = effects

	# game over overlay
	_game_over = ColorRect.new()
	(_game_over as ColorRect).color = Color(0.933, 0.894, 0.855, 0.75)
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game_over)

	var over_box := VBoxContainer.new()
	over_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	over_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	over_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	over_box.alignment = BoxContainer.ALIGNMENT_CENTER
	over_box.add_theme_constant_override("separation", 30)
	_game_over.add_child(over_box)
	over_box.add_child(_label("Game Over!", 80, TEXT_COLOR))
	over_box.add_child(_button("Try Again", new_game))

	_ignore_mouse(self)


func _score_box(parent: Control, caption: String) -> Label:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(150, 0)
	box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	box.add_theme_stylebox_override("panel", _style(Board.BOARD_COLOR, 8, 10))
	parent.add_child(box)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	box.add_child(column)
	column.add_child(_label(caption, 22, Color(0.933, 0.894, 0.855)))

	var value := _label("0", 40, Color.WHITE)
	column.add_child(value)
	return value


func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _button(text: String, on_pressed: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(220, 72)
	button.focus_mode = Control.FOCUS_NONE
	button.add_theme_font_size_override("font_size", 30)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		button.add_theme_color_override(state, Color.WHITE)
	button.add_theme_stylebox_override("normal", _style(BUTTON_COLOR, 10, 12))
	button.add_theme_stylebox_override("hover", _style(BUTTON_COLOR.lightened(0.1), 10, 12))
	button.add_theme_stylebox_override("pressed", _style(BUTTON_COLOR.darkened(0.15), 10, 12))
	button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	button.pressed.connect(on_pressed)
	return button


func _style(color: Color, radius: int, padding: float) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	return style


# Everything except buttons lets touches through, so swipes work anywhere.
func _ignore_mouse(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)
