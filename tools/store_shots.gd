extends SceneTree

# Store graphics for Google Play / App Store, drawn by the game itself:
#   - 512x512 icon
#   - 1024x500 feature graphic (EN and TR)
#   - phone screenshots 1080x2160 with a caption on top (EN and TR)
# Run from the project folder:
#   Godot --path . -s tools/store_shots.gd
# Files go to ../build/store. Your own save files are set aside during the run.

const USER_FILES := ["user://save.cfg", "user://game.cfg"]
const WINDOW := Vector2i(360, 720) # 1:2, saved 3x larger
const SAVE_SCALE := 3
const CAPTION_SPACE := 40.0 # game pixels above the game for the caption
const FEATURE := Vector2i(256, 125) # saved 4x larger: 1024x500

const CAPTIONS := {
	"en": {
		"zeus": ["ZEUS DOUBLES", "YOUR TILES!"],
		"eros": ["EROS MERGES", "EVERY PAIR!"],
		"ares": ["ARES BLOWS", "AWAY THE 2S!"],
		"chaos": ["AT 2048 CHAOS", "AWAKENS!"],
		"herald": ["BEAT THE", "HERALD AT 512!"],
		"tagline": "MERGE WITH THE GODS",
	},
	"tr": {
		"zeus": ["ZEUS TAŞLARINI", "İKİYE KATLAR!"],
		"eros": ["EROS ÇİFTLERİ", "BİRLEŞTİRİR!"],
		"ares": ["ARES 2'LERİ", "YOK EDER!"],
		"chaos": ["2048'DE KAOS", "UYANIYOR!"],
		"herald": ["512'DE ELÇİYİ", "YEN!"],
		"tagline": "TANRILARLA BİRLEŞTİR",
	},
}

var out_dir := ""
var main: Control
var board: Board
var caption: Control


func _initialize() -> void:
	out_dir = ProjectSettings.globalize_path("res://").path_join("../build/store").simplify_path()
	for path in USER_FILES:
		var real := ProjectSettings.globalize_path(path)
		if FileAccess.file_exists(real + ".storebak"):
			# an earlier run was cut short: its backup is the real save
			DirAccess.remove_absolute(real)
		elif FileAccess.file_exists(real):
			DirAccess.rename_absolute(real, real + ".storebak")
	DisplayServer.window_set_size(WINDOW)
	# a hidden or minimized window stops drawing and the run would hang
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_ALWAYS_ON_TOP, true)
	_run.call_deferred()


func _finish() -> void:
	for path in USER_FILES:
		var real := ProjectSettings.globalize_path(path)
		DirAccess.remove_absolute(real)
		if FileAccess.file_exists(real + ".storebak"):
			DirAccess.rename_absolute(real + ".storebak", real)
	print("DONE -> ", out_dir)
	quit()


func _run() -> void:
	await process_frame
	await process_frame
	DirAccess.make_dir_recursive_absolute(out_dir)
	_save_icon()

	for lang in ["en", "tr"]:
		I18n.lang = lang
		DirAccess.make_dir_recursive_absolute(out_dir.path_join(lang))
		await _feature_graphic(lang)
		await _screenshots(lang)
	_finish()


# --- icon -------------------------------------------------------------------------

func _save_icon() -> void:
	var icon := Image.load_from_file(ProjectSettings.globalize_path("res://icon.png"))
	icon.resize(512, 512, Image.INTERPOLATE_NEAREST)
	icon.save_png(out_dir.path_join("icon-512.png"))


# --- feature graphic ------------------------------------------------------------------

func _feature_graphic(lang: String) -> void:
	var viewport := SubViewport.new()
	viewport.size = FEATURE
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(viewport)

	var sky := NightSky.new()
	sky.size = Vector2(FEATURE)
	viewport.add_child(sky)

	var title := PixelLabel.new("2048", 5, Palette.GOLD, Palette.GOLD_DARK)
	title.position = Vector2(10, 18)
	viewport.add_child(title)
	var name_label := PixelLabel.new("OLYMPOS", 3, Palette.LIGHT, Palette.INK)
	name_label.position = Vector2(12, 62)
	viewport.add_child(name_label)
	var tagline := PixelLabel.new(CAPTIONS[lang]["tagline"], 1, Palette.GOLD, Palette.INK)
	tagline.position = Vector2(12, 92)
	viewport.add_child(tagline)

	var portraits: Array[God] = [Zeus.new(), Eros.new(), Ares.new(), Chaos.new()]
	for i in portraits.size():
		var god := portraits[i]
		god.god_name = I18n.t("chaos") if god is Chaos else god.god_name
		god.position = Vector2(150 + (i % 2) * 54, 6 + (i / 2) * 60)
		viewport.add_child(god)

	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	image.resize(FEATURE.x * 4, FEATURE.y * 4, Image.INTERPOLATE_NEAREST)
	image.save_png(out_dir.path_join(lang).path_join("feature-1024x500.png"))
	viewport.queue_free()


# --- screenshots ------------------------------------------------------------------

func _screenshots(lang: String) -> void:
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	board = main.board
	main.sfx.enabled = false
	main._tutorial.close()
	I18n.lang = lang
	main._apply_texts()

	# no ad placeholders in store art; the game sits under the caption
	main.ads._mock = false
	main.ads._sync_banners()
	main.hiscore = 18436
	main.trophies.assign(["chain", "love", "roar"]) # no "trophy!" lines in the shots
	for god in main.gods:
		god._moves_since_action = 100

	# Zeus: a chain strike in mid-air
	_board([[0, 1, 2, 3], [4, 3, 2, 1], [5, 6, -1, 0], [7, -1, 1, 0]], 3412)
	main.zeus.strike_chance = 1.0
	main.zeus.chain_chance = 1.0
	main.zeus.chain_length = Vector2i(4, 4)
	main.zeus.big_tile_falloff = 1.0
	main.zeus.after_move()
	await _shot(lang, "1-zeus", "zeus", 0.24)
	await create_timer(1.2).timeout

	# Eros: every pair merges at once
	_board([[1, 1, 3, 3], [5, -1, 4, 4], [2, 2, -1, 0], [7, 6, 6, 1]], 5120)
	main.eros.merge_chance = 1.0
	main.eros.after_move()
	await _shot(lang, "2-eros", "eros", 0.2)
	await create_timer(1.2).timeout

	# Ares: the war cry blows the 2s away
	_board([[0, 3, 0, 5], [4, 0, 6, 0], [0, 2, 0, 7], [8, 0, 1, 0]], 7864)
	main.ares.scream_chance = 1.0
	main.ares.after_move()
	await _shot(lang, "3-ares", "ares", 0.3)
	await create_timer(1.5).timeout

	# the herald at 512
	_board([[8, 4, 2, -1], [5, 3, -1, -1], [2, 1, 0, -1], [0, -1, -1, -1]], 6210)
	main.boss = main.herald
	main.boss_active = true
	main.herald.reset()
	main._show_boss(true)
	main._refresh_ui()
	main._show_card("herald_intro", Herald.GREEN)
	await _shot(lang, "4-herald", "herald", 0.4)
	main._card.visible = false

	# Chaos: the boss fight
	_board([[10, 7, 4, 1], [8, 6, 3, -1], [5, 2, 0, -1], [1, 0, -1, -1]], 16742)
	main.boss = main.chaos
	main.boss_active = true
	main.chaos.reset()
	main.chaos.mood = "flood"
	main._show_boss(true)
	main.chaos.hp = 1584
	main._update_hp()
	main._refresh_ui()
	await _shot(lang, "5-chaos", "chaos", 0.15)

	main.queue_free()
	await process_frame


func _board(levels: Array, score: int) -> void:
	board.clear()
	for y in 4:
		for x in 4:
			if levels[y][x] >= 0:
				board.place_tile(Vector2i(x, y), levels[y][x])
	main.score = score
	main._update_score_labels()
	main.ares.rage_left = 0
	main.ares._update_status()
	main.boss_active = false
	main._show_boss(false)
	main._refresh_ui()


func _shot(lang: String, file: String, key: String, wait: float) -> void:
	print("shot ", lang, "/", file)
	_set_caption(CAPTIONS[lang][key])
	await create_timer(wait).timeout
	_shift_game()
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	image.resize(image.get_width() * SAVE_SCALE, image.get_height() * SAVE_SCALE, Image.INTERPOLATE_NEAREST)
	image.save_png(out_dir.path_join(lang).path_join(file + ".png"))


# The game hangs from the bottom of the screen, leaving the top for the caption.
func _shift_game() -> void:
	main._layout()
	for box: Control in [main._screen, main._game_over_box, main._card_box, main._confirm_box, main._tutorial.box]:
		box.position.y = CAPTION_SPACE


func _set_caption(lines: Array) -> void:
	if caption != null:
		caption.queue_free()
	var layer := CanvasLayer.new()
	layer.layer = 50
	root.add_child(layer)
	caption = Control.new()
	caption.size = Vector2(180, CAPTION_SPACE)
	layer.add_child(caption)
	caption.tree_exited.connect(layer.queue_free)
	for i in lines.size():
		var label := PixelLabel.new(lines[i], 2, Palette.GOLD, Palette.INK)
		label.fixed_width = 180
		label.position = Vector2(0, 4 + i * 20) # room for the dots of İ, Ö, Ü above line 2
		caption.add_child(label)
		if PixelFont.measure(lines[i], 2).x > 176:
			push_warning("caption too wide: " + lines[i])


# Night sky with stars and a bolt, behind the feature graphic.
class NightSky extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Palette.BG)
		seed(7)
		for i in 70:
			var star := Vector2(randi() % int(size.x), randi() % int(size.y))
			draw_rect(Rect2(star, Vector2.ONE), Palette.LIGHT if randf() > 0.75 else Palette.DIM.darkened(0.3))
		var bolt := PackedVector2Array([Vector2(132, 0), Vector2(126, 30), Vector2(136, 34), Vector2(124, 70), Vector2(134, 74), Vector2(122, 125)])
		draw_polyline(bolt, Palette.GOLD_DARK, 3.0)
		draw_polyline(bolt, Palette.GOLD, 1.0)
