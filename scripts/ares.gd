class_name Ares
extends God

# Ares lets out a war cry: every 2 on the board is blown away and, for a few
# moves, all points scored are multiplied.

@export_range(0.0, 1.0) var scream_chance := 0.07
@export var cooldown_moves := 6
@export var rage_moves := 8
@export var score_multiplier := 1.5

const RED := Color("e03030")
const SPRITE: Array[String] = [
	".....RRRRRRRRRR.....",
	"....RRrRRrRRrRRR....",
	".....rrrrrrrrrr.....",
	"....BBBBBBBBBBBB....",
	"...BBbBBBBBBBBbBB...",
	"..BBBBBBBBBBBBBBBB..",
	"..BBEEEBBBBBBEEEBB..",
	"..BBSPSSbBBbSSPSBB..",
	"..BbSSSSbBBbSSSSbB..",
	"..BbSSSSSbbSSSSSbB..",
	"..BbDDSSSSSSSSDDbB..",
	"..BbDDDMMMMMMDDDbB..",
	"..BbDDDDDDDDDDDDbB..",
	"..BB.DDDDDDDDDD.BB..",
	"..BB..DDDDDDDD..BB..",
	"..Bb...DDDDDD...bB..",
	"...b....DDDD....b...",
	"....................",
	"....................",
	"....................",
]
const SCREAM_ROWS := {
	11: "..BbDDMMMMMMMMDDbB..",
	12: "..BbDDMOOOOOOMDDbB..",
	13: "..BB.DMMMMMMMMD.BB..",
}
const SPRITE_COLORS := {
	"R": RED, "r": Color("a01828"),
	"B": Color("d09040"), "b": Color("8a5a28"),
	"S": Color("e0a070"), "E": Color("2a1a2a"), "P": Color("2a1a2a"),
	"D": Color("4a2a20"), "M": Color("2a1a2a"), "O": Color("c02020"),
}

var rage_left := 0

var _screaming := false
var _scream_sprite: Array[String] = []


func _init() -> void:
	super()
	god_name = "ARES"
	accent = RED
	_scream_sprite = SPRITE.duplicate()
	for row in SCREAM_ROWS:
		_scream_sprite[row] = SCREAM_ROWS[row]


func sprite() -> Array[String]:
	return _scream_sprite if _screaming else SPRITE


func sprite_colors() -> Dictionary:
	return SPRITE_COLORS


func glow_colors() -> Dictionary:
	return {"P": Color("ff4040")}


func reset() -> void:
	super()
	rage_left = 0


func is_raging() -> bool:
	return rage_left > 0


func apply_rage(points: int) -> int:
	return roundi(points * score_multiplier) if is_raging() else points


func tick() -> void:
	super()
	if rage_left > 0:
		rage_left -= 1
		_update_status()


func after_move() -> bool:
	if is_raging() or not wants_to_act(scream_chance, cooldown_moves):
		return false

	# only worth it if there are 2s to clear and something would remain
	var twos := board.tiles().filter(func(t: Tile) -> bool: return t.level == 0)
	if twos.is_empty() or twos.size() == board.tiles().size():
		return false

	acted()
	_screaming = true
	queue_redraw()
	sfx.play("roar")
	banner("ARES ROARS!", RED)
	strobe(RED, [0.6, 0.0, 0.4, 0.0, 0.3, 0.0])
	Fx.shake(shaker, 4, 0.5)

	await wait(0.2)

	for tile in twos:
		if is_instance_valid(tile):
			Fx.sparks(effects, tile_point(tile), RED, 8, 16.0)
			board.remove_tile(tile)
	sfx.play("shatter")

	rage_left = rage_moves
	_update_status()

	await wait(0.5)
	_screaming = false
	queue_redraw()
	return true


func _update_status() -> void:
	status = "x%s %d" % [str(score_multiplier), rage_left] if rage_left > 0 else ""
