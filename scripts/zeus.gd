class_name Zeus
extends Control

# Zeus watches the board and, by chance, strikes one tile with lightning,
# multiplying it by x2 (one level up) or x4 (two levels up). Multipliers stay
# powers of two so the struck tile can still merge with the rest of the board.

@export_range(0.0, 1.0) var strike_chance := 0.12
@export var cooldown_moves := 3 # minimum moves between two normal strikes
@export_range(0.0, 1.0) var x4_chance := 0.2
@export var rescues_per_game := 1 # strikes that save the player when no move is left
@export var portrait: Texture2D # optional art; a drawn placeholder is used otherwise

const GOLD := Color(0.96, 0.78, 0.25)
const ROBE := Color(0.33, 0.25, 0.45)
const BOLT := Color(1.0, 0.95, 0.6)
const BOLT_SHAPE: Array[Vector2] = [
	Vector2(0.2, -0.8), Vector2(-0.35, 0.1), Vector2(0.0, 0.1), Vector2(-0.2, 0.8),
	Vector2(0.4, -0.15), Vector2(0.05, -0.15), Vector2(0.3, -0.8),
]
const NAME_HEIGHT := 30.0

var board: Board
var effects: Control # full-screen layer the lightning is drawn on

var _moves_since_strike := 0
var _rescues_used := 0
var _time := 0.0
var _glow := 0.0


func _init() -> void:
	custom_minimum_size = Vector2(150, 150 + NAME_HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func() -> void: pivot_offset = size / 2.0)


func reset() -> void:
	_moves_since_strike = 0
	_rescues_used = 0


# Called after every move. Returns true if Zeus struck.
func after_move() -> bool:
	_moves_since_strike += 1
	if _moves_since_strike <= cooldown_moves or randf() >= strike_chance:
		return false

	var steps := 2 if randf() < x4_chance else 1
	var tile := _pick_target(steps, false)
	if tile == null and steps == 2:
		steps = 1
		tile = _pick_target(steps, false)
	if tile == null:
		return false

	_moves_since_strike = 0
	await _strike(tile, steps)
	return true


# Called when the board is stuck. Strikes a tile that opens up a merge, if any.
func try_rescue() -> bool:
	if _rescues_used >= rescues_per_game:
		return false

	for steps in [1, 2]:
		var tile := _pick_target(steps, true)
		if tile != null:
			_rescues_used += 1
			await _strike(tile, steps)
			return true

	return false


# Prefers tiles that will match a neighbor after the strike, so the strike
# opens up a merge. Otherwise picks one of the smaller tiles on the board.
func _pick_target(steps: int, helpful_only: bool) -> Tile:
	var helpful: Array[Tile] = []
	var others: Array[Tile] = []

	for tile in board.tiles():
		var new_level := tile.level + steps
		if new_level > Board.MAX_LEVEL:
			continue

		if board.neighbors(tile.grid_pos).any(func(n: Tile) -> bool: return n.level == new_level):
			helpful.append(tile)
		else:
			others.append(tile)

	if not helpful.is_empty():
		return helpful.pick_random()
	if helpful_only or others.is_empty():
		return null

	others.sort_custom(func(a: Tile, b: Tile) -> bool: return a.level < b.level)
	return others[randi() % ceili(others.size() / 2.0)]


func _strike(tile: Tile, steps: int) -> void:
	_glow = 1.0
	var pulse := create_tween()
	pulse.tween_property(self, "scale", Vector2.ONE * 1.12, 0.1)
	pulse.tween_property(self, "scale", Vector2.ONE, 0.2)

	var from := _to_effects(global_position + _bolt_center())
	var to := _to_effects(tile.global_position + tile.size / 2.0)
	_spawn_lightning(from, to)
	_spawn_flash()

	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(tile):
		board.upgrade(tile, steps)
		_spawn_multiplier(to, 1 << steps)

	await get_tree().create_timer(0.45).timeout


func _to_effects(global_point: Vector2) -> Vector2:
	return effects.get_global_transform().affine_inverse() * global_point


func _spawn_lightning(from: Vector2, to: Vector2) -> void:
	var points := PackedVector2Array()
	var segments := 10
	var normal := (to - from).orthogonal().normalized()
	for i in segments + 1:
		var t := float(i) / segments
		var jitter := 0.0 if i == 0 or i == segments else randf_range(-22.0, 22.0)
		points.append(from.lerp(to, t) + normal * jitter)

	var bolt := Node2D.new()
	for layer in [[26.0, Color(GOLD, 0.35)], [8.0, BOLT], [3.0, Color.WHITE]]:
		var line := Line2D.new()
		line.points = points
		line.width = layer[0]
		line.default_color = layer[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		bolt.add_child(line)
	effects.add_child(bolt)

	var flicker := bolt.create_tween()
	flicker.tween_property(bolt, "modulate:a", 0.3, 0.06)
	flicker.tween_property(bolt, "modulate:a", 1.0, 0.06)
	flicker.tween_property(bolt, "modulate:a", 0.0, 0.3)
	flicker.tween_callback(bolt.queue_free)


func _spawn_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1.0, 0.97, 0.8, 0.5)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	effects.add_child(flash)

	var fade := flash.create_tween()
	fade.tween_property(flash, "color:a", 0.0, 0.3)
	fade.tween_callback(flash.queue_free)


func _spawn_multiplier(at: Vector2, multiplier: int) -> void:
	var label := Label.new()
	label.text = "x%d" % multiplier
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 84)
	label.add_theme_color_override("font_color", GOLD)
	label.add_theme_color_override("font_outline_color", Color(0.35, 0.2, 0.05))
	label.add_theme_constant_override("outline_size", 14)
	label.size = Vector2(200, 110)
	label.pivot_offset = label.size / 2.0
	label.position = at - label.size / 2.0
	label.scale = Vector2.ONE * 0.4
	effects.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "scale", Vector2.ONE * 1.2, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "position:y", label.position.y - 70.0, 0.8).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.25)
	tween.tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)


func _process(delta: float) -> void:
	_time += delta
	_glow = maxf(_glow - delta * 1.5, 0.0)
	queue_redraw()


func _bolt_center() -> Vector2:
	return Vector2(size.x / 2.0, (size.y - NAME_HEIGHT) / 2.0)


func _draw() -> void:
	var center := _bolt_center()
	var radius := minf(size.x, size.y - NAME_HEIGHT) / 2.0 - 10.0
	var breathe := 0.5 + 0.5 * sin(_time * 2.0)

	draw_circle(center, radius + 6.0 + 4.0 * breathe + 6.0 * _glow, Color(GOLD, 0.15 + 0.1 * breathe + 0.5 * _glow))
	draw_circle(center, radius, ROBE)

	if portrait != null:
		draw_texture_rect(portrait, Rect2(center - Vector2.ONE * radius, Vector2.ONE * radius * 2.0), false)
	else:
		var shape := PackedVector2Array()
		for p in BOLT_SHAPE:
			shape.append(center + p * radius * 0.75)
		draw_colored_polygon(shape, BOLT.lerp(Color.WHITE, _glow))

	draw_arc(center, radius, 0.0, TAU, 64, GOLD, 5.0, true)
	draw_string(get_theme_default_font(), Vector2(0.0, size.y - 6.0), "ZEUS",
			HORIZONTAL_ALIGNMENT_CENTER, size.x, 26, GOLD)
