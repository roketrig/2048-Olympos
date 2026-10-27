class_name Zeus
extends Control

# Zeus watches the board and, by chance, strikes one tile with lightning,
# multiplying it by x2 (one level up) or x4 (two levels up). Multipliers stay
# powers of two so the struck tile can still merge with the rest of the board.

@export_range(0.0, 1.0) var strike_chance := 0.12
@export var cooldown_moves := 3 # minimum moves between two normal strikes
@export_range(0.0, 1.0) var x4_chance := 0.2
@export var rescues_per_game := 1 # strikes that save the player when no move is left
@export var portrait: Texture2D # optional art; the pixel sprite is used otherwise

const FRAME := 46.0
const SPRITE_PX := 2
const SPRITE: Array[String] = [
	"....g.G.GGGG.G.g....",
	"...gGGGGWWWWGGGGg...",
	"..gGWWWWWWWWWWWWGg..",
	"..WWWWWWWWWWWWWWWW..",
	".WWWWSSSSSSSSSSWWWW.",
	".WWWSSSSSSSSSSSSWWW.",
	".WWWSEEESSSSEEESWWW.",
	".WWWSSPSSSSSSPSSWWW.",
	".WWWSSSSSSSSSSSSWWW.",
	".wWWSSSSSssSSSSSWWw.",
	".wWWWSWWWWWWWWSWWWw.",
	".wWWWWWWEEEEWWWWWWw.",
	".wWWWWWWWWWWWWWWWWw.",
	"..wWWWWWwWWwWWWWWw..",
	"..wWWWWWWWWWWWWWWw..",
	"...wWWWwWWWWwWWWw...",
	"....wWWWWWWWWWWw....",
	".....wWWwWWwWWw.....",
	"......wWWWWWWw......",
	"........wWWw........",
]
const SPRITE_COLORS := {
	"W": Color("f4f0ff"), "w": Color("b9b0d6"),
	"S": Color("f2b88c"), "s": Color("c98563"),
	"E": Color("3a2a4a"), "P": Color("3a2a4a"),
	"G": Palette.GOLD, "g": Palette.GOLD_DARK,
}

var board: Board
var effects: Control # layer the lightning and texts are drawn on
var shaker: Control # node that shakes on a strike
var flash: ColorRect # full-screen strobe
var sfx: Sfx

var _moves_since_strike := 0
var _rescues_used := 0
var _time := 0.0
var _glow := 0.0
var _bob := 0


func _init() -> void:
	custom_minimum_size = Vector2(FRAME, FRAME + 10)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE


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
			_banner("DIVINE RESCUE!")
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
	sfx.play("zap")
	sfx.play("thunder")

	var from := _to_effects(global_position + Vector2(FRAME / 2.0, FRAME - 4.0))
	var to := _to_effects(tile.global_position + tile.size / 2.0)
	_spawn_bolt(from, to)
	_strobe()
	Fx.shake(shaker, 3, 0.3)

	await get_tree().create_timer(0.12).timeout

	if is_instance_valid(tile):
		board.upgrade(tile, steps)
		sfx.play("bonus")
		Fx.sparks(effects, to, Palette.GOLD, 14, 24.0)
		Fx.sparks(effects, to, Color.WHITE, 6, 14.0)
		_spawn_multiplier(to, 1 << steps)

	await get_tree().create_timer(0.5).timeout


func _to_effects(global_point: Vector2) -> Vector2:
	return (effects.get_global_transform().affine_inverse() * global_point).floor()


func _spawn_bolt(from: Vector2, to: Vector2) -> void:
	var bolt := Bolt.new()
	bolt.points = _jagged(from, to, 8, 6.0)
	var fork_start := bolt.points[bolt.points.size() / 2]
	bolt.fork = _jagged(fork_start, fork_start + Vector2(randf_range(-24, 24), 22), 3, 3.0)
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


func _strobe() -> void:
	var tween := flash.create_tween()
	for alpha in [0.8, 0.0, 0.5, 0.0]:
		tween.tween_property(flash, "color:a", alpha, 0.0)
		tween.tween_interval(0.04)


func _spawn_multiplier(at: Vector2, multiplier: int) -> void:
	var label := PixelLabel.new("x%d" % multiplier, 3, Palette.GOLD, Palette.INK)
	label.position = (at - label.size / 2.0).floor()
	effects.add_child(label)

	var tween := label.create_tween()
	tween.tween_property(label, "position:y", label.position.y - 10.0, 0.3).set_ease(Tween.EASE_OUT)
	Fx.blink_out(label, 0.45)


func _banner(text: String) -> void:
	var label := PixelLabel.new(text, 2, Palette.GOLD, Palette.INK)
	var center := _to_effects(board.global_position + board.size / 2.0)
	label.position = (center - label.size / 2.0).floor()
	effects.add_child(label)
	Fx.blink_out(label, 0.9, 4)


func _process(delta: float) -> void:
	_time += delta
	var bob := int(_time * 2.0) % 2
	if _glow > 0.0 or bob != _bob:
		_bob = bob
		_glow = maxf(_glow - delta * 2.0, 0.0)
		queue_redraw()


func _draw() -> void:
	var lit := _glow > 0.0

	# portrait frame
	draw_rect(Rect2(0, 0, FRAME, FRAME), Palette.INK)
	draw_rect(Rect2(1, 1, FRAME - 2, FRAME - 2), Palette.GOLD if lit else Palette.GOLD_DARK)
	draw_rect(Rect2(2, 2, FRAME - 4, FRAME - 4), Palette.BOARD.lightened(0.2) if lit else Palette.CELL)

	var origin := Vector2(3, 3 + _bob)
	if portrait != null:
		draw_texture_rect(portrait, Rect2(3, 3, FRAME - 6, FRAME - 6), false)
	else:
		for y in SPRITE.size():
			var row := SPRITE[y]
			for x in row.length():
				var key := row[x]
				if key == ".":
					continue
				var color: Color = Color.WHITE if (lit and key == "P") else SPRITE_COLORS[key]
				draw_rect(Rect2(origin + Vector2(x, y) * SPRITE_PX, Vector2.ONE * SPRITE_PX), color)

	PixelFont.draw_centered(self, "ZEUS", Rect2(0, FRAME + 2, FRAME, 7), 1, Palette.GOLD, Palette.INK)


# Pixel lightning: chunky gold glow with a 1px white core.
class Bolt extends Node2D:
	var points := PackedVector2Array()
	var fork := PackedVector2Array()

	func _draw() -> void:
		for path in [points, fork]:
			_path(path, 3, Palette.GOLD)
		for path in [points, fork]:
			_path(path, 1, Color.WHITE)

	func _path(path: PackedVector2Array, width: int, color: Color) -> void:
		var half := floorf(width / 2.0)
		for i in path.size() - 1:
			var a := path[i]
			var b := path[i + 1]
			var steps := maxi(1, int(maxf(absf(b.x - a.x), absf(b.y - a.y))))
			for s in steps + 1:
				var p := a.lerp(b, float(s) / steps).floor()
				draw_rect(Rect2(p - Vector2(half, half), Vector2(width, width)), color)
