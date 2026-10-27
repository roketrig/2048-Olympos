class_name PixelSprite
extends Node2D

# Draws a small sprite from rows of characters; "." is transparent.

var rows: Array[String] = []
var colors := {}
var px := 1


func _draw() -> void:
	for y in rows.size():
		var row := rows[y]
		for x in row.length():
			if row[x] != ".":
				draw_rect(Rect2(Vector2(x, y) * px, Vector2.ONE * px), colors[row[x]])
