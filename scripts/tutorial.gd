class_name Tutorial
extends Control

# "How to play" pages. Opened on first launch, from the ? button, and on a
# single page when the player taps a god's portrait.

signal closed

const PAGE_WIDTH := 164.0
const PAGES := [
	{"title": "HOW TO PLAY", "art": "merge", "lines": [
		"SWIPE TO MOVE ALL TILES.",
		"EQUAL NUMBERS MERGE.",
		"REACH 2048!",
		"",
		"THE GODS OF OLYMPOS",
		"WATCH OVER YOU...",
	]},
	{"title": "ZEUS", "art": "zeus", "lines": [
		"STRIKES A TILE WITH",
		"LIGHTNING: x2 OR x4.",
		"RARELY THE BOLT CHAINS",
		"FROM TILE TO TILE, x2.",
		"SAVES YOU ONCE WHEN",
		"NO MOVES ARE LEFT.",
	]},
	{"title": "EROS", "art": "eros", "lines": [
		"MERGES EVERY PAIR OF",
		"EQUAL NEIGHBORS",
		"AT ONCE.",
		"",
		"WHEN YOU MERGE, HE MAY",
		"GIVE YOU A LOVE POTION.",
	]},
	{"title": "LOVE POTION", "art": "potion", "lines": [
		"TAP THE HEART BUTTON,",
		"THEN TAP A TILE TO",
		"LIFT IT OFF THE BOARD.",
		"",
		"TAP AN EMPTY CELL TO",
		"PUT IT BACK, ANYTIME.",
	]},
	{"title": "ARES", "art": "ares", "lines": [
		"HIS WAR CRY BLOWS",
		"ALL 2S OFF THE BOARD.",
		"",
		"THEN FOR 8 MOVES",
		"YOUR SCORE IS x1.5!",
		"",
	]},
]
const PAGE_ZEUS := 1
const PAGE_EROS := 2
const PAGE_ARES := 4

var sfx: Sfx
var box: Control # screen-sized; positioned by main like the rest of the UI

var _page := 0
var _single := false
var _content: Control
var _back: PixelButton
var _next: PixelButton


func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visible = false

	box = Control.new()
	box.size = Vector2(180, 320)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)

	var panel := Card.new()
	panel.size = Vector2(PAGE_WIDTH, 240)
	panel.position = Vector2(8, 40)
	box.add_child(panel)

	_content = Control.new()
	_content.size = Vector2(180, 320)
	_content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(_content)

	_back = PixelButton.new("BACK", 50, 18, Palette.CELL.lightened(0.15))
	_back.position = Vector2(16, 254)
	_back.pressed.connect(func() -> void: _turn(-1))
	box.add_child(_back)

	_next = PixelButton.new("NEXT", 50, 18)
	_next.position = Vector2(114, 254)
	_next.pressed.connect(func() -> void: _turn(1))
	box.add_child(_next)


func open(page := 0, single := false) -> void:
	_page = page
	_single = single
	visible = true
	_show_page()


func _turn(step: int) -> void:
	sfx.play("click")
	if _single or _page + step >= PAGES.size():
		visible = false
		closed.emit()
		return
	_page = clampi(_page + step, 0, PAGES.size() - 1)
	_show_page()


func _show_page() -> void:
	for child in _content.get_children():
		child.queue_free()

	var page: Dictionary = PAGES[_page]
	var accent := _accent(page["art"])

	_add_label(page["title"], 2, accent, Vector2(0, 50))
	_add_art(page["art"])

	var lines: Array = page["lines"]
	for i in lines.size():
		_add_label(lines[i], 1, Palette.LIGHT, Vector2(0, 142 + i * 10))

	if not _single:
		var dots := Dots.new()
		dots.count = PAGES.size()
		dots.current = _page
		dots.position = Vector2(0, 240)
		dots.size = Vector2(180, 4)
		_content.add_child(dots)

	_back.visible = not _single and _page > 0
	_next.text = "OK" if _single else ("PLAY" if _page == PAGES.size() - 1 else "NEXT")
	_next.position.x = 65 if _single else 114


func _add_label(text: String, px: int, color: Color, at: Vector2) -> void:
	var label := PixelLabel.new(text, px, color, Palette.INK)
	label.fixed_width = 180
	label.position = at
	_content.add_child(label)


func _add_art(art: String) -> void:
	var node: Control
	match art:
		"zeus":
			node = Zeus.new()
		"eros":
			node = Eros.new()
		"ares":
			node = Ares.new()
		_:
			var drawing := Art.new()
			drawing.kind = art
			drawing.size = Vector2(150, 46)
			node = drawing
	node.position = Vector2(floorf((180 - node.size.x) / 2.0), 74)
	_content.add_child(node)


func _accent(art: String) -> Color:
	match art:
		"eros", "potion":
			return Eros.PINK
		"ares":
			return Ares.RED
	return Palette.GOLD


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.75))


# Card background.
class Card extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Palette.GOLD_DARK)
		draw_rect(Rect2(2, 2, size.x - 4, size.y - 4), Palette.BOARD)
		draw_rect(Rect2(2, 2, size.x - 4, 1), Palette.BOARD.lightened(0.15))


# Page indicator.
class Dots extends Control:
	var count := 0
	var current := 0

	func _draw() -> void:
		var x := floorf((size.x - (count * 6 - 2)) / 2.0)
		for i in count:
			draw_rect(Rect2(x + i * 6, 0, 4, 4), Palette.GOLD if i == current else Palette.DIM.darkened(0.3))


# Small illustrations: "2 + 2 > 4" and the potion lift.
class Art extends Control:
	var kind := ""

	func _draw() -> void:
		var tile := Vector2(30, 30)
		var y := 8.0
		if kind == "merge":
			Tile.draw_face(self, Rect2(Vector2(15, y), tile), 0)
			PixelFont.draw(self, "+", Vector2(51, y + 11), 1, Palette.LIGHT)
			Tile.draw_face(self, Rect2(Vector2(63, y), tile), 0)
			PixelFont.draw(self, ">", Vector2(99, y + 11), 1, Palette.LIGHT)
			Tile.draw_face(self, Rect2(Vector2(111, y), tile), 1)
		elif kind == "potion":
			var heart: Array[String] = [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
			for row in heart.size():
				for col in heart[row].length():
					if heart[row][col] == "#":
						draw_rect(Rect2(Vector2(14 + col * 3, y + 6 + row * 3), Vector2(3, 3)), Eros.PINK)
			PixelFont.draw(self, ">", Vector2(41, y + 11), 1, Palette.LIGHT)
			Tile.draw_face(self, Rect2(Vector2(53, y), tile), 3)
			PixelFont.draw(self, ">", Vector2(89, y + 11), 1, Palette.LIGHT)
			draw_rect(Rect2(Vector2(101, y), tile), Palette.CELL)
			draw_rect(Rect2(Vector2(101, y), tile), Eros.PINK, false, 1.0)
			PixelFont.draw_centered(self, "?", Rect2(Vector2(101, y), tile), 1, Eros.PINK)
