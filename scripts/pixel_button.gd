class_name PixelButton
extends BaseButton

var text := "":
	set(value):
		text = value
		queue_redraw()
var face := Palette.BUTTON
var icon: Array[String] = [] # optional pixel icon drawn left of the text
var icon_color := Color.WHITE
var highlighted := false: # selected look, e.g. while a mode is active
	set(value):
		highlighted = value
		queue_redraw()


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
	var color := face.lightened(0.25) if highlighted else face
	if disabled:
		color = face.darkened(0.35)
	var body := Rect2(1, 1 + lift, size.x - 2, size.y - 3)
	draw_rect(body, color)
	draw_rect(Rect2(body.position, Vector2(body.size.x, 1)), color.lightened(0.3))
	draw_rect(Rect2(body.position + Vector2(0, body.size.y - 1), Vector2(body.size.x, 1)), color.darkened(0.3))
	if highlighted:
		draw_rect(Rect2(0, 0, size.x, size.y), Palette.LIGHT, false, 1.0)

	var text_color := Palette.DIM if disabled else Palette.LIGHT
	if icon.is_empty():
		PixelFont.draw_centered(self, text, body, 1, text_color, color.darkened(0.45))
		return

	# icon + text, centered together
	var icon_size := Vector2(icon[0].length(), icon.size())
	var text_size := PixelFont.measure(text, 1)
	var gap := 2.0 if text != "" else 0.0
	var x := floorf(body.position.x + (body.size.x - icon_size.x - gap - text_size.x) / 2.0)
	var icon_y := floorf(body.position.y + (body.size.y - icon_size.y) / 2.0)
	for y in icon.size():
		for i in icon[y].length():
			if icon[y][i] != ".":
				draw_rect(Rect2(x + i, icon_y + y, 1, 1), icon_color if not disabled else Palette.DIM)
	PixelFont.draw(self, text, Vector2(x + icon_size.x + gap, floorf(body.position.y + (body.size.y - text_size.y) / 2.0)), 1, text_color, color.darkened(0.45))
