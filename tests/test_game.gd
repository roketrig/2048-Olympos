extends SceneTree

# Gameplay tests. Run from the project folder:
#   Godot --path . -s tests/test_game.gd            (prints PASS / FAIL lines)
#   Godot --path . -s tests/test_game.gd -- out.png (also saves screenshots)
# Your own save files are set aside during the run and put back afterwards.

const USER_FILES := ["user://save.cfg", "user://game.cfg"]

var shot_path := ""
var board: Board
var failures := 0


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	shot_path = args[0] if args.size() > 0 else ""
	for path in USER_FILES:
		var real := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(real):
			DirAccess.rename_absolute(real, real + ".testbak")
	I18n.lang = "en"
	_run.call_deferred()


func _finish() -> void:
	for path in USER_FILES:
		var real := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(real)
		if FileAccess.file_exists(real + ".testbak"):
			DirAccess.rename_absolute(real + ".testbak", real)
	print("DONE, %d failed" % failures)
	quit(1 if failures > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	if not cond:
		failures += 1
	print(("PASS " if cond else "FAIL ") + msg)


func _fill(levels: Array) -> void:
	board.clear()
	for y in 4:
		for x in 4:
			if levels[y][x] >= 0:
				_place(Vector2i(x, y), levels[y][x])


func _sum() -> int:
	var total := 0
	for t in board.tiles():
		total += t.value()
	return total


func _run() -> void:
	var main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	board = main.board
	var zeus: Zeus = main.zeus
	var eros: Eros = main.eros
	var ares: Ares = main.ares
	main._load_save() # language and settings from the (now empty) save
	I18n.lang = "en"
	main._apply_texts()
	main._tutorial._show_page()

	_check(board.tiles().size() == 2, "new game spawns 2 tiles")
	_check(main._tutorial.visible, "tutorial shows on first launch")
	if shot_path != "":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_tut0.png"))
		main._tutorial._turn(1)
		main._tutorial._turn(1)
		main._tutorial._turn(1)
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_tut3.png"))
	for i in 5:
		main._tutorial._turn(1)
	_check(not main._tutorial.visible and main.tutorial_seen, "tutorial closes after last page and is remembered")
	main._on_tap(ares.get_global_rect().get_center())
	_check(main._tutorial.visible and main._tutorial._page == Tutorial.PAGE_ARES and main._tutorial._single, "tapping Ares opens his card")
	if shot_path != "":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_ares_card.png"))
	main._tutorial._turn(1)
	_check(not main._tutorial.visible, "OK closes the card")

	# merge rules
	_fill([[0, 0, 1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.score = 0
	_check(board.move(Vector2i.LEFT), "move left reported change")
	await create_timer(0.3).timeout
	_check(board.tile_at(Vector2i(0, 0)).value() == 4 and board.tile_at(Vector2i(1, 0)).value() == 4 and board.tile_at(Vector2i(2, 0)) == null, "2,2,4 -> 4,4 (no double merge)")
	_check(main.score == 4, "score += 4 (got %d)" % main.score)

	# Zeus rescue
	_fill([[0, 1, 0, 1], [1, 0, 1, 0], [0, 1, 0, 1], [1, 0, 1, 2]])
	_check(not board.can_move(), "stuck board detected")
	var rescued: bool = await zeus.try_rescue()
	_check(rescued and board.can_move(), "Zeus rescue opens a merge")
	_check(not await zeus.try_rescue(), "only one rescue per game")

	# Zeus chain lightning: each chained tile doubles exactly once
	_fill([[0, 1, 2, 3], [-1, -1, -1, -1], [4, -1, -1, -1], [-1, -1, -1, 5]])
	zeus.strike_chance = 1.0
	zeus.chain_chance = 1.0
	zeus.cooldown_moves = 0
	zeus.chain_length = Vector2i(4, 4)
	zeus.big_tile_falloff = 1.0 # every tile may join the chain
	var levels_before := {}
	for t in board.tiles():
		levels_before[t] = t.level
	zeus.tick()
	_check(await zeus.after_move(), "Zeus chain strike fired")
	var raised := 0
	var bad := 0
	for t in board.tiles():
		var diff: int = t.level - levels_before[t]
		if diff == 1: raised += 1
		elif diff != 0: bad += 1
	_check(raised == 4 and bad == 0, "chain doubled exactly 4 tiles once each (raised %d, bad %d)" % [raised, bad])
	zeus.big_tile_falloff = 0.55

	# Zeus rarely strikes big tiles
	_fill([[0, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, 9]])
	var big_hits := 0
	for i in 500:
		if zeus._pick_target(1, false).level == 9:
			big_hits += 1
	_check(big_hits < 15, "Zeus picks a 1024 over a 2 rarely (%d / 500)" % big_hits)

	# 8192 is the last tile: it never merges and Zeus never strikes it
	_fill([[12, 12, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	board.move(Vector2i.LEFT)
	_check(board.tiles().size() == 2 and board.tiles().all(func(t: Tile) -> bool: return t.level == 12), "two 8192s don't merge")
	_check(zeus._pick_target(1, false) == null and zeus._pick_chain().is_empty(), "Zeus never strikes a 8192")
	_fill([[12, 0, 12, 0], [0, 12, 0, 12], [12, 0, 12, 0], [0, 12, 0, 12]])
	_check(not board.can_move(), "a board of 8192s and 2s with no pairs is stuck")
	_fill([[12, 12, 3, 5], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	await main.chaos._halve()
	_check(board.tile_at(Vector2i(0, 0)).level == 12 and board.tile_at(Vector2i(1, 0)).level == 12 and board.tile_at(Vector2i(2, 0)).level == 2, "Chaos spares 8192s")

	# Eros merges every equal pair at once
	main.score = 0
	_fill([[0, 0, 3, 3], [-1, -1, -1, -1], [5, -1, -1, -1], [5, -1, -1, 7]])
	eros.merge_chance = 1.0
	eros.cooldown_moves = 0
	eros.tick()
	_check(await eros.after_move(), "Eros acted")
	var values := board.tiles().map(func(t: Tile) -> int: return t.value())
	values.sort()
	_check(values == [4, 32, 128, 256], "Eros merged 3 pairs -> %s" % [values])
	_check(main.score == 4 + 32 + 128, "Eros merges scored (got %d)" % main.score)

	# Ares clears 2s and boosts score
	_fill([[0, 0, 3, -1], [0, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, 5]])
	ares.scream_chance = 1.0
	ares.cooldown_moves = 0
	ares.tick()
	_check(await ares.after_move(), "Ares roared")
	await create_timer(0.3).timeout
	_check(board.tiles().size() == 2 and board.tiles().all(func(t: Tile) -> bool: return t.level != 0), "all 2s cleared")
	_check(ares.is_raging() and ares.rage_left == ares.rage_moves, "rage active for %d moves" % ares.rage_left)
	main.score = 0
	main._on_score_gained(100)
	_check(main.score == 150, "score x1.5 during rage (got %d)" % main.score)
	for i in ares.rage_moves:
		ares.tick()
	main.score = 0
	main._on_score_gained(100)
	_check(not ares.is_raging() and main.score == 100, "rage wears off")

	# --- ads ---
	var ads: Ads = main.ads
	var vp: Vector2 = main.get_viewport_rect().size
	print("viewport ", vp, " banner ", ads.banner_height(), " top banner ", ads.top_banner, " scale ", main._screen.scale)
	var screen_rect: Rect2 = main._screen.get_global_rect()
	_check(screen_rect.position.y >= ads.top_inset() - 0.5 and screen_rect.end.y <= vp.y - ads.bottom_inset() + 0.5, "game stays clear of banners (%s)" % screen_rect)
	if shot_path != "":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_ads_short.png"))

	# interstitial caps
	ads._game_overs_since_ad = 0
	ads._last_interstitial = -1.0e9
	ads.count_game_over()
	_check(not ads.interstitial_due(), "no interstitial after 1st game over")
	ads.count_game_over()
	var grace_ok := Time.get_ticks_msec() / 1000.0 >= Ads.SESSION_GRACE_SECONDS
	_check(ads.interstitial_due() == grace_ok, "interstitial due on 2nd game over only after grace (%s)" % grace_ok)
	ads._last_interstitial = Time.get_ticks_msec() / 1000.0
	_check(not ads.interstitial_due(), "not again within 2 minutes")

	# rewarded continue on a stuck board
	_fill([[0, 1, 0, 1], [1, 0, 1, 0], [0, 1, 0, 1], [1, 0, 1, 0]])
	zeus._rescues_used = 99
	main._show_game_over()
	_check(main._continue_button.visible, "continue offered at game over")
	main._on_continue()
	await create_timer(0.1).timeout
	_check(ads.is_showing(), "rewarded test ad showing")
	if shot_path != "":
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_ad_full.png"))
	await create_timer(3.2).timeout
	_press_close(ads)
	await create_timer(1.5).timeout
	_check(not main.over and board.can_move(), "rewarded continue revives the game")
	main._show_game_over()
	_check(not main._continue_button.visible, "continue only once per game")
	if shot_path != "":
		await create_timer(1.3).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_over_ads.png"))
	main.new_game()

	# rewarded potion needs two taps
	main._on_potion_pressed()
	_check(main.offering and not ads.is_showing(), "first tap only offers the ad")
	main._on_potion_pressed()
	await create_timer(3.2).timeout
	_press_close(ads)
	await create_timer(0.2).timeout
	_check(main.potions == 1 and main.potion_ads_used == 1, "watching the ad gives a potion")

	# --- language & font ---
	var missing := {}
	var too_wide := []
	for language in I18n.LANGUAGES:
		var texts: Array = I18n.STRINGS[language].values()
		for page in I18n.PAGES[language]:
			texts.append(page["title"])
			texts.append_array(page["lines"])
			for line in page["lines"]:
				if PixelFont.measure(line, 1).x > 160:
					too_wide.append(line)
			if PixelFont.measure(page["title"], 2).x > 160:
				too_wide.append(page["title"])
		for boss_key in I18n.BOSS_PAGES:
			for page in I18n.BOSS_PAGES[boss_key][language]:
				texts.append(page["title"])
				texts.append_array(page["lines"])
				for line in page["lines"]:
					if PixelFont.measure(line, 1).x > 160:
						too_wide.append(line)
				if PixelFont.measure(page["title"], 2).x > 160:
					too_wide.append(page["title"])
		for key in I18n.STRINGS[language]:
			var card_text: String = I18n.STRINGS[language][key]
			if "%d" in card_text:
				card_text = card_text.replace("%d", "999")
			if key.ends_with("_title") and PixelFont.measure(card_text, 3).x > 144:
				too_wide.append(card_text)
			if (key.contains("intro_") or key.contains("victory_") or key.begins_with("mood_") or key.begins_with("trophy")) and not key.ends_with("_title") and PixelFont.measure(card_text, 1).x > 144:
				too_wide.append(card_text)
		for key in I18n.STRINGS[language]:
			var text: String = I18n.STRINGS[language][key]
			if key.begins_with("hint") and PixelFont.measure(text % "1.5" if "%" in text else text, 1).x > 180:
				too_wide.append(text)
			if key.begins_with("banner") and PixelFont.measure(text, 2).x > 180:
				too_wide.append(text)
		for text in texts:
			for ch in text:
				if ch != " " and ch != "%" and not PixelFont.GLYPHS.has(ch) and not PixelFont.GLYPHS.has(ch.to_upper()):
					missing[ch] = true
	_check(missing.is_empty(), "font has every character used (missing: %s)" % [missing.keys()])
	_check(too_wide.is_empty(), "all texts fit their space (too wide: %s)" % [too_wide])

	I18n.lang = "tr"
	main._apply_texts()
	_check(main._new_button.text == "YENİ OYUN" and main._score_box.caption.text == "SKOR", "Turkish UI texts")
	for button in [main._new_button, main._try_again, main._continue_button]:
		_check(PixelFont.measure(button.text, 1).x <= button.size.x - 4, "Turkish button text fits: %s" % button.text)
	for key in ["fight", "continue"]:
		_check(PixelFont.measure(I18n.t(key), 1).x <= main._card_button.size.x - 4, "Turkish card button fits: %s" % I18n.t(key))
	if shot_path != "":
		main._tutorial.open()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_tr_tut.png"))
		main._tutorial._show_credits()
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_tr_credits.png"))
		main._tutorial.close()
	I18n.lang = "en"
	main._apply_texts()

	# credits
	main._tutorial.open()
	main._tutorial._show_credits()
	var license: String = Tutorial._license_text()
	_check(main._tutorial.credits_open() and "Godot" in license and "MIT" in license and license.length() > 2000, "credits show Godot license (%d chars)" % license.length())

	# Android back button closes the topmost layer
	main._on_back()
	_check(not main._tutorial.credits_open() and main._tutorial.visible, "back closes credits first")
	main._on_back()
	_check(not main._tutorial.visible, "back then closes the help screen")

	# save & resume
	_fill([[3, -1, -1, 1], [-1, 5, -1, -1], [-1, -1, -1, -1], [0, -1, -1, 10]])
	main.score = 1234
	main.potions = 2
	main.held_level = 4
	ares.rage_left = 3
	main._save_game()
	board.clear() # simulate a fresh launch: the board is empty until the save loads
	main.score = 0
	main.potions = 0
	main.held_level = -1
	ares.rage_left = 0
	_check(main._load_game(), "saved game loads")
	var restored: Array = []
	for t in board.tiles():
		restored.append([t.grid_pos, t.level])
	restored.sort()
	var expected := [[Vector2i(0, 0), 3], [Vector2i(0, 3), 0], [Vector2i(1, 1), 5], [Vector2i(3, 0), 1], [Vector2i(3, 3), 10]]
	expected.sort()
	_check(restored == expected and main.score == 1234 and main.potions == 2 and main.held_level == 4 and ares.rage_left == 3, "board, score, potions, hand and rage restored")
	main.new_game()

	# --- Chaos boss fight ---
	var chaos: Chaos = main.chaos
	for god in main.gods:
		god._moves_since_action = -1000 # keep the gods out of these moves
	_fill([[9, 9, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.try_move(Vector2i.LEFT)
	await create_timer(1.4).timeout
	_check(main.boss_active and main.herald_done, "first 2048 wakes Chaos (the herald is skipped)")
	_check(main._tutorial.visible and main._tutorial._sequence == I18n.boss_pages("chaos") and not main._card.visible, "first meeting opens the Chaos guide")
	_check(not main._tutorial._credits_button.visible, "the boss guide has no credits row")
	if shot_path != "":
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_chaos_guide.png"))
	for i in I18n.boss_pages("chaos").size():
		main._tutorial._turn(1)
	await create_timer(0.1).timeout
	_check(not main._tutorial.visible and main._card.visible, "after the guide comes the intro card")
	_check(Chaos.MOODS.has(chaos.mood) and main._card_lines[3].text == I18n.t("mood_" + chaos.mood), "the card names his mood (%s)" % chaos.mood)
	_check(main.gods.all(func(g: God) -> bool: return not g.visible) and chaos.is_visible_in_tree() and not main.herald.visible, "gods vanish, Chaos appears")
	_check(main.sfx.music_playing(), "boss music plays")
	var saved_mood := chaos.mood
	chaos.mood = "flood"
	_check(is_equal_approx(chaos.chance("flood", 0.04), 0.072) and is_equal_approx(chaos.chance("halve", 0.06), 0.036), "mood boosts one power and dampens the others")
	chaos.mood = saved_mood
	if shot_path != "":
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_boss_intro.png"))
	main._card_button.pressed.emit()
	await create_timer(0.3).timeout
	_check(not main._card.visible and not main.busy, "FIGHT closes the card and play resumes")

	chaos._moves_since_action = -1000 # no Chaos moves while measuring damage
	_fill([[0, 0, -1, -1], [1, 1, -1, -1], [10, -1, -1, -1], [-1, -1, -1, -1]])
	var hp_before := chaos.hp
	await main.try_move(Vector2i.LEFT)
	_check(chaos.hp == hp_before - 12, "merges hurt Chaos for their value (%d -> %d)" % [hp_before, chaos.hp])
	chaos.curse_left = 3
	_fill([[0, 0, -1, -1], [-1, -1, -1, -1], [10, -1, -1, -1], [-1, -1, -1, -1]])
	hp_before = chaos.hp
	await main.try_move(Vector2i.LEFT)
	_check(chaos.hp == hp_before - 2, "curse halves damage (%d -> %d)" % [hp_before, chaos.hp])
	chaos.curse_left = 0
	if shot_path != "":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_boss.png"))

	_fill([[3, 3, 5, 9], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	var levels_sum := func() -> int:
		var total := 0
		for t in board.tiles():
			total += t.level
		return total
	var before_halve: int = levels_sum.call()
	_check(await chaos._halve(), "Chaos halves a tile")
	_check(levels_sum.call() < before_halve and board.tile_at(Vector2i(3, 0)).level == 9, "a tile shrank, the biggest was spared")

	_fill([[3, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.potions = 1
	_check(await chaos._split(), "Chaos splits")
	var split_levels := board.tiles().map(func(t: Tile) -> int: return t.level)
	_check(split_levels == [2, 2] and main.potions == 0, "16 split into 8 + 8 and a potion was stolen (%s)" % [split_levels])

	_fill([[3, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, 5]])
	_check(await chaos._flood(), "Chaos floods")
	_check(board.tiles().size() == 5 and chaos.curse_left == chaos.curse_moves, "three 2s poured in and the curse is on")
	chaos.curse_left = 0

	main._on_tap(chaos.get_global_rect().get_center())
	_check(main._tutorial.visible and main._tutorial._sequence == I18n.boss_pages("chaos"), "tapping Chaos opens his guide")
	main._tutorial.close()

	main._save_game()
	var saved_hp := chaos.hp
	var saved_moves: int = main.boss_moves
	main.boss_active = false
	chaos.hp = 1
	main._load_game()
	_check(main.boss_active and chaos.hp == saved_hp and not main.zeus.visible, "boss fight resumes after relaunch")
	_check(main.boss == chaos and chaos.mood == saved_mood and main.boss_moves == saved_moves and saved_moves > 0, "mood and move count resume too")

	chaos._moves_since_action = -1000
	chaos.hp = 5
	var score_before: int = main.score
	_fill([[1, 1, -1, -1], [-1, -1, -1, -1], [10, -1, -1, -1], [-1, -1, -1, -1]])
	main.try_move(Vector2i.LEFT)
	await create_timer(1.4).timeout
	_check(main._card.visible and main.boss_done and not main.boss_active, "Chaos defeated: victory card")
	_check(main.gods.all(func(g: God) -> bool: return g.visible) and not main.sfx.music_playing(), "gods return, music stops")
	_check(main.score >= score_before + 2048, "victory bonus +2048")
	_check(main.chaos_best == main.boss_moves and main._card_lines[3].text == I18n.t("victory_record") % main.boss_moves, "first win is a record (%s)" % main._card_lines[3].text)
	_check(main.trophies.has("chaos"), "trophy for beating Chaos")
	if shot_path != "":
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_victory.png"))
	main._on_back()
	await create_timer(0.3).timeout
	_check(not main._card.visible, "back closes the victory card")

	_fill([[9, 9, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	await main.try_move(Vector2i.LEFT)
	_check(not main.boss_active and not main._card.visible, "Chaos comes only once per game")
	main.new_game()

	# --- the herald at 512 ---
	var herald: Herald = main.herald
	for god in main.gods:
		god._moves_since_action = -1000 # new_game reset them
	_fill([[7, 7, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.try_move(Vector2i.LEFT)
	await create_timer(1.4).timeout
	_check(main.boss_active and main.boss == herald and herald.is_visible_in_tree() and not chaos.visible, "first 512 brings the herald")
	_check(main._tutorial.visible and main._tutorial._sequence == I18n.boss_pages("herald"), "first meeting opens the herald guide")
	main._on_back()
	await create_timer(0.1).timeout
	_check(main._card.visible and main._card_title.text == "512!", "back closes the guide, then the herald card")
	if shot_path != "":
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_herald_intro.png"))
	main._card_button.pressed.emit()
	await create_timer(0.3).timeout
	_check(herald.hp == herald.max_hp and herald.max_hp < chaos.max_hp and herald.mood == "", "the herald is weaker and has no mood")
	herald._moves_since_action = -1000
	_fill([[1, 1, -1, -1], [-1, -1, -1, -1], [8, -1, -1, -1], [-1, -1, -1, -1]])
	await main.try_move(Vector2i.LEFT)
	_check(herald.hp == herald.max_hp - 8, "merges hurt the herald")
	if shot_path != "":
		await create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_herald.png"))
	herald.hp = 3
	score_before = main.score
	_fill([[1, 1, -1, -1], [-1, -1, -1, -1], [8, -1, -1, -1], [-1, -1, -1, -1]])
	main.try_move(Vector2i.LEFT)
	await create_timer(1.4).timeout
	_check(main._card.visible and main.herald_done and not main.boss_done and not main.boss_active, "herald defeated, Chaos still to come")
	_check(main.score >= score_before + 512 and main.trophies.has("herald"), "herald bonus +512 and trophy")
	main._card_button.pressed.emit()
	await create_timer(0.3).timeout

	_fill([[9, 9, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.try_move(Vector2i.LEFT)
	await create_timer(1.4).timeout
	_check(main.boss == chaos and main._card.visible and not main._tutorial.visible, "the guide shows only the first time")
	main._card_button.pressed.emit()
	await create_timer(0.3).timeout
	main.new_game()

	# --- trophies ---
	_check(main.trophies.has("chain") and main.trophies.has("love") and main.trophies.has("roar"), "god trophies unlocked along the way (%s)" % [main.trophies])
	var page: Dictionary = main._trophy_page()
	_check(page["lines"].size() == 6 and page["title"] == I18n.t("trophies") % [main.trophies.size(), 6], "trophy page lists all six")
	_fill([[11, 11, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1]])
	main.boss_done = true
	main.herald_done = true
	await main.try_move(Vector2i.LEFT)
	_check(main.trophies.has("tile") and main._hint.text == I18n.t("trophy") % I18n.t("trophy_tile"), "reaching 8192 unlocks a trophy with a message")
	main._tutorial.open_custom(main._trophy_page())
	if shot_path != "":
		await create_timer(0.2).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_trophies.png"))
	main._tutorial.close()
	main._save()
	main.trophies.clear()
	main.chaos_best = 0
	main._load_save()
	I18n.lang = "en"
	_check(main.trophies.size() == 6 and main.chaos_best > 0, "trophies and record are saved")
	for god in main.gods:
		god._moves_since_action = 0
	main.new_game()

	# love potion: lift a tile and drop it elsewhere
	_fill([[3, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, -1], [-1, -1, -1, 0]])
	main.potions = 1
	main._on_potion_pressed()
	_check(main.picking, "potion enters pick mode")
	main._on_tap(_cell_center(Vector2i(0, 0)))
	_check(main.held_level == 3 and board.tile_at(Vector2i(0, 0)) == null and main.potions == 0, "tile lifted into hand")
	await create_timer(0.2).timeout
	main._on_tap(_cell_center(Vector2i(2, 2)))
	_check(main.held_level == -1 and board.tile_at(Vector2i(2, 2)) != null and board.tile_at(Vector2i(2, 2)).level == 3, "tile dropped on empty cell")

	if shot_path != "":
		await create_timer(0.5).timeout
		main.new_game()
		_fill([[0, 1, 2, 3], [4, 5, 6, -1], [7, 8, -1, -1], [9, 10, -1, 0]])
		main.potions = 2
		main.held_level = 6
		ares.rage_left = 5
		ares._update_status()
		main._refresh_ui()
		await create_timer(0.3).timeout
		zeus.tick(); zeus.after_move()
		await create_timer(0.22).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_chain.png"))
		await create_timer(1.2).timeout
		_fill([[0, 0, 2, 2], [4, -1, 6, 6], [-1, -1, -1, -1], [9, 9, -1, 0]])
		eros.tick(); eros.after_move()
		await create_timer(0.15).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_eros.png"))
		await create_timer(1.2).timeout
		_fill([[0, 0, 2, 2], [4, 0, 6, 0], [-1, -1, -1, -1], [9, 9, -1, 0]])
		ares.rage_left = 0
		ares.tick(); ares.after_move()
		await create_timer(0.25).timeout
		await RenderingServer.frame_post_draw
		_save(shot_path.replace(".png", "_ares.png"))
		print("shots saved")
	_finish()


func _cell_center(p: Vector2i) -> Vector2:
	return board.get_global_transform() * (board.cell_position(p) + Vector2.ONE * board.cell_size / 2.0)


func _press_close(ads: Ads) -> void:
	for node in ads.find_children("*", "PixelButton", true, false):
		if node.text == "CLOSE":
			node.pressed.emit()


func _place(p: Vector2i, level: int) -> void:
	var tile := Tile.new()
	tile.resize(board.cell_size)
	tile.set_level(level)
	tile.grid_pos = p
	tile.position = board.cell_position(p)
	board.add_child(tile)
	board.cells[p.y][p.x] = tile


func _save(path: String) -> void:
	var img := root.get_texture().get_image()
	img.resize(img.get_width() * 3, img.get_height() * 3, Image.INTERPOLATE_NEAREST)
	img.save_png(path)
