class_name PixelLabel
extends Control

var text := "":
	set(value):
		text = value
		_fit()
		queue_redraw()
var px := 1
var color := Palette.LIGHT
var shadow := Color.TRANSPARENT
var fixed_width := 0.0: # when > 0 the text is centered in this width
	set(value):
		fixed_width = value
		_fit()


func _init(label_text := "", pixel_size := 1, text_color := Palette.LIGHT, shadow_color := Color.TRANSPARENT) -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	px = pixel_size
	color = text_color
	shadow = shadow_color
	text = label_text


func _fit() -> void:
	var needed := PixelFont.measure(text, px) + (Vector2.ONE if shadow.a > 0.0 else Vector2.ZERO)
	if fixed_width > 0.0:
		needed.x = fixed_width
	custom_minimum_size = needed
	size = needed


func _draw() -> void:
	PixelFont.draw_centered(self, text, Rect2(Vector2.ZERO, size), px, color, shadow)
