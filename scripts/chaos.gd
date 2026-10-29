class_name Chaos
extends God

# The boss. When a 2048 tile appears the gods vanish and Chaos takes Olympos.
# Every merge hurts him; he fights back with the reverse of each god's gift,
# less often than the gods would help:
#   halve  (anti-Zeus): a tile is halved, rarely quartered
#   split  (anti-Eros): tiles break in two, and he steals a love potion
#   flood  (anti-Ares): 2s pour onto the board and hits are weakened

@export var max_hp := 3000
@export var cooldown_moves := 4
@export_range(0.0, 1.0) var halve_chance := 0.06
@export_range(0.0, 1.0) var quarter_chance := 0.2 # share of halvings that quarter instead
@export_range(0.0, 1.0) var split_chance := 0.045
@export_range(0.0, 1.0) var flood_chance := 0.04
@export var curse_moves := 6
@export var curse_multiplier := 0.5

const PURPLE := Color("b04cff")
const VOID := Color("3d1f5c")
const SPRITE: Array[String] = [
	"....vVVVVVVVVVVv....",
	"...vVVKKKKKKKKVVv...",
	"..vVKKKKKKKKKKKKVv..",
	".vVKKKKKKKKKKKKKKVv.",
	".VKKKKKKKKKKKKKKKKV.",
	"vVKKKEEKKKKKKEEKKKVv",
	"VKKKEeeEKKKKEeeEKKKV",
	"VKKKKEEKKKKKKEEKKKKV",
	"VKKKKKKKKKKKKKKKKKKV",
	"VKKKKKKKKKKKKKKKKKKV",
	"VKKKKWKWKWKWKWKKKKKV",
	"vVKKKKWKWKWKWKKKKKVv",
	".VKKKKKKKKKKKKKKKKV.",
	".vVKKKKKKKKKKKKKKVv.",
	"..vVKKKKKKKKKKKKVv..",
	"...vVVKKKKKKKKVVv...",
	"..v.vVVVKKKKVVVv.v..",
	".v....vVVVVVVv....v.",
	"v.......vVVv.......v",
	"....................",
]
const SPRITE_COLORS := {
	"K": Color("140a1e"), "V": VOID, "v": Color("6a2fa0"),
	"E": Color("ff3355"), "e": Color("ffb0c0"), "W": Color("d8d0e8"),
}

var hp := 0
var curse_left := 0
var steal_potion: Callable # returns true if the player had a potion to lose


func _init() -> void:
	super()
	accent = PURPLE
	god_name = I18n.t("chaos")


func sprite() -> Array[String]:
	return SPRITE


func sprite_colors() -> Dictionary:
	return SPRITE_COLORS


func glow_colors() -> Dictionary:
	return {"E": Color.WHITE, "e": Color.WHITE}


func reset() -> void:
	super()
	hp = max_hp
	curse_left = 0


func is_cursed() -> bool:
	return curse_left > 0


# Damage (and score) from merges while the curse lasts.
func apply_curse(points: int) -> int:
	return roundi(points * curse_multiplier) if is_cursed() else points


func tick() -> void:
	super()
	if curse_left > 0:
		curse_left -= 1


# Returns true when this hit finished him.
func take_damage(amount: int) -> bool:
	if amount <= 0 or hp <= 0:
		return false
	hp = maxi(hp - amount, 0)
	_glow = 0.6
	# next to his health bar, not over his face
	float_text("-%d" % amount, to_effects(global_position + Vector2(FRAME + 58, 32)), 2, Color("ff6680"))
	return hp == 0


func after_move() -> bool:
	if hp <= 0 or _moves_since_action <= cooldown_moves:
		return false

	var moves := [[halve_chance, "halve"], [split_chance, "split"], [flood_chance, "flood"]]
	moves.shuffle()
	for move in moves:
		if randf() >= move[0]:
			continue
		var did := false
		match move[1]:
			"halve":
				did = await _halve()
			"split":
				did = await _split()
			"flood":
				did = await _flood()
		if did:
			return true
	return false


# Anti-Zeus: halves a tile, preferring one that was about to merge.
# The biggest tile on the board, and any finished 8192, is spared.
func _halve() -> bool:
	var tiles := board.tiles().filter(func(t: Tile) -> bool: return t.level >= 1 and t.level < Board.MAX_LEVEL)
	if tiles.size() < 2:
		return false
	tiles.sort_custom(func(a: Tile, b: Tile) -> bool: return a.level > b.level)
	tiles.remove_at(0)

	var spoilers := tiles.filter(func(t: Tile) -> bool:
		return board.neighbors(t.grid_pos).any(func(n: Tile) -> bool: return n.level == t.level))
	var tile: Tile = (spoilers if not spoilers.is_empty() else tiles).pick_random()
	var steps := 2 if randf() < quarter_chance and tile.level >= 2 else 1

	acted()
	sfx.play("zap", 0.6)
	sfx.buzz(40)
	var to := tile_point(tile)
	spawn_bolt(portrait_point(), to, PURPLE, Color("ffb0c0"))
	strobe(VOID, [0.6, 0.0, 0.4, 0.0])
	Fx.shake(shaker, 3, 0.3)
	await wait(0.12)

	if is_instance_valid(tile):
		board.downgrade(tile, steps)
		Fx.sparks(effects, to, PURPLE, 12, 20.0)
		float_text("/%d" % (1 << steps), to, 3, PURPLE)
	await wait(0.5)
	return true


# Anti-Eros: up to three tiles break into two halves; a potion is stolen.
func _split() -> bool:
	var candidates := board.tiles().filter(func(t: Tile) -> bool:
		return t.level >= 1 and t.level < Board.MAX_LEVEL and _free_neighbor(t.grid_pos) != Vector2i(-1, -1))
	if candidates.is_empty():
		return false
	candidates.shuffle()

	acted()
	sfx.play("shatter")
	sfx.buzz(40)
	banner(I18n.t("banner_split"), PURPLE)
	await wait(0.2)

	for tile in candidates.slice(0, 3):
		var free := _free_neighbor(tile.grid_pos)
		if not is_instance_valid(tile) or free.x < 0:
			continue
		Fx.sparks(effects, tile_point(tile), PURPLE, 8, 14.0)
		board.downgrade(tile, 1)
		board.place_tile(free, tile.level)

	if steal_potion.is_valid() and steal_potion.call():
		float_text(I18n.t("potion_minus"), portrait_point() - Vector2(0, 16), 1, Eros.PINK)
	await wait(0.5)
	return true


# Anti-Ares: 2s pour onto empty cells and the player's hits are weakened.
func _flood() -> bool:
	var empty := board.empty_cells()
	if empty.is_empty():
		return false
	empty.shuffle()

	acted()
	sfx.play("roar", 0.7)
	sfx.buzz(100)
	banner(I18n.t("banner_flood"), PURPLE)
	strobe(VOID, [0.6, 0.0, 0.4, 0.0])
	Fx.shake(shaker, 4, 0.4)
	await wait(0.2)

	for cell in empty.slice(0, 3):
		board.place_tile(cell, 0)
	curse_left = curse_moves
	await wait(0.5)
	return true


func _free_neighbor(p: Vector2i) -> Vector2i:
	var options: Array[Vector2i] = []
	for dir in [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]:
		if board.is_inside(p + dir) and board.tile_at(p + dir) == null:
			options.append(p + dir)
	return options.pick_random() if not options.is_empty() else Vector2i(-1, -1)


# A burst of color as he falls.
func explode() -> void:
	_glow = 1.0
	sfx.play("thunder")
	sfx.play("bonus")
	sfx.buzz(200)
	strobe(Color.WHITE, [0.9, 0.0, 0.7, 0.0, 0.5, 0.0])
	Fx.shake(shaker, 5, 0.6)
	var center := portrait_point() - Vector2(0, 18)
	for color in [PURPLE, Color("ff3355"), Palette.GOLD, Color.WHITE]:
		Fx.sparks(effects, center, color, 16, 40.0)
	await wait(0.6)
