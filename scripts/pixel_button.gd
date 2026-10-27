class_name PixelButton
extends BaseButton

var text := "":
	set(value):
		text = value
		queue_redraw()
var face := Palette.BUTTON


func _init(label_text := "", width := 60, height := 16, face_color := Palette.BUTTON) -> void:
	text = label_text
	face = face_color
	custom_minimum_size = Vector2(width, height)
	size = custom_minimum_size
	focus_mode = Control.FOCUS_NONE
	button_down.connect(queue_redraw)
	button_up.connect(queue_redraw)


func _draw() -> void:
	var down := get_draw_mode() == DRAW_PRESSED or get_draw_mode() == DRAW_HOVER_PRESSED
	var lift := 1.0 if down else 0.0

	# 1px ink outline plus a 1px drop that disappears when pressed
	draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
	var body := Rect2(1, 1 + lift, size.x - 2, size.y - 3)
	draw_rect(body, face)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 1)), face.lightened(0.3))
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 1), Vector2(body.size.x, 1)), face.darkened(0.3))
	PixelFont.draw_centered(self, text, body, 1, Palette.LIGHT, face.darkened(0.45))
