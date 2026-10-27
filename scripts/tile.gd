class_name Tile
extends Control

var level := 0
var grid_pos := Vector2i.ZERO
var locked := false

var _tween: Tween


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


static func value_of(tile_level: int) -> int:
	return 1 << (tile_level + 1)


func value() -> int:
	return value_of(level)


func set_level(value_level: int) -> void:
	level = value_level
	queue_redraw()


func resize(cell_size: float) -> void:
	size = Vector2(cell_size, cell_size)
	pivot_offset = (size / 2.0).floor()


func appear() -> void:
	_restart_tween()
	scale = Vector2.ONE * 0.25
	_tween.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func pop(amount := 1.2, duration := 0.16) -> void:
	_restart_tween()
	scale = Vector2.ONE
	_tween.tween_property(self, "scale", Vector2.ONE * amount, duration * 0.5).set_ease(Tween.EASE_OUT)
	_tween.tween_property(self, "scale", Vector2.ONE, duration * 0.5).set_ease(Tween.EASE_IN)


func _restart_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


func _draw() -> void:
	var face := Palette.tile_color(level)
	var shade := face.darkened(0.4)

	# chunky bevel: dark base with a 2px drop, light top and left edges
	draw_rect(Rect2(Vector2.ZERO, size), shade)
	draw_rect(Rect2(0, 0, size.x, size.y - 2), face)
	draw_rect(Rect2(1, 1, size.x - 2, 1), face.lightened(0.4))
	draw_rect(Rect2(1, 2, 1, size.y - 5), face.lightened(0.2))

	var text := str(value())
	var px := 3 if text.length() == 1 else (2 if text.length() == 2 else 1)
	PixelFont.draw_centered(self, text, Rect2(0, 0, size.x, size.y - 2), px, Palette.tile_text_color(level), shade)
