class_name God
extends Control

# Base for the gods shown above the board: draws the pixel portrait and
# provides the shared effects. Subclasses decide when and how to act.

signal feat(id: String) # something worth a trophy happened

const FRAME := 46.0
const SPRITE_PX := 2

var god_name := ""
var accent := Palette.GOLD
var status := "": # replaces the name under the portrait while set
	set(value):
		status = value
		queue_redraw()

var board: Board
var effects: Control # layer for bolts, hearts, texts
var shaker: Control # node that shakes on big moments
var flash: ColorRect # full-screen strobe
var sfx: Sfx

var _moves_since_action := 0
var _time := 0.0
var _glow := 0.0
var _bob := 0


func _init() -> void:
	custom_minimum_size = Vector2(FRAME, FRAME + 10)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func reset() -> void:
	_moves_since_action = 0
	status = ""


# Called once per move for every god, before any of them acts.
func tick() -> void:
	_moves_since_action += 1


# Called after a move; returns true if the god acted (only one acts per move).
func after_move() -> bool:
	return false


func wants_to_act(chance: float, cooldown: int) -> bool:
	return _moves_since_action > cooldown and randf() < chance


func acted() -> void:
	_moves_since_action = 0
	_glow = 1.0


# --- portrait ---------------------------------------------------------------

func sprite() -> Array[String]:
	return []


func sprite_colors() -> Dictionary:
	return {}


# Colors swapped in while the god is glowing (e.g. shining eyes).
func glow_colors() -> Dictionary:
	return {}


func _process(delta: float) -> void:
	_time += delta
	var bob := int(_time * 2.0) % 2
	if _glow > 0.0 or bob != _bob:
		_bob = bob
		_glow = maxf(_glow - delta * 1.5, 0.0)
		queue_redraw()


func _draw() -> void:
	var lit := _glow > 0.0

	draw_rect(Rect2(0, 0, FRAME, FRAME), Palette.INK)
	draw_rect(Rect2(1, 1, FRAME - 2, FRAME - 2), accent if lit else accent.darkened(0.45))
	draw_rect(Rect2(2, 2, FRAME - 4, FRAME - 4), Palette.BOARD.lightened(0.2) if lit else Palette.CELL)

	var colors := sprite_colors()
	var glowing := glow_colors() if lit else {}
	var origin := Vector2(3, 3 + _bob)
	var rows := sprite()
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			var key := row[x]
			if key == ".":
				continue
			var color: Color = glowing.get(key, colors[key])
			draw_rect(Rect2(origin + Vector2(x, y) * SPRITE_PX, Vector2.ONE * SPRITE_PX), color)

	var caption := status if status != "" else god_name
	PixelFont.draw_centered(self, caption, Rect2(0, FRAME + 2, FRAME, 7), 1, accent, Palette.INK)


# --- shared effects -----------------------------------------------------------

func portrait_point() -> Vector2:
	return to_effects(global_position + Vector2(FRAME / 2.0, FRAME - 4.0))


func tile_point(tile: Tile) -> Vector2:
	return to_effects(tile.global_position + tile.size / 2.0)


func to_effects(global_point: Vector2) -> Vector2:
	return (effects.get_global_transform().affine_inverse() * global_point).floor()


func strobe(color: Color, pulses: Array = [0.8, 0.0, 0.5, 0.0]) -> void:
	flash.color = Color(color, 0.0)
	var tween := flash.create_tween()
	for alpha in pulses:
		tween.tween_property(flash, "color:a", alpha, 0.0)
		tween.tween_interval(0.04)


func float_text(text: String, at: Vector2, px: int, color: Color) -> void:
	var label := PixelLabel.new(text, px, color, Palette.INK)
	label.position = (at - label.size / 2.0).floor()
	effects.add_child(label)
	label.create_tween().tween_property(label, "position:y", label.position.y - 10.0, 0.3).set_ease(Tween.EASE_OUT)
	Fx.blink_out(label, 0.45)


func banner(text: String, color: Color) -> void:
	var label := PixelLabel.new(text, 2, color, Palette.INK)
	var center := to_effects(board.global_position + board.size / 2.0)
	label.position = (center - label.size / 2.0).floor()
	effects.add_child(label)
	Fx.blink_out(label, 0.9, 4)


func spawn_bolt(from: Vector2, to: Vector2, glow := Palette.GOLD, core := Color.WHITE) -> void:
	var bolt := Bolt.new()
	bolt.glow = glow
	bolt.core = core
	bolt.points = _jagged(from, to, maxi(3, int(from.distance_to(to) / 12.0)), 6.0)
	var fork_start := bolt.points[bolt.points.size() / 2]
	bolt.fork = _jagged(fork_start, fork_start + Vector2(randf_range(-20, 20), 18), 3, 3.0)
	effects.add_child(bolt)

	var tween := bolt.create_tween()
	tween.tween_interval(0.06)
	tween.tween_callback(bolt.hide)
	tween.tween_interval(0.04)
	tween.tween_callback(bolt.show)
	tween.tween_interval(0.1)
	tween.tween_callback(bolt.queue_free)


func _jagged(from: Vector2, to: Vector2, segments: int, jitter: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var normal := (to - from).orthogonal().normalized()
	for i in segments + 1:
		var offset := 0.0 if i == 0 or i == segments else randf_range(-jitter, jitter)
		points.append((from.lerp(to, float(i) / segments) + normal * offset).floor())
	return points


func wait(seconds: float) -> void:
	await get_tree().create_timer(seconds).timeout
