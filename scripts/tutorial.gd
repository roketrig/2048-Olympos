class_name Tutorial
extends Control

# "How to play" pages (texts live in I18n). Opened on first launch, from the
# ? button, and on a single page when the player taps a god's portrait. Also
# holds the credits/licenses, privacy and language buttons.

signal closed
signal language_changed

const PAGE_WIDTH := 164.0
const PAGE_ZEUS := 1
const PAGE_EROS := 2
const PAGE_ARES := 4

var sfx: Sfx
var ads: Ads
var box: Control # screen-sized; positioned by main like the rest of the UI

var _page := 0
var _single := false
var _custom := {} # a page outside the regular ones (the Chaos card)
var _content: Control
var _back: PixelButton
var _next: PixelButton
var _privacy: PixelButton
var _credits_button: PixelButton
var _language: PixelButton
var _credits: Control


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

	_back = PixelButton.new("BACK", 44, 18, Palette.CELL.lightened(0.15))
	_back.position = Vector2(14, 254)
	_back.pressed.connect(func() -> void: _turn(-1))
	box.add_child(_back)

	_next = PixelButton.new("NEXT", 44, 18)
	_next.position = Vector2(122, 254)
	_next.pressed.connect(func() -> void: _turn(1))
	box.add_child(_next)

	_credits_button = PixelButton.new("", 56, 16, Palette.CELL)
	_credits_button.pressed.connect(func() -> void:
		sfx.play("click")
		_show_credits()
	)
	box.add_child(_credits_button)

	# consent can be changed here when the ad SDK says it applies (UMP)
	_privacy = PixelButton.new("", 56, 16, Palette.CELL)
	_privacy.pressed.connect(func() -> void:
		sfx.play("click")
		ads.show_privacy_options()
	)
	box.add_child(_privacy)

	_language = PixelButton.new("", 24, 16, Palette.CELL)
	_language.pressed.connect(func() -> void:
		sfx.play("click")
		var index := I18n.LANGUAGES.find(I18n.lang)
		I18n.lang = I18n.LANGUAGES[(index + 1) % I18n.LANGUAGES.size()]
		language_changed.emit()
		_show_page()
	)
	box.add_child(_language)


func open(page := 0, single := false) -> void:
	_page = page
	_single = single
	_custom = {}
	visible = true
	_show_page()


func open_chaos() -> void:
	open(0, true)
	_custom = I18n.chaos_page()
	_show_page()


func close() -> void:
	_close_credits()
	visible = false
	closed.emit()


func credits_open() -> bool:
	return _credits != null


func _turn(step: int) -> void:
	sfx.play("click")
	if _single or _page + step >= I18n.pages().size():
		close()
		return
	_page = clampi(_page + step, 0, I18n.pages().size() - 1)
	_show_page()


func _show_page() -> void:
	for child in _content.get_children():
		child.queue_free()

	var pages := I18n.pages()
	var page: Dictionary = _custom if not _custom.is_empty() else pages[_page]
	var accent := _accent(page["art"])

	_add_label(page["title"], 2, accent, Vector2(0, 50))
	_add_art(page["art"])

	var lines: Array = page["lines"]
	for i in lines.size():
		_add_label(lines[i], 1, Palette.LIGHT, Vector2(0, 142 + i * 10))

	if not _single:
		var dots := Dots.new()
		dots.count = pages.size()
		dots.current = _page
		dots.position = Vector2(0, 244)
		dots.size = Vector2(180, 4)
		_content.add_child(dots)

	_back.visible = not _single and _page > 0
	_back.text = I18n.t("back")
	_next.text = I18n.t("ok") if _single else I18n.t("play" if _page == pages.size() - 1 else "next")
	_next.position.x = 68 if _single else 122

	# extra row: credits, privacy (only where consent applies), language
	_credits_button.text = I18n.t("credits")
	_privacy.text = I18n.t("privacy")
	_language.text = I18n.lang.to_upper()
	_credits_button.visible = not _single
	_privacy.visible = not _single and ads != null and ads.privacy_options_required()
	_language.visible = not _single
	var row: Array[PixelButton] = []
	for button in [_credits_button, _privacy, _language]:
		if button.visible:
			row.append(button)
	var width := 0.0
	for button in row:
		width += button.size.x + 4.0
	var x := floorf(8 + (PAGE_WIDTH - width + 4.0) / 2.0)
	for button in row:
		button.position = Vector2(x, 222)
		x += button.size.x + 4.0


# --- credits ------------------------------------------------------------------

func _show_credits() -> void:
	_credits = Control.new()
	_credits.size = box.size
	box.add_child(_credits)

	var panel := Card.new()
	panel.size = Vector2(PAGE_WIDTH, 240)
	panel.position = Vector2(8, 40)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_credits.add_child(panel)

	var lines := [
		[I18n.t("credits"), 2, Palette.GOLD, 50],
		["2048 OLYMPOS", 1, Palette.LIGHT, 72],
		[I18n.t("credits_by"), 1, Palette.DIM, 86],
		["BUĞRA KASARCI", 1, Palette.LIGHT, 96],
		[I18n.t("credits_engine"), 1, Palette.DIM, 110],
		[I18n.t("credits_licenses"), 1, Palette.DIM, 124],
	]
	for line in lines:
		var label := PixelLabel.new(line[0], line[1], line[2], Palette.INK)
		label.fixed_width = 180
		label.position = Vector2(0, line[3])
		_credits.add_child(label)

	# the full license texts, scrollable (Godot's MIT license and its parts)
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(14, 136)
	scroll.size = Vector2(152, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_credits.add_child(scroll)

	var text := Label.new()
	text.text = _license_text()
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size = Vector2(144, 0)
	text.add_theme_font_size_override("font_size", 5)
	text.add_theme_color_override("font_color", Palette.LIGHT)
	scroll.add_child(text)

	var back := PixelButton.new(I18n.t("back"), 44, 18, Palette.CELL.lightened(0.15))
	back.position = Vector2(68, 254)
	back.pressed.connect(func() -> void:
		sfx.play("click")
		_close_credits()
	)
	_credits.add_child(back)


func _close_credits() -> void:
	if _credits != null:
		_credits.queue_free()
		_credits = null


static func _license_text() -> String:
	var parts := PackedStringArray()
	parts.append("2048 Olympos (c) 2026 Buğra Kasarcı.")
	parts.append("This game uses Godot Engine, available under the following license:")
	parts.append(Engine.get_license_text())
	parts.append("Godot Engine includes third-party components:")
	for component in Engine.get_copyright_info():
		for part in component["parts"]:
			parts.append("%s
(c) %s
License: %s" % [component["name"], ", ".join(part["copyright"]), part["license"]])
	var licenses := Engine.get_license_info()
	for name in licenses:
		parts.append("--- %s ---
%s" % [name, licenses[name]])
	return "

".join(parts)


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
		"chaos":
			node = Chaos.new()
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
		"chaos":
			return Chaos.PURPLE
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
