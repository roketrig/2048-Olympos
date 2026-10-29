extends Control

const SAVE_PATH := "user://save.cfg" # settings and best score
const GAME_PATH := "user://game.cfg" # the game in progress, to resume after the app closes
const SWIPE_MIN_DISTANCE := 12.0
const SCREEN := Vector2(180, 320) # game area; extra space on tall phones shows the night sky
const BOARD_SIZE := 168.0
const MAX_POTIONS := 3
const BOSS_LEVEL := 10 # the first 2048 tile wakes Chaos
const BOSS_BONUS := 2048
const HEART_ICON: Array[String] = [".##.##.", "#######", "#######", ".#####.", "..###..", "...#..."]
const SOUND_ON_ICON: Array[String] = ["..#....", ".##..#.", "###...#", "###...#", "###...#", ".##..#.", "..#...."]
const SOUND_OFF_ICON: Array[String] = ["..#....", ".##....", "###.#.#", "###..#.", "###.#.#", ".##....", "..#...."]

var board: Board
var zeus: Zeus
var eros: Eros
var ares: Ares
var chaos: Chaos
var gods: Array[God] = []
var sfx: Sfx
var ads: Ads

var score := 0
var hiscore := 0
var sound_on := true
var tutorial_seen := false
var busy := false
var over := false

# the Chaos boss fight, once per game after the first 2048
var boss_active := false
var boss_done := false

# love potion: lift a tile off the board and drop it back on any empty cell
var potions := 0
var held_level := -1
var picking := false
var offering := false # first tap on an empty heart offers a rewarded ad
var potion_ads_used := 0
var continued := false # the rewarded "continue" is offered once per game

var _screen: Control
var _shaker: Control
var _effects: Control
var _stars: Stars
var _score_box: Box
var _best_box: Box
var _score_label: PixelLabel
var _hiscore_label: PixelLabel
var _boss_panel: Control
var _chaos_title: PixelLabel
var _hp_bar: HpBar
var _hp_label: PixelLabel
var _potion_button: PixelButton
var _held_slot: HeldSlot
var _new_button: PixelButton
var _sound_button: PixelButton
var _hint: PixelLabel
var _game_over: Control
var _game_over_tween: Tween
var _game_over_title: PixelLabel
var _try_again: PixelButton
var _continue_button: PixelButton
var _game_over_panel: Box
var _game_over_box: Control
var _final_score: PixelLabel
var _card: Control
var _card_box: Control
var _card_title: PixelLabel
var _card_lines: Array[PixelLabel] = []
var _card_button: PixelButton
var _tutorial: Tutorial
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
	_apply_texts()
	ads.layout_changed.connect(_layout)
	get_viewport().size_changed.connect(_layout)
	_layout()
	if not _load_game():
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
	_card.visible = false

	for god in gods:
		god.reset()
	chaos.reset()
	boss_active = false
	boss_done = false
	_show_boss(false)

	board.clear()
	board.spawn_tile()
	board.spawn_tile()
	_refresh_ui()
	_save_game()


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

	# in the boss fight every merge hits Chaos for the merged value
	if boss_active and merged:
		var damage := 0
		for level in board.merge_levels:
			damage += Tile.value_of(level)
		chaos.take_damage(chaos.apply_curse(damage))
		_update_hp()

	busy = true
	await get_tree().create_timer(Board.MOVE_TIME + 0.02).timeout

	board.spawn_tile()
	if boss_active:
		if chaos.hp <= 0:
			await _defeat_boss()
		else:
			chaos.tick()
			await chaos.after_move()
	else:
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
	await _check_boss()
	await _check_stuck()
	busy = false
	_save_game()


func _check_stuck() -> void:
	if board.can_move():
		return
	# the gods are gone while Chaos rules: no rescue then
	var rescued := false
	if not boss_active:
		rescued = await zeus.try_rescue()
	if not rescued or not board.can_move():
		_show_game_over()


# --- Chaos boss fight ---------------------------------------------------------

func _check_boss() -> void:
	if boss_active or boss_done or not board.tiles().any(func(t: Tile) -> bool: return t.level >= BOSS_LEVEL):
		return
	await _start_boss()


func _start_boss() -> void:
	boss_active = true
	chaos.reset()
	ares.rage_left = 0
	ares._update_status()
	picking = false
	offering = false

	# the gods vanish in a burst of their own colors
	sfx.play("thunder")
	sfx.buzz(150)
	chaos.strobe(Chaos.VOID, [0.8, 0.0, 0.6, 0.0, 0.4, 0.0])
	Fx.shake(_shaker, 4, 0.6)
	for god in gods:
		Fx.sparks(_effects, _effects.get_global_transform().affine_inverse() * god.get_global_rect().get_center(), god.accent, 14, 26.0)
	_show_boss(true)
	chaos.banner(I18n.t("banner_chaos"), Chaos.PURPLE)
	_refresh_ui()

	await get_tree().create_timer(0.8).timeout
	await _show_card("intro", Palette.GOLD)
	_save_game()


func _defeat_boss() -> void:
	await chaos.explode()
	boss_active = false
	boss_done = true
	_show_boss(false)
	for god in gods:
		Fx.sparks(_effects, _effects.get_global_transform().affine_inverse() * god.get_global_rect().get_center(), Palette.GOLD, 14, 26.0)
	_on_score_gained(BOSS_BONUS)
	_refresh_ui()
	await _show_card("victory", Palette.GOLD)


# Swaps the gods' row for Chaos's portrait and health bar, with his music.
func _show_boss(on: bool) -> void:
	for god in gods:
		god.visible = not on
	_boss_panel.visible = on
	_stars.chaos = on
	_stars.queue_redraw()
	if on:
		_update_hp()
		sfx.play_music("boss")
	else:
		sfx.stop_music()


func _update_hp() -> void:
	_hp_bar.ratio = float(chaos.hp) / chaos.max_hp
	_hp_bar.queue_redraw()
	_hp_label.text = I18n.t("hp") % [chaos.hp, chaos.max_hp]


# Full-screen story card ("intro" / "victory"); returns when dismissed.
func _show_card(kind: String, color: Color) -> void:
	_card_title.text = I18n.t(kind + "_title")
	_card_title.color = color
	for i in _card_lines.size():
		_card_lines[i].text = I18n.t("%s_%d" % [kind, i + 1])
	_card_button.text = I18n.t("fight" if kind == "intro" else "continue")
	_card.visible = true
	await _card_button.pressed
	sfx.play("click")
	_card.visible = false


func _steal_potion() -> bool:
	if potions <= 0:
		return false
	potions -= 1
	_refresh_ui()
	return true


# --- taps and input -----------------------------------------------------------

func _on_tap(at: Vector2) -> void:
	if over or _card.visible:
		return

	# tapping a god (or Chaos) explains what it does
	var pages := {zeus: Tutorial.PAGE_ZEUS, eros: Tutorial.PAGE_EROS, ares: Tutorial.PAGE_ARES}
	for god in gods:
		if god.is_visible_in_tree() and god.get_global_rect().has_point(at):
			sfx.play("click")
			_tutorial.open(pages[god], true)
			return
	if boss_active and chaos.get_global_rect().has_point(at):
		sfx.play("click")
		_tutorial.open_chaos()
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
	_save_game()


func _drop(cell: Vector2i) -> void:
	board.place_tile(cell, held_level)
	held_level = -1
	sfx.play("drop")
	_refresh_ui()

	busy = true
	await _check_boss()
	await _check_stuck()
	busy = false
	_save_game()


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
			_save_game()
	elif _can_offer_potion_ad():
		offering = true
	_refresh_ui()


func _can_offer_potion_ad() -> bool:
	return potion_ads_used < Ads.REWARDED_POTIONS_PER_GAME and ads.rewarded_ready()


func _input(event: InputEvent) -> void:
	if _tutorial.visible or ads.is_showing() or _card.visible:
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


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			_on_back()
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_WM_CLOSE_REQUEST:
			if board != null:
				_save_game()


# Android back button: closes the topmost thing, and leaves the game last.
func _on_back() -> void:
	if ads.is_showing():
		return
	if _tutorial.credits_open():
		_tutorial._close_credits()
	elif _tutorial.visible:
		_tutorial.close()
	elif _card.visible:
		_card_button.pressed.emit()
	elif picking or offering:
		picking = false
		offering = false
		_refresh_ui()
	else:
		_save_game()
		get_tree().quit()


func _on_score_gained(points: int) -> void:
	points = ares.apply_rage(points)
	if boss_active:
		points = chaos.apply_curse(points)
	score += points
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

	_score_box.hot = ares.is_raging() or (boss_active and chaos.is_cursed())
	_score_box.queue_redraw()

	if offering:
		_hint.text = I18n.t("hint_offer")
		_hint.color = Eros.PINK
	elif picking:
		_hint.text = I18n.t("hint_pick")
		_hint.color = Eros.PINK
	elif held_level >= 0:
		_hint.text = I18n.t("hint_drop")
		_hint.color = Eros.PINK
	elif boss_active and chaos.is_cursed():
		_hint.text = I18n.t("hint_curse") % str(chaos.curse_multiplier)
		_hint.color = Chaos.PURPLE
	elif boss_active:
		_hint.text = I18n.t("hint_boss")
		_hint.color = Chaos.PURPLE
	elif ares.is_raging():
		_hint.text = I18n.t("hint_rage") % str(ares.score_multiplier)
		_hint.color = Ares.RED
	else:
		_hint.text = I18n.t("hint_gods") if score == 0 else I18n.t("hint_swipe")
		_hint.color = Palette.DIM


# Sets every fixed text; called at start and when the language changes.
func _apply_texts() -> void:
	_score_box.caption.text = I18n.t("score")
	_best_box.caption.text = I18n.t("best")
	_new_button.text = I18n.t("new_game")
	_game_over_title.text = I18n.t("game_over")
	_final_score.text = I18n.t("score_n") % score
	_try_again.text = I18n.t("try_again")
	_continue_button.text = I18n.t("watch_continue")
	chaos.god_name = I18n.t("chaos")
	chaos.queue_redraw()
	_chaos_title.text = I18n.t("chaos")
	_update_hp()
	_refresh_ui()


func _on_language_changed() -> void:
	_apply_texts()
	_save()


func _show_game_over() -> void:
	over = true
	sfx.stop_music()
	sfx.play("over")
	sfx.buzz(60)
	_final_score.text = I18n.t("score_n") % score
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


# Rewarded continue: Zeus frees the board once per game (even mid boss fight,
# when he slips back for a moment).
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
		if boss_active:
			sfx.play_music("boss")
		await zeus.revive()
		_refresh_ui()
		if not board.can_move():
			_show_game_over()
	busy = false
	_save_game()


func _toggle_sound() -> void:
	sound_on = not sound_on
	sfx.enabled = sound_on
	_sound_button.icon = SOUND_ON_ICON if sound_on else SOUND_OFF_ICON
	_sound_button.queue_redraw()
	if sound_on and boss_active:
		sfx.play_music("boss")
	elif not sound_on:
		sfx.stop_music()
	sfx.play("click")
	_save()


# --- saving -----------------------------------------------------------------

func _load_save() -> void:
	I18n.lang = I18n.detect()
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	hiscore = config.get_value("game", "hiscore", 0)
	sound_on = config.get_value("settings", "sound", true)
	tutorial_seen = config.get_value("settings", "tutorial_seen", false)
	I18n.lang = config.get_value("settings", "language", I18n.lang)


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("game", "hiscore", hiscore)
	config.set_value("settings", "sound", sound_on)
	config.set_value("settings", "tutorial_seen", tutorial_seen)
	config.set_value("settings", "language", I18n.lang)
	config.save(SAVE_PATH)


# The game in progress. A finished game is not kept: the next launch starts fresh.
func _save_game() -> void:
	if over:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(GAME_PATH))
		return
	var levels := []
	for y in Board.SIZE:
		for x in Board.SIZE:
			var tile := board.tile_at(Vector2i(x, y))
			levels.append(tile.level if tile != null else -1)

	var config := ConfigFile.new()
	config.set_value("game", "levels", levels)
	config.set_value("game", "score", score)
	config.set_value("game", "potions", potions)
	config.set_value("game", "held_level", held_level)
	config.set_value("game", "potion_ads_used", potion_ads_used)
	config.set_value("game", "continued", continued)
	config.set_value("gods", "rescues_used", zeus._rescues_used)
	config.set_value("gods", "rage_left", ares.rage_left)
	config.set_value("boss", "active", boss_active)
	config.set_value("boss", "done", boss_done)
	config.set_value("boss", "hp", chaos.hp)
	config.set_value("boss", "curse_left", chaos.curse_left)
	config.save(GAME_PATH)


func _load_game() -> bool:
	var config := ConfigFile.new()
	if config.load(GAME_PATH) != OK:
		return false
	var levels: Array = config.get_value("game", "levels", [])
	if levels.size() != Board.SIZE * Board.SIZE or levels.all(func(l: int) -> bool: return l < 0):
		return false

	new_game()
	board.clear()
	for i in levels.size():
		if levels[i] >= 0:
			board.place_tile(Vector2i(i % Board.SIZE, i / Board.SIZE), mini(levels[i], Board.MAX_LEVEL))
	score = config.get_value("game", "score", 0)
	potions = config.get_value("game", "potions", 0)
	held_level = config.get_value("game", "held_level", -1)
	potion_ads_used = config.get_value("game", "potion_ads_used", 0)
	continued = config.get_value("game", "continued", false)
	zeus._rescues_used = config.get_value("gods", "rescues_used", 0)
	ares.rage_left = config.get_value("gods", "rage_left", 0)
	ares._update_status()
	boss_active = config.get_value("boss", "active", false)
	boss_done = config.get_value("boss", "done", false)
	chaos.hp = config.get_value("boss", "hp", chaos.max_hp)
	chaos.curse_left = config.get_value("boss", "curse_left", 0)
	_show_boss(boss_active)
	_update_score_labels()
	_refresh_ui()
	return true


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
	for box in [_screen, _game_over_box, _card_box, _tutorial.box]:
		box.scale = Vector2(fit, fit)
		box.position = origin


func _build_ui() -> void:
	_stars = Stars.new()
	add_child(_stars)

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
	_score_box = _make_score_box(Vector2(80, 6))
	_score_label = _score_box.value
	_best_box = _make_score_box(Vector2(128, 6))
	_hiscore_label = _best_box.value

	# the gods
	zeus = Zeus.new()
	eros = Eros.new()
	ares = Ares.new()
	gods = [zeus, eros, ares]
	for i in gods.size():
		_place(_shaker, gods[i], Vector2(6 + i * 61, 42))

	# Chaos takes the gods' row during the boss fight
	_boss_panel = Control.new()
	_boss_panel.size = SCREEN
	_boss_panel.visible = false
	_shaker.add_child(_boss_panel)
	chaos = Chaos.new()
	chaos.steal_potion = _steal_potion
	_place(_boss_panel, chaos, Vector2(6, 42))
	_chaos_title = PixelLabel.new("", 2, Chaos.PURPLE, Palette.INK)
	_place(_boss_panel, _chaos_title, Vector2(58, 46))
	_hp_bar = HpBar.new()
	_hp_bar.size = Vector2(116, 10)
	_place(_boss_panel, _hp_bar, Vector2(58, 66))
	_hp_label = PixelLabel.new("", 1, Palette.LIGHT, Palette.INK)
	_place(_boss_panel, _hp_label, Vector2(58, 80))

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

	_new_button = PixelButton.new("", 74, 20)
	_new_button.pressed.connect(func() -> void:
		sfx.play("click")
		new_game()
	)
	_place(_shaker, _new_button, Vector2(74, 278))

	_sound_button = PixelButton.new("", 24, 20, Palette.CELL.lightened(0.15))
	_sound_button.icon = SOUND_ON_ICON if sound_on else SOUND_OFF_ICON
	_sound_button.icon_color = Palette.LIGHT
	_sound_button.pressed.connect(_toggle_sound)
	_place(_shaker, _sound_button, Vector2(150, 278))

	_hint = _centered("", 1, Palette.DIM, SCREEN.x)
	_place(_shaker, _hint, Vector2(0, 306))

	# effects layer above the board (lightning, hearts, sparks, texts)
	_effects = Control.new()
	_effects.size = SCREEN
	_shaker.add_child(_effects)

	# full-screen strobe for big moments
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(flash)

	for god in gods + [chaos]:
		god.board = board
		god.effects = _effects
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
	_game_over_title = _centered("", 2, Palette.GOLD, SCREEN.x, Palette.INK)
	_place(_game_over_box, _game_over_title, Vector2(0, 128))
	_final_score = _centered("", 1, Palette.LIGHT, SCREEN.x)
	_place(_game_over_box, _final_score, Vector2(0, 152))

	_try_again = PixelButton.new("", 74, 18)
	_try_again.pressed.connect(_on_try_again)
	_place(_game_over_box, _try_again, Vector2(53, 168))

	_continue_button = PixelButton.new("", 132, 18, Palette.GOLD_DARK)
	_continue_button.pressed.connect(_on_continue)
	_place(_game_over_box, _continue_button, Vector2(24, 194))

	# story card for the boss fight (intro / victory)
	_card = Dim.new()
	_card.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_card.visible = false
	add_child(_card)

	_card_box = Control.new()
	_card_box.size = SCREEN
	_card.add_child(_card_box)

	var card_panel := Box.new()
	card_panel.size = Vector2(148, 120)
	_place(_card_box, card_panel, Vector2(16, 84))
	_card_title = _centered("", 3, Palette.GOLD, SCREEN.x, Palette.INK)
	_place(_card_box, _card_title, Vector2(0, 94))
	for i in 4:
		var line := _centered("", 1, Palette.LIGHT, SCREEN.x)
		_place(_card_box, line, Vector2(0, 124 + i * 10))
		_card_lines.append(line)
	_card_button = PixelButton.new("", 74, 18)
	_place(_card_box, _card_button, Vector2(53, 174))

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
	_tutorial.language_changed.connect(_on_language_changed)
	add_child(_tutorial)


func _make_score_box(at: Vector2) -> Box:
	var box := Box.new()
	box.size = Vector2(46, 24)
	_place(_shaker, box, at)

	box.caption = _centered("", 1, Palette.DIM, box.size.x)
	_place(box, box.caption, Vector2(0, 3))
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


# Panel background; turns red while Ares rages or Chaos curses (score box).
class Box extends Control:
	var caption: PixelLabel
	var value: PixelLabel
	var hot := false

	func _draw() -> void:
		var color := Ares.RED.darkened(0.35) if hot else Palette.BOARD
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), color)
		draw_rect(Rect2(1, 1, size.x - 2, 1), color.lightened(0.15))


# Chaos's health: a segmented retro bar.
class HpBar extends Control:
	var ratio := 1.0

	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.INK)
		draw_rect(Rect2(1, 1, size.x - 2, size.y - 2), Palette.CELL)
		var fill := floorf((size.x - 2) * clampf(ratio, 0.0, 1.0))
		var color := Color("ff3355") if ratio > 0.25 else Color("ff8a3d")
		draw_rect(Rect2(1, 1, fill, size.y - 2), color)
		draw_rect(Rect2(1, 1, fill, 1), color.lightened(0.35))
		for x in range(5, int(size.x) - 1, 5):
			draw_rect(Rect2(x, 2, 1, size.y - 4), Color(Palette.INK, 0.35))


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


# Darkened scanline backdrop for the game over screen and story cards.
class Dim extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color(Palette.INK, 0.6))
		for y in range(0, int(size.y), 2):
			draw_rect(Rect2(0, y, size.x, 1), Color(Palette.INK, 0.35))


# Twinkling night sky behind the game; turns blood red while Chaos rules.
class Stars extends Control:
	var chaos := false
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
		if chaos:
			draw_rect(Rect2(Vector2.ZERO, size), Color(Chaos.VOID, 0.35))
		var bright := Color("ff3355") if chaos else Palette.LIGHT
		var dim := Color("6a2fa0") if chaos else Palette.DIM.darkened(0.3)
		for star in _stars:
			draw_rect(Rect2(star.x, star.y, 1, 1), bright if star.z > 0.8 else dim)
