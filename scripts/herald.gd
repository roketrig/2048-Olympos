class_name Herald
extends Chaos

# Chaos's herald: a mini boss at the first 512. A hooded shadow with one eye,
# weaker than his master: fewer HP, no splitting, smaller floods and a short
# curse, and halvings never quarter.

const GREEN := Color("8cff9e")
const HOOD_SPRITE: Array[String] = [
	"......vVVVVVVv......",
	".....vVKKKKKKVv.....",
	"....vVKKKKKKKKVv....",
	"...vVKKKKKKKKKKVv...",
	"...VKKKKKKKKKKKKV...",
	"..vVKKKKKKKKKKKKVv..",
	"..VKKKKKKKKKKKKKKV..",
	"..VKKKKEEeeeEEKKKV..",
	"..VKKKKKKEEEKKKKKV..",
	"..VKKKKKKKKKKKKKKV..",
	"..vVKKKKKKKKKKKKVv..",
	"...VVKKKKKKKKKKVV...",
	"..vVVVKKKKKKKKVVVv..",
	".vVVVVVKKKKKKVVVVVv.",
	".VVVVVVVVKKVVVVVVVV.",
	"vVVVVVVVVVVVVVVVVVVv",
	"VVVvVVVVvVVVVvVVVVvV",
	"VVv.vVVv.vVVv.vVVv.V",
	"Vv...vv...vv...vv..v",
	"....................",
]
const HOOD_COLORS := {
	"K": Color("0c0814"), "V": Color("5a3d8a"), "v": Color("8a64c0"),
	"E": GREEN, "e": Color.WHITE,
}


func _init() -> void:
	super()
	accent = GREEN
	max_hp = 500
	halve_chance = 0.05
	quarter_chance = 0.0
	split_chance = 0.0
	flood_chance = 0.04
	flood_count = 2
	curse_moves = 3


func name_key() -> String:
	return "herald"


func intro_card() -> String:
	return "herald_intro"


func victory_card() -> String:
	return "herald_victory"


func banner_key() -> String:
	return "banner_herald"


func bonus() -> int:
	return 512


func pick_mood() -> void:
	mood = "" # the herald just follows orders


func sprite() -> Array[String]:
	return HOOD_SPRITE


func sprite_colors() -> Dictionary:
	return HOOD_COLORS


func glow_colors() -> Dictionary:
	return {"E": Color.WHITE}
