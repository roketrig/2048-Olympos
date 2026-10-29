class_name Zeus
extends God

# Zeus watches the board and, by chance, strikes one tile with lightning,
# multiplying it by x2 (one level up) or x4 (two levels up). Rarely the bolt
# chains from tile to tile, doubling each one. Multipliers stay powers of two
# so struck tiles can still merge with the rest of the board.

@export_range(0.0, 1.0) var strike_chance := 0.12
@export var cooldown_moves := 3 # minimum moves between two strikes
@export_range(0.0, 1.0) var x4_chance := 0.2
@export_range(0.0, 1.0) var chain_chance := 0.2 # share of strikes that chain
@export var chain_length := Vector2i(3, 5)
@export var rescues_per_game := 1 # strikes that save the player when no move is left

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

var _rescues_used := 0


func _init() -> void:
	super()
	god_name = "ZEUS"
	accent = Palette.GOLD


func sprite() -> Array[String]:
	return SPRITE


func sprite_colors() -> Dictionary:
	return SPRITE_COLORS


func glow_colors() -> Dictionary:
	return {"P": Color.WHITE}


func reset() -> void:
	super()
	_rescues_used = 0


func after_move() -> bool:
	if not wants_to_act(strike_chance, cooldown_moves):
		return false

	if randf() < chain_chance:
		var chain := _pick_chain()
		if chain.size() >= 2:
			acted()
			await _chain_strike(chain)
			return true

	var steps := 2 if randf() < x4_chance else 1
	var tile := _pick_target(steps, false)
	if tile == null and steps == 2:
		steps = 1
		tile = _pick_target(steps, false)
	if tile == null:
		return false

	acted()
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
			acted()
			banner(I18n.t("banner_rescue"), Palette.GOLD)
			await _strike(tile, steps)
			return true

	return false


# Reward for watching an ad on the game over screen: always frees the board.
func revive() -> void:
	acted()
	for steps in [1, 2]:
		var tile := _pick_target(steps, true)
		if tile != null:
			banner(I18n.t("banner_saves"), Palette.GOLD)
			await _strike(tile, steps)
			return

	# no strike opens a merge: smite the three smallest tiles to make room
	banner(I18n.t("banner_smites"), Palette.GOLD)
	sfx.play("thunder")
	strobe(Color.WHITE)
	Fx.shake(shaker, 4, 0.4)
	var victims := board.tiles()
	victims.sort_custom(func(a: Tile, b: Tile) -> bool: return a.level < b.level)
	var from := portrait_point()
	for tile in victims.slice(0, 3):
		var to := tile_point(tile)
		_spawn_bolt(from, to)
		sfx.play("zap")
		await wait(0.09)
		Fx.sparks(effects, to, Palette.GOLD, 10, 18.0)
		board.remove_tile(tile)
		from = to
	await wait(0.4)


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


# Random start, then always hops to the nearest tile not hit yet.
func _pick_chain() -> Array[Tile]:
	var pool := board.tiles().filter(func(t: Tile) -> bool: return t.level < Board.MAX_LEVEL)
	var chain: Array[Tile] = []
	if pool.is_empty():
		return chain

	var length := mini(randi_range(chain_length.x, chain_length.y), pool.size())
	var current: Tile = pool.pick_random()
	while chain.size() < length:
		chain.append(current)
		pool.erase(current)
		if pool.is_empty():
			break
		var from := current.grid_pos
		pool.sort_custom(func(a: Tile, b: Tile) -> bool:
			return Vector2(a.grid_pos - from).length() < Vector2(b.grid_pos - from).length())
		current = pool[0]

	return chain


func _strike(tile: Tile, steps: int) -> void:
	sfx.buzz(40)
	sfx.play("zap")
	sfx.play("thunder")

	var to := tile_point(tile)
	_spawn_bolt(portrait_point(), to)
	strobe(Color.WHITE)
	Fx.shake(shaker, 3, 0.3)

	await wait(0.12)

	if is_instance_valid(tile):
		board.upgrade(tile, steps)
		sfx.play("bonus")
		Fx.sparks(effects, to, Palette.GOLD, 14, 24.0)
		Fx.sparks(effects, to, Color.WHITE, 6, 14.0)
		float_text("x%d" % (1 << steps), to, 3, Palette.GOLD)

	await wait(0.5)


func _chain_strike(chain: Array[Tile]) -> void:
	sfx.play("thunder")
	banner(I18n.t("banner_chain") % chain.size(), Palette.GOLD)
	sfx.buzz(60)
	strobe(Color.WHITE, [0.8, 0.0, 0.5, 0.0, 0.4, 0.0])
	Fx.shake(shaker, 4, 0.5)

	var from := portrait_point()
	for i in chain.size():
		var tile := chain[i]
		if not is_instance_valid(tile):
			continue
		var to := tile_point(tile)
		_spawn_bolt(from, to)
		sfx.play("zap", 1.0 + i * 0.15)
		await wait(0.09)

		board.upgrade(tile, 1)
		Fx.sparks(effects, to, Palette.GOLD, 10, 18.0)
		float_text("x2", to, 2, Palette.GOLD)
		from = to

	sfx.play("bonus")
	await wait(0.5)


func _spawn_bolt(from: Vector2, to: Vector2) -> void:
	var bolt := Bolt.new()
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
