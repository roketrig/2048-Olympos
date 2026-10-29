class_name Zeus
extends God

# Zeus watches the board and, by chance, strikes one tile with lightning,
# multiplying it by x2 (one level up) or x4 (two levels up). Rarely the bolt
# chains from tile to tile, doubling each one. Multipliers stay powers of two
# so struck tiles can still merge with the rest of the board.

@export_range(0.0, 1.0) var strike_chance := 0.10
@export var cooldown_moves := 3 # minimum moves between two strikes
@export_range(0.0, 1.0) var x4_chance := 0.2
@export_range(0.0, 1.0) var chain_chance := 0.2 # share of strikes that chain
@export var chain_length := Vector2i(3, 5)
@export var rescues_per_game := 1 # strikes that save the player when no move is left
# Each level up makes a tile this much less likely to be struck: a 2 is always a
# candidate, a 64 about 20 times less, a 1024 about 200 times less.
@export_range(0.0, 1.0) var big_tile_falloff := 0.55
@export var helpful_bonus := 4.0 # weight boost for strikes that open a merge

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
		spawn_bolt(from, to)
		sfx.play("zap")
		await wait(0.09)
		Fx.sparks(effects, to, Palette.GOLD, 10, 18.0)
		board.remove_tile(tile)
		from = to
	await wait(0.4)


# Small tiles are far more likely to be struck than big ones. Tiles that will
# match a neighbor after the strike get a boost, so strikes tend to open merges.
func _pick_target(steps: int, helpful_only: bool) -> Tile:
	var pool: Array[Tile] = []
	var weights: Array[float] = []

	for tile in board.tiles():
		var new_level := tile.level + steps
		if new_level > Board.MAX_LEVEL:
			continue

		var weight := strike_weight(tile.level)
		if board.neighbors(tile.grid_pos).any(func(n: Tile) -> bool: return n.level == new_level):
			weight *= helpful_bonus
		elif helpful_only:
			continue
		pool.append(tile)
		weights.append(weight)

	return _weighted_pick(pool, weights)


func strike_weight(level: int) -> float:
	return pow(big_tile_falloff, level)


func _weighted_pick(pool: Array[Tile], weights: Array[float]) -> Tile:
	var total := 0.0
	for w in weights:
		total += w
	var roll := randf() * total
	for i in pool.size():
		roll -= weights[i]
		if roll < 0.0:
			return pool[i]
	return pool.back() if not pool.is_empty() else null


# Random start, then always hops to the nearest tile not hit yet. Each tile
# joins the pool with its strike weight, so big tiles are rarely in a chain.
func _pick_chain() -> Array[Tile]:
	var pool := board.tiles().filter(func(t: Tile) -> bool:
		return t.level < Board.MAX_LEVEL and randf() < strike_weight(t.level))
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
	spawn_bolt(portrait_point(), to)
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
		spawn_bolt(from, to)
		sfx.play("zap", 1.0 + i * 0.15)
		await wait(0.09)

		board.upgrade(tile, 1)
		Fx.sparks(effects, to, Palette.GOLD, 10, 18.0)
		float_text("x2", to, 2, Palette.GOLD)
		from = to

	sfx.play("bonus")
	await wait(0.5)
