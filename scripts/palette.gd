class_name Palette
extends RefCounted

# One limited palette for the whole game, night-sky-over-Olympos themed.

const BG := Color("1b1030")
const INK := Color("120a1e")
const BOARD := Color("3a2c5e")
const CELL := Color("2a1f48")
const LIGHT := Color("f4ead0")
const DIM := Color("8f84b0")
const DARK_TEXT := Color("3a2a4a")
const GOLD := Color("ffcd4a")
const GOLD_DARK := Color("b5762a")
const BUTTON := Color("7b5cc4")

const TILES: Array[Color] = [
	Color("e8dcc0"), # 2
	Color("e8c890"), # 4
	Color("f0a050"), # 8
	Color("f07838"), # 16
	Color("e84848"), # 32
	Color("c8283c"), # 64
	Color("f8d850"), # 128
	Color("f0c020"), # 256
	Color("d8a018"), # 512
	Color("50c8e8"), # 1024
	Color("a070ff"), # 2048
]
const TILE_BEYOND := Color("f4f0ff")
const DARK_TEXT_LEVELS: Array[int] = [0, 1, 6, 7, 8]


static func tile_color(level: int) -> Color:
	return TILES[level] if level < TILES.size() else TILE_BEYOND


static func tile_text_color(level: int) -> Color:
	if level >= TILES.size():
		return GOLD_DARK
	return DARK_TEXT if level in DARK_TEXT_LEVELS else LIGHT
