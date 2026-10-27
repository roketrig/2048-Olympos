class_name Fx
extends RefCounted

# Small retro effects shared by the board and Zeus.


static func sparks(layer: Control, at: Vector2, color: Color, count := 8, reach := 18.0) -> void:
	for i in count:
		var spark := ColorRect.new()
		spark.color = color
		spark.size = Vector2.ONE * (2 if randf() < 0.5 else 1)
		spark.position = at.floor()
		spark.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(spark)

		var target := at + Vector2.RIGHT.rotated(randf() * TAU) * randf_range(0.4, 1.0) * reach
		var tween := spark.create_tween().set_parallel()
		tween.tween_property(spark, "position", target.floor(), 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(spark, "modulate:a", 0.0, 0.2).set_delay(0.2)
		tween.chain().tween_callback(spark.queue_free)


# Jitters `node` around its resting position (assumed Vector2.ZERO) in whole pixels.
static func shake(node: Control, strength := 3, duration := 0.3) -> void:
	var steps := int(duration / 0.03)
	var tween := node.create_tween()
	for i in steps:
		var amount := ceili(strength * (1.0 - float(i) / steps))
		tween.tween_property(node, "position", Vector2(randi_range(-amount, amount), randi_range(-amount, amount)), 0.03)
	tween.tween_property(node, "position", Vector2.ZERO, 0.03)


# Retro blink: toggles visibility a few times, then frees the node.
static func blink_out(node: CanvasItem, delay: float, blinks := 3, rate := 0.07) -> void:
	var tween := node.create_tween()
	tween.tween_interval(delay)
	for i in blinks:
		tween.tween_callback(node.hide)
		tween.tween_interval(rate)
		tween.tween_callback(node.show)
		tween.tween_interval(rate)
	tween.tween_callback(node.queue_free)
