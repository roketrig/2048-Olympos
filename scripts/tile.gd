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


func vanish() -> void:
	_restart_tween()
	_tween.tween_property(self, "scale", Vector2.ZERO, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	_tween.tween_callback(queue_free)


func _restart_tween() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()


func _draw() -> void:
	draw_face(self, Rect2(Vector2.ZERO, size), level)


# Shared with the potion slot, which shows a held tile in miniature.
static func draw_face(canvas: CanvasItem, rect: Rect2, tile_level: int) -> void:
	var face := Palette.tile_color(tile_level)
	var shade := face.darkened(0.4)
	var p := rect.position
	var s := rect.size

	# chunky bevel: dark base with a 2px drop, light top and left edges
	canvas.draw_rect(rect, shade)
	canvas.draw_rect(Rect2(p, Vector2(s.x, s.y - 2)), face)
	canvas.draw_rect(Rect2(p + Vector2(1, 1), Vector2(s.x - 2, 1)), face.lightened(0.4))
	canvas.draw_rect(Rect2(p + Vector2(1, 2), Vector2(1, s.y - 5)), face.lightened(0.2))

	var text := str(value_of(tile_level))
	var px := 1
	if s.x >= 30:
		px = 3 if text.length() == 1 else (2 if text.length() == 2 else 1)
	PixelFont.draw_centered(canvas, text, Rect2(p, Vector2(s.x, s.y - 2)), px, Palette.tile_text_color(tile_level), shade)
