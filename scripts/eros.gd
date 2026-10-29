class_name Eros
extends God

# Eros shoots hearts at every pair of equal neighbors and merges them all at
# once. He also hands out love potions as the player keeps merging.

@export_range(0.0, 1.0) var merge_chance := 0.065
@export var cooldown_moves := 4
@export_range(0.0, 1.0) var potion_chance := 0.06 # per move that merged something

const PINK := Color("f04870")
const SPRITE: Array[String] = [
	"......yYYYYYYy......",
	"....yYYyYYYYyYYy....",
	"...yYYYYYyYYYYYYy...",
	"..yYYyYYYYYYYyYYYy..",
	"..YYYYSSSSSSSSYYYY..",
	".yYYSSSSSSSSSSSSYYy.",
	".YYSSSSSSSSSSSSSSYY.",
	".YYSSSESSSSSSESSSYY.",
	".yYSSSPSSSSSSPSSSYy.",
	"..YSRRSSSSSSSSRRSY..",
	"..ySSSSSSssSSSSSSy..",
	"...SSSSMSSSSMSSSS...",
	"...sSSSSMMMMSSSSs...",
	"....sSSSSSSSSSSs....",
	".....ssSSSSSSss.....",
	".......ssssss.......",
	".......HH.HH........",
	".......HHHHH........",
	"........HHH.........",
	".........H..........",
]
const SPRITE_COLORS := {
	"Y": Color("f8d860"), "y": Color("c89a30"),
	"S": Color("f2c09a"), "s": Color("c98563"),
	"E": Color("3a2a4a"), "P": Color("3a2a4a"),
	"R": Color("f07890"), "M": Color("a03050"),
	"H": PINK,
}
const HEART: Array[String] = [".#.#.", "#####", ".###.", "..#.."]


func _init() -> void:
	super()
	god_name = "EROS"
	accent = PINK


func sprite() -> Array[String]:
	return SPRITE


func sprite_colors() -> Dictionary:
	return SPRITE_COLORS


func glow_colors() -> Dictionary:
	return {"P": PINK, "H": Color.WHITE}


func after_move() -> bool:
	if not wants_to_act(merge_chance, cooldown_moves):
		return false

	var pairs := find_pairs()
	if pairs.is_empty():
		return false

	acted()
	sfx.play("love")
	banner(I18n.t("banner_love"), PINK)

	var from := portrait_point()
	for pair in pairs:
		var mid := (tile_point(pair[0]) + tile_point(pair[1])) / 2.0
		_fly_heart(from, mid.floor())

	await wait(0.3)

	for pair in pairs:
		if is_instance_valid(pair[0]) and is_instance_valid(pair[1]):
			board.merge_into(pair[0], pair[1])
	board.unlock_all()
	sfx.play("merge", 1.2)

	await wait(0.35)
	return true


# Every pair of equal neighbors, each tile used at most once.
func find_pairs() -> Array:
	var used := {}
	var pairs := []
	var pool := board.tiles()
	pool.shuffle()
	for tile in pool:
		if used.has(tile) or tile.level >= Board.MAX_LEVEL:
			continue
		var partners := board.neighbors(tile.grid_pos)
		partners.shuffle()
		for other in partners:
			if not used.has(other) and other.level == tile.level:
				pairs.append([tile, other])
				used[tile] = true
				used[other] = true
				break
	return pairs


# Rolled after a move that merged; returns true if a potion dropped.
func roll_potion() -> bool:
	return randf() < potion_chance


# A heart flies from Eros to `to` (the potion slot) when a potion drops.
func gift_potion(to: Vector2) -> void:
	_glow = 1.0
	sfx.play("potion")
	_fly_heart(portrait_point(), to.floor())
	float_text(I18n.t("potion_plus"), to - Vector2(0, 12), 1, PINK)


func _fly_heart(from: Vector2, to: Vector2) -> void:
	var heart := PixelSprite.new()
	heart.rows = HEART
	heart.colors = {"#": PINK}
	heart.position = from - Vector2(2, 2)
	effects.add_child(heart)

	# arc: x travels linearly while y eases, which bends the path
	var tween := heart.create_tween().set_parallel()
	tween.tween_property(heart, "position:x", to.x - 2, 0.28)
	tween.tween_property(heart, "position:y", to.y - 2, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.chain().tween_callback(func() -> void:
		Fx.sparks(effects, to, PINK, 8, 14.0)
		heart.queue_free()
	)
