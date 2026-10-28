class_name Ads
extends CanvasLayer

# Every ad goes through here. With the AdMob plugin installed, `_find_backend`
# returns the bridge to it (see ADS.md). Debug builds without the plugin show
# clearly marked test placeholders, so the layout and flows can be tried on
# desktop. Release builds without the plugin show no ads at all.

signal layout_changed

# Google's public TEST ids. Replace them with your own before release (ADS.md);
# never click your own live ads.
const IDS := {
	"Android": {
		"app": "ca-app-pub-3940256099942544~3347511713",
		"banner": "ca-app-pub-3940256099942544/9214589741",
		"interstitial": "ca-app-pub-3940256099942544/1033173712",
		"rewarded": "ca-app-pub-3940256099942544/5224354917",
	},
	"iOS": {
		"app": "ca-app-pub-3940256099942544~1458002511",
		"banner": "ca-app-pub-3940256099942544/2435281174",
		"interstitial": "ca-app-pub-3940256099942544/4411468910",
		"rewarded": "ca-app-pub-3940256099942544/1712485313",
	},
}

const BANNER_DP := 60.0 # space kept per banner; anchored adaptive banners are ~50-60dp on phones
const AD_GAP := 6.0 # game pixels between a banner and anything tappable
const INTERSTITIAL_EVERY := 2 # at most every 2nd game over...
const INTERSTITIAL_MIN_SECONDS := 120.0 # ...at most once every 2 minutes...
const SESSION_GRACE_SECONDS := 60.0 # ...and never in the first minute of a session
const REWARDED_POTIONS_PER_GAME := 2

# The layout turns the top banner off on short screens.
var top_banner := true:
	set(value):
		if top_banner == value:
			return
		top_banner = value
		_sync_banners()
		layout_changed.emit()

var _backend: Object = null
var _mock := false
var _showing := false
var _game_overs_since_ad := 0
var _last_interstitial := -1.0e9
var _mock_banners: MockBanners


func _ready() -> void:
	layer = 100
	_backend = _find_backend()
	_mock = _backend == null and OS.is_debug_build()

	_mock_banners = MockBanners.new()
	_mock_banners.ads = self
	add_child(_mock_banners)

	if _backend != null:
		_backend.initialize(IDS.get(OS.get_name(), IDS["Android"]))
	get_viewport().size_changed.connect(_sync_banners)
	_sync_banners()


# Bridge to the AdMob plugin. Return an object with: initialize(ids: Dictionary)
# (runs the UMP consent form / iOS tracking prompt, then loads ads),
# show_banners(top: bool, bottom: bool), show_interstitial() and
# show_rewarded() -> bool (coroutines that return when the ad closes),
# rewarded_ready() -> bool, privacy_options_required() -> bool and
# show_privacy_options(). See ADS.md.
func _find_backend() -> Object:
	return null


func enabled() -> bool:
	return _mock or _backend != null


func is_showing() -> bool:
	return _showing


# --- layout -------------------------------------------------------------------

# Game-pixel space above and below the game: safe area + banner + gap.
func top_inset() -> float:
	return safe_area().position.y + (banner_height() + AD_GAP if enabled() and top_banner else 0.0)


func bottom_inset() -> float:
	var safe := safe_area()
	return (_viewport_size().y - safe.end.y) + (banner_height() + AD_GAP if enabled() else 0.0)


func banner_height() -> float:
	var px_per_dp: float
	if OS.has_feature("mobile"):
		px_per_dp = DisplayServer.screen_get_scale() if OS.get_name() == "iOS" else DisplayServer.screen_get_dpi() / 160.0
	else:
		px_per_dp = DisplayServer.window_get_size().y / 640.0 # desktop preview: pretend a 640dp phone
	return ceilf(BANNER_DP * px_per_dp * _to_game())


# Notch / home indicator free area, in game coordinates.
func safe_area() -> Rect2:
	var viewport := _viewport_size()
	if not OS.has_feature("mobile"):
		return Rect2(Vector2.ZERO, viewport)
	var area := Rect2(DisplayServer.get_display_safe_area())
	var factor := _to_game()
	return Rect2(area.position * factor, area.size * factor)


func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size


func _to_game() -> float:
	return _viewport_size().y / maxf(DisplayServer.window_get_size().y, 1.0)


func _sync_banners() -> void:
	if _backend != null:
		_backend.show_banners(top_banner, true)
	_mock_banners.visible = _mock
	_mock_banners.queue_redraw()


# --- interstitial ---------------------------------------------------------------

func count_game_over() -> void:
	_game_overs_since_ad += 1


func interstitial_due() -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	return enabled() \
		and _game_overs_since_ad >= INTERSTITIAL_EVERY \
		and now - _last_interstitial >= INTERSTITIAL_MIN_SECONDS \
		and now >= SESSION_GRACE_SECONDS


# Shows an interstitial if the frequency caps allow it; returns when it closes.
func show_interstitial_if_due() -> void:
	if not interstitial_due():
		return
	_game_overs_since_ad = 0
	_last_interstitial = Time.get_ticks_msec() / 1000.0
	_begin()
	if _mock:
		await _mock_fullscreen("TEST AD", "INTERSTITIAL", false)
	else:
		await _backend.show_interstitial()
	_end()


# --- rewarded -------------------------------------------------------------------

func rewarded_ready() -> bool:
	return _mock or (_backend != null and _backend.rewarded_ready())


# Returns true if the player watched to the end and earned the reward.
func show_rewarded() -> bool:
	if not rewarded_ready():
		return false
	_begin()
	var earned: bool
	if _mock:
		earned = await _mock_fullscreen("TEST AD", "REWARDED", true)
	else:
		earned = await _backend.show_rewarded()
	_end()
	return earned


# --- privacy --------------------------------------------------------------------

# UMP requires a way to change consent later, for users where it applies.
func privacy_options_required() -> bool:
	return _mock or (_backend != null and _backend.privacy_options_required())


func show_privacy_options() -> void:
	if _mock:
		_begin()
		await _mock_fullscreen("PRIVACY", "CONSENT FORM (TEST)", false)
		_end()
	elif _backend != null:
		_backend.show_privacy_options()


# --- helpers ----------------------------------------------------------------------

# Game sound is muted while a full-screen ad plays.
func _begin() -> void:
	_showing = true
	AudioServer.set_bus_mute(0, true)


func _end() -> void:
	AudioServer.set_bus_mute(0, false)
	_showing = false


func _mock_fullscreen(title: String, subtitle: String, countdown: bool) -> bool:
	var screen := ColorRect.new()
	screen.color = Color(0.1, 0.1, 0.12)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(screen)

	var center := _viewport_size() / 2.0
	for line in [[title, 3, -40.0], [subtitle, 1, -10.0]]:
		var label := PixelLabel.new(line[0], line[1], Palette.LIGHT)
		label.position = (center + Vector2(-label.size.x / 2.0, line[2])).floor()
		screen.add_child(label)

	var close := PixelButton.new("CLOSE", 60, 18, Palette.CELL.lightened(0.15))
	close.position = (center + Vector2(-30, 20)).floor()
	screen.add_child(close)

	if countdown:
		close.disabled = true
		for i in range(3, 0, -1):
			close.text = "WAIT %d" % i
			await get_tree().create_timer(1.0).timeout
		close.disabled = false
		close.text = "CLOSE"
		close.queue_redraw()

	await close.pressed
	screen.queue_free()
	return true


# Grey "TEST AD" boxes where the real banners will sit.
class MockBanners extends Control:
	var ads: Ads

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var safe := ads.safe_area()
		var height := ads.banner_height()
		var bottom := Rect2(0, safe.end.y - height, size.x, height)
		_banner(bottom)
		if ads.top_banner:
			_banner(Rect2(0, safe.position.y, size.x, height))

	func _banner(rect: Rect2) -> void:
		draw_rect(rect, Color(0.55, 0.55, 0.6))
		draw_rect(rect, Color(0.3, 0.3, 0.35), false, 1.0)
		PixelFont.draw_centered(self, "TEST AD BANNER", rect, 1, Color(0.2, 0.2, 0.25))
