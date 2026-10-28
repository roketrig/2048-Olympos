extends Control

const SAVE_PATH := "user://save.cfg"
const SWIPE_MIN_DISTANCE := 12.0
const SCREEN := Vector2(180, 320) # game area; extra space on tall phones shows the night sky
const BOARD_SIZE := 168.0
const MAX_POTIONS := 3
const HEART_ICON: Array[String] = [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]

var board: Board
var zeus: Zeus
var eros: Eros
var ares: Ares
var gods: Array[God] = []
var sfx: Sfx
var ads: Ads

var score := 0
var hiscore := 0
var sound_on := true
var tutorial_seen := false
var busy := false
var over := false

# love potion: lift a tile off the board and drop it back on any empty cell
var potions := 0
var held_level := -1
var picking := false
var offering := false # first tap on an empty heart offers a rewarded ad
var potion_ads_used := 0
var continued := false # the rewarded "continue" is offered once per game

var _screen: Control
var _shaker: Control
var _score_box: Box
var _score_label: PixelLabel
var _hiscore_label: PixelLabel
var _potion_button: PixelButton
var _held_slot: HeldSlot
var _sound_button: PixelButton
var _hint: PixelLabel
var _game_over: Control
var _game_over_tween: Tween
var _continue_button: PixelButton
var _game_over_panel: Box
var _tutorial: Tutorial
var _game_over_box: Control
var _final_score: PixelLabel
var _swipe_start := Vector2.ZERO
var _swiping := false


func _ready() -> void:
	_load_save()

	sfx = Sfx.new()
	sfx.enabled = sound_on
	add_child(sfx)

	ads = Ads.new()
	add_child(ads)

	_build_ui()
	ads.layout_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	new_game()
	if not tutorial_seen:
		_tutorial.open()


func new_game() -> void:
	score = 0
	over = false
	busy = false
	potions = 0
	held_level = -1
	picking = false
	offering = false
	potion_ads_used = 0
	continued = false
	_update_score_labels()

	if _game_over_tween != null:
		_game_over_tween.kill()
	_game_over.visible = false
	_game_over.modulate.a = 0.0

	for god in gods:
		god.reset()
	board.clear()
	board.spawn_tile()
	board.spawn_tile()
	_refresh_ui()


func try_move(dir: Vector2i) -> void:
	if busy or over:
		return
	picking = false
	offering = false
	if not board.move(dir):
		_refresh_ui()
		return

	var merged := not board.merge_levels.is_empty()
	if merged:
		sfx.play("merge", 1.0 + 0.06 * board.merge_levels.max())
	else:
		sfx.play("move")

	busy = true
	await get_tree().create_timer(Board.MOVE_TIME + 0.02).timeout

	board.spawn_tile()
	if merged and potions < MAX_POTIONS and eros.roll_potion():
		potions += 1
		eros.gift_potion(eros.to_effects(_potion_button.global_position + _potion_button.size / 2.0))

	# every god counts the move, then at most one of them acts
	for god in gods:
		god.tick()
	var order := gods.duplicate()
	order.shuffle()
	for god in order:
		var acted: bool = await god.after_move()
		if acted:
			break

	_refresh_ui()
	await _check_stuck()
	busy = false


func _check_stuck() -> void:
	if board.can_move():
		return
	var rescued: bool = await zeus.try_rescue()
	if not rescued or not board.can_move():
		_show_game_over()


func _on_tap(at: Vector2) -> void:
	if over:
		return

	# tapping a god explains what it does
	var pages := {zeus: Tutorial.PAGE_ZEUS, eros: Tutorial.PAGE_EROS, ares: Tutorial.PAGE_ARES}
	for god in gods:
		if god.get_global_rect().has_point(at):
			sfx.play("click")
			_tutorial.open(pages[god], true)
			return

	if busy:
		return
	var cell := board.cell_at(board.get_global_transform().affine_inverse() * at)
	if cell.x < 0:
		return
	if offering:
		offering = false
		_refresh_ui()

	var tile := board.tile_at(cell)
	if picking and tile != null:
		_lift(tile)
	elif held_level >= 0 and tile == null:
		_drop(cell)


func _lift(tile: Tile) -> void:
	potions -= 1
	picking = false
	held_level = tile.level
	var center := _shaker.get_global_transform().affine_inverse() * (tile.global_position + tile.size / 2.0)
	Fx.sparks(_shaker, center, Eros.PINK, 10, 16.0)
	board.remove_tile(tile)
	sfx.play("lift")
	_refresh_ui()


func _drop(cell: Vector2i) -> void:
	board.place_tile(cell, held_level)
	held_level = -1
	sfx.play("drop")
	_refresh_ui()

	busy = true
	await _check_stuck()
	busy = false


func _on_potion_pressed() -> void:
	if busy or over or held_level >= 0:
		return
	sfx.play("click")

	if potions > 0:
		picking = not picking
	elif offering:
		offering = false
		busy = true
		var earned: bool = await ads.show_rewarded()
		busy = false
		if earned:
			potion_ads_used += 1
			potions += 1
			eros.gift_potion(eros.to_effects(_potion_button.global_position + _potion_button.size / 2.0))
	elif _can_offer_potion_ad():
		offering = true
	_refresh_ui()


func _can_offer_potion_ad() -> bool:
	return potion_ads_used < Ads.REWARDED_POTIONS_PER_GAME and ads.rewarded_ready()


func _input(event: InputEvent) -> void:
	if _tutorial.visible or ads.is_showing():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_UP, KEY_W:
				try_move(Vector2i.UP)
			KEY_DOWN, KEY_S:
				try_move(Vector2i.DOWN)
			KEY_LEFT, KEY_A:
				try_move(Vector2i.LEFT)
			KEY_RIGHT, KEY_D:
				try_move(Vector2i.RIGHT)
	elif event is InputEventScreenTouch and event.index == 0:
		if event.pressed:
			_swipe_start = event.position
			_swiping = true
		elif _swiping:
			_swiping = false
			var delta: Vector2 = event.position - _swipe_start
			if delta.length() < SWIPE_MIN_DISTANCE:
				_on_tap(event.position)
			elif absf(delta.x) > absf(delta.y):
				try_move(Vector2i.RIGHT if delta.x > 0 else Vector2i.LEFT)
			else:
				try_move(Vector2i.DOWN if delta.y > 0 else Vector2i.UP)


func _on_score_gained(points: int) -> void:
	score += ares.apply_rage(points)
	if score > hiscore:
		hiscore = score
		_save()
	_update_score_labels()


func _on_tile_merged(tile: Tile) -> void:
	var center := tile.global_position + tile.size / 2.0
	var local := _shaker.get_global_transform().affine_inverse() * center
	Fx.sparks(_shaker, local, Palette.tile_color(tile.level), 6, 14.0)


func _update_score_labels() -> void:
	_score_label.text = str(score)
	_hiscore_label.text = str(hiscore)


func _refresh_ui() -> void:
	var can_offer := potions == 0 and _can_offer_potion_ad()
	_potion_button.text = "AD" if can_offer else "x%d" % potions
	_potion_button.disabled = held_level >= 0 or (potions == 0 and not can_offer)
	_potion_button.highlighted = picking or offering
	_potion_button.queue_redraw()

	_held_slot.level = held_level
	_held_slot.waiting = picking
	_held_slot.queue_redraw()

	_score_box.hot = ares.is_raging()
	_score_box.queue_redraw()

	if offering:
		_hint.text = "TAP AGAIN: AD FOR A POTION"
		_hint.color = Eros.PINK
	elif picking:
		_hint.text = "TAP A TILE TO LIFT IT"
		_hint.color = Eros.PINK
	elif held_level >= 0:
		_hint.text = "TAP EMPTY CELL TO DROP"
		_hint.color = Eros.PINK
	elif ares.is_raging():
		_hint.text = "ARES RAGE: SCORE x%s" % str(ares.score_multiplier)
		_hint.color = Ares.RED
	else:
		_hint.text = "TAP A GOD TO SEE WHAT IT DOES" if score == 0 else "SWIPE TO MERGE TILES"
		_hint.color = Palette.DIM


func _show_game_over() -> void:
	over = true
	sfx.play("over")
	_final_score.text = "SCORE %d" % score
	_continue_button.visible = not continued and ads.rewarded_ready()
	_game_over_panel.size.y = 104 if _continue_button.visible else 80
	ads.count_game_over()
	_game_over.visible = true
	_game_over_tween = create_tween()
	_game_over_tween.tween_interval(0.8)
	_game_over_tween.tween_property(_game_over, "modulate:a", 1.0, 0.3)


# Interstitials only ever show here, on the way into a new game, and only as
# often as the caps in Ads allow.
func _on_try_again() -> void:
	if busy:
		return
	sfx.play("click")
	busy = true
	await ads.show_interstitial_if_due()
	new_game()


# Rewarded continue: Zeus frees the board once per game.
func _on_continue() -> void:
	if busy:
		return
	sfx.play("click")
	busy = true
	var earned: bool = await ads.show_rewarded()
	if earned:
		continued = true
		over = false
		_game_over_tween.kill()
		_game_over.visible = false
		_game_over.modulate.a = 0.0
		await zeus.revive()
		_refresh_ui()
		if not board.can_move():
			_show_game_over()
	busy = false


func _toggle_sound() -> void:
	sound_on = not sound_on
	sfx.enabled = sound_on
	_sound_button.text = "SFX ON" if sound_on else "SFX OFF"
	sfx.play("click")
	_save()


func _load_save() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	hiscore = config.get_value("game", "hiscore", 0)
	sound_on = config.get_value("settings", "sound", true)
	tutorial_seen = config.get_value("settings", "tutorial_seen", false)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "hiscore", hiscore)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "tutorial_seen", tutorial_seen)
	config.save(SAVE_PATH)


# --- UI ---------------------------------------------------------------------

# Fits the game between the ad banners and the notch / home indicator. Short
# screens drop the top banner first; if it still does not fit, the game shrinks.
func _layout() -> void:
	var viewport := get_viewport_rect().size
	if ads.top_banner and viewport.y - ads.top_inset() - ads.bottom_inset() < SCREEN.y:
		ads.top_banner = false # emits layout_changed, which lays out again
		return

	var top := ads.top_inset()
	var area := Rect2(0, top, viewport.x, viewport.y - top - ads.bottom_inset())
	var fit := minf(1.0, minf(area.size.x / SCREEN.x, area.size.y / SCREEN.y))

	# keep every game pixel a whole number of screen pixels so the art stays
	# crisp (phones are ~6 screen pixels per game pixel; tiny previews skip this)
	var window_scale := DisplayServer.window_get_size().y / viewport.y
	if window_scale * fit >= 3.0:
		fit = floorf(window_scale * fit) / window_scale
	var origin := ((area.position + (area.size - SCREEN * fit) / 2.0) * window_scale).floor() / window_scale
	for box in [_screen, _game_over_box, _tutorial.box]:
		box.scale = Vector2(fit, fit)
		box.position = origin


func _build_ui() -> void:
	add_child(Stars.new())

	_screen = Control.new()
	_screen.size = SCREEN
	add_child(_screen)

	_shaker = Control.new()
	_shaker.size = SCREEN
	_screen.add_child(_shaker)

	# header: title + score boxes
	_place(_shaker, PixelLabel.new("2048", 3, Palette.GOLD, Palette.GOLD_DARK), Vector2(6, 6))
	_place(_shaker, PixelLabel.new("OLYMPOS", 1, Palette.DIM), Vector2(7, 31))

	var help := PixelButton.new("?", 13, 12, Palette.CELL.lightened(0.15))
	help.pressed.connect(func() -> void:
		sfx.play("click")
		_tutorial.open()
	)
	_place(_shaker, help, Vector2(53, 29))
	_score_box = _make_score_box(Vector2(80, 6), "SCORE")
	_score_label = _score_box.value
	_hiscore_label = _make_score_box(Vector2(128, 6), "BEST").value

	# the gods
	zeus = Zeus.new()
	eros = Eros.new()
	ares = Ares.new()
	gods = [zeus, eros, ares]
	for i in gods.size():
		_place(_shaker, gods[i], Vector2(6 + i * 61, 42))

	# board
	board = Board.new()
	board.setup(BOARD_SIZE)
	board.score_gained.connect(_on_score_gained)
	board.merged.connect(_on_tile_merged)
	_place(_shaker, board, Vector2(6, 104))

	# bottom bar: potion, held tile, new game, sound
	_potion_button = PixelButton.new("x0", 32, 20, Palette.CELL.lightened(0.15))
	_potion_button.icon = HEART_ICON
	_potion_button.icon_color = Eros.PINK
	_potion_button.pressed.connect(_on_potion_pressed)
	_place(_shaker, _potion_button, Vector2(6, 278))

	_held_slot = HeldSlot.new()
	_held_slot.size = Vector2(32, 20)
	_place(_shaker, _held_slot, Vector2(40, 278))

	var new_button := PixelButton.new("NEW GAME", 54, 20)
	new_button.pressed.connect(func() -> void:
		sfx.play("click")
		new_game()
	)
	_place(_shaker, new_button, Vector2(74, 278))

	_sound_button = PixelButton.new("SFX ON" if sound_on else "SFX OFF", 44, 20, Palette.CELL.lightened(0.15))
	_sound_button.pressed.connect(_toggle_sound)
	_place(_shaker, _sound_button, Vector2(130, 278))

	_hint = _centered("SWIPE TO MERGE TILES", 1, Palette.DIM, SCREEN.x)
	_place(_shaker, _hint, Vector2(0, 306))

	# effects layer above the board (lightning, hearts, sparks, texts)
	var effects := Control.new()
	effects.size = SCREEN
	_shaker.add_child(effects)

	# full-screen strobe for big moments
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	for god in gods:
		god.board = board
		god.effects = effects
		god.shaker = _shaker
		god.flash = flash
		god.sfx = sfx

	# game over overlay
	_game_over = Dim.new()
	_game_over.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(_game_over)

	_game_over_box = Control.new()
	_game_over_box.size = SCREEN
	_game_over.add_child(_game_over_box)

	_game_over_panel = Box.new()
	_game_over_panel.size = Vector2(140, 104)
	_place(_game_over_box, _game_over_panel, Vector2(20, 116))
	_place(_game_over_box, _centered("GAME OVER", 2, Palette.GOLD, SCREEN.x, Palette.INK), Vector2(0, 128))
	_final_score = _centered("SCORE 0", 1, Palette.LIGHT, SCREEN.x)
	_place(_game_over_box, _final_score, Vector2(0, 152))

	var again := PixelButton.new("TRY AGAIN", 70, 18)
	again.pressed.connect(_on_try_again)
	_place(_game_over_box, again, Vector2(55, 168))

	_continue_button = PixelButton.new("WATCH AD TO CONTINUE", 128, 18, Palette.GOLD_DARK)
	_continue_button.pressed.connect(_on_continue)
	_place(_game_over_box, _continue_button, Vector2(26, 194))

	_ignore_mouse(self)

	# how-to-play pages on top of everything; blocks touches to the game below
	_tutorial = Tutorial.new()
	_tutorial.sfx = sfx
	_tutorial.ads = ads
	_ignore_mouse(_tutorial.box)
	_tutorial.closed.connect(func() -> void:
		if not tutorial_seen:
			tutorial_seen = true
			_save()
	)
	add_child(_tutorial)


func _make_score_box(at: Vector2, caption: String) -> Box:
	var box := Box.new()
	box.size = Vector2(46, 24)
	_place(_shaker, box, at)
	_place(box, _centered(caption, 1, Palette.DIM, box.size.x), Vector2(0, 3))

	box.value = _centered("0", 1, Palette.LIGHT, box.size.x)
	_place(box, box.value, Vector2(0, 13))
	return box


func _centered(text: String, px: int, color: Color, width: float, shadow := Color.TRANSPARENT) -> PixelLabel:
	var label := PixelLabel.new(text, px, color, shadow)
	label.fixed_width = width
	return label


func _place(parent: Control, child: Control, at: Vector2) -> void:
	child.position = at
	parent.add_child(child)


# Everything except buttons lets touches through, so swipes work anywhere.
func _ignore_mouse(node: Node) -> void:
	if node is Control and not node is BaseButton:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)


# Panel background; turns red while Ares rages (for the score box).
class Box extends Control:
	var value: PixelLabel
	var hot := false

	func _draw() -> void:
		var color := Ares.RED.darkened(0.35) if hot else Palette.BOARD
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), color)
		draw_rect(Rect2(1, 1, size.x - 2, 1), color.lightened(0.15))


# Shows the tile lifted with a love potion.
class HeldSlot extends Control:
	var level := -1
	var waiting := false

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Palette.CELL)
		if level >= 0:
			Tile.draw_face(self, Rect2(2, 2, size.x - 4, size.y - 4), level)
		elif waiting:
			draw_rect(Rect2(0, 0, size.x, size.y), Eros.PINK, false, 1.0)
			PixelFont.draw_centered(self, "?", Rect2(Vector2.ZERO, size), 1, Eros.PINK)
		else:
			PixelFont.draw_centered(self, "-", Rect2(Vector2.ZERO, size), 1, Palette.DIM)


# Darkened scanline backdrop for the game over screen.
class Dim extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.6))
		for y in range(0, int(size.y), 2):
			draw_rect(Rect2(0, y, size.x, 1), Color(Palette.INK, 0.35))


# Twinkling night sky behind the game.
class Stars extends Control:
	var _stars: Array[Vector3] = [] # x, y, brightness
	var _timer := 0.0

	func _ready() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		resized.connect(_scatter)
		_scatter()

	func _scatter() -> void:
		_stars.clear()
		for i in int(size.x * size.y / 900.0):
			_stars.append(Vector3(randi() % maxi(int(size.x), 1), randi() % maxi(int(size.y), 1), randf()))
		queue_redraw()

	func _process(delta: float) -> void:
		_timer += delta
		if _timer < 0.4 or _stars.is_empty():
			return
		_timer = 0.0
		for i in 3:
			var index := randi() % _stars.size()
			var star := _stars[index]
			star.z = randf()
			_stars[index] = star
		queue_redraw()

	func _draw() -> void:
		for star in _stars:
			draw_rect(Rect2(star.x, star.y, 1, 1), Palette.LIGHT if star.z > 0.8 else Palette.DIM.darkened(0.3))
