class_name Bolt
extends Node2D

# Pixel lightning: a chunky colored glow with a 1px core.

var points := PackedVector2Array()
var fork := PackedVector2Array()
var glow := Palette.GOLD
var core := Color.WHITE


func _draw() -> void:
	for path in [points, fork]:
		_path(path, 3, glow)
	for path in [points, fork]:
		_path(path, 1, core)


func _path(path: PackedVector2Array, width: int, color: Color) -> void:
	var half := floorf(width / 2.0)
	for i in path.size() - 1:
		var a := path[i]
		var b := path[i + 1]
		var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
		for s in steps + 1:
			var p := a.lerp(b, float(s) / steps).floor()
			draw_rect(Rect2(p - Vector2(half, half), Vector2(width, width)), color)
