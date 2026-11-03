class_name AdMobBackend
extends RefCounted

# Bridge from Ads to the Poing Studios AdMob plugin (addons/admob). Only used
# when the native plugin is in the build (Android export); everywhere else Ads
# falls back to its test placeholders or no ads at all.
#
# Start-up order follows Google's rules: consent first (UMP form where it
# applies), then the SDK, then ads are loaded. Full-screen ads are preloaded so
# they open instantly, and reloaded after each show.

signal banner_size_changed
signal _fullscreen_closed

const RETRY_SECONDS := 30.0

var _ads: Node # for timers
var _ids: Dictionary
var _started := false
var _want_top := false
var _want_bottom := false
var _top: AdView
var _bottom: AdView
var _banner_dp := 0.0
var _interstitial: InterstitialAd
var _rewarded: RewardedAd
var _earned := false


static func available() -> bool:
	return Engine.has_singleton("PoingGodotAdMob")


func _init(ads: Node) -> void:
	_ads = ads


func initialize(ids: Dictionary) -> void:
	_ids = ids
	UserMessagingPlatform.consent_information.update(ConsentRequestParameters.new(), _on_consent_updated, _on_form_error)


func _on_consent_updated() -> void:
	if UserMessagingPlatform.consent_information.get_is_consent_form_available():
		UserMessagingPlatform.load_consent_form(_on_consent_form_loaded, _on_form_error)
	else:
		_start_sdk()


func _on_consent_form_loaded(form: ConsentForm) -> void:
	if UserMessagingPlatform.consent_information.get_consent_status() == ConsentInformation.ConsentStatus.REQUIRED:
		form.show(_on_form_error)
	else:
		_start_sdk()


# Every consent path ends here, error or not: the SDK honors whatever was chosen.
func _on_form_error(_error: FormError) -> void:
	_start_sdk()


func _start_sdk() -> void:
	if _started:
		return
	_started = true
	var config := RequestConfiguration.new()
	config.max_ad_content_rating = RequestConfiguration.MAX_AD_CONTENT_RATING_T # the game is rated 13+
	MobileAds.set_request_configuration(config)

	var listener := OnInitializationCompleteListener.new()
	listener.on_initialization_complete = _on_sdk_ready
	MobileAds.initialize(listener)


func _on_sdk_ready(_status: InitializationStatus) -> void:
	_banner_dp = _banner_size().height
	banner_size_changed.emit()
	_sync_banners()
	_load_interstitial()
	_load_rewarded()


# --- banners --------------------------------------------------------------------

func show_banners(top: bool, bottom: bool) -> void:
	_want_top = top
	_want_bottom = bottom
	_sync_banners()


# Height of the anchored adaptive banner in dp, once known (0 before that).
func banner_dp() -> float:
	return _banner_dp


func _banner_size() -> AdSize:
	return AdSize.get_current_orientation_anchored_adaptive_banner_ad_size(AdSize.FULL_WIDTH)


func _sync_banners() -> void:
	if _banner_dp == 0.0:
		return # the SDK is not ready yet; _on_sdk_ready calls this again
	_bottom = _sync_banner(_bottom, _want_bottom, AdPosition.BOTTOM)
	_top = _sync_banner(_top, _want_top, AdPosition.TOP)


func _sync_banner(view: AdView, wanted: bool, position: AdPosition) -> AdView:
	if wanted and view == null:
		view = AdView.new(_ids["banner"], _banner_size(), position)
		view.load_ad(AdRequest.new())
	elif not wanted and view != null:
		view.destroy()
		view = null
	return view


# --- interstitial -------------------------------------------------------------------

func _load_interstitial() -> void:
	var callback := InterstitialAdLoadCallback.new()
	callback.on_ad_loaded = _on_interstitial_loaded
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: _retry(_load_interstitial)
	InterstitialAdLoader.new().load(_ids["interstitial"], AdRequest.new(), callback)


func _on_interstitial_loaded(ad: InterstitialAd) -> void:
	_interstitial = ad
	ad.full_screen_content_callback = _closing_callback(_on_interstitial_closed)


func _on_interstitial_closed() -> void:
	if _interstitial != null:
		_interstitial.destroy()
		_interstitial = null
	_load_interstitial()


# Returns when the ad closes (right away if none is loaded).
func show_interstitial() -> void:
	if _interstitial == null:
		return
	_interstitial.show()
	await _fullscreen_closed


# --- rewarded ---------------------------------------------------------------------

func _load_rewarded() -> void:
	var callback := RewardedAdLoadCallback.new()
	callback.on_ad_loaded = _on_rewarded_loaded
	callback.on_ad_failed_to_load = func(_error: LoadAdError) -> void: _retry(_load_rewarded)
	RewardedAdLoader.new().load(_ids["rewarded"], AdRequest.new(), callback)


func _on_rewarded_loaded(ad: RewardedAd) -> void:
	_rewarded = ad
	ad.full_screen_content_callback = _closing_callback(_on_rewarded_closed)


func _on_rewarded_closed() -> void:
	if _rewarded != null:
		_rewarded.destroy()
		_rewarded = null
	_load_rewarded()


func rewarded_ready() -> bool:
	return _rewarded != null


# Returns true if the player earned the reward.
func show_rewarded() -> bool:
	if _rewarded == null:
		return false
	_earned = false
	var listener := OnUserEarnedRewardListener.new()
	listener.on_user_earned_reward = _on_reward_earned
	_rewarded.show(listener)
	await _fullscreen_closed
	return _earned


func _on_reward_earned(_item: RewardedItem) -> void:
	_earned = true


# --- privacy --------------------------------------------------------------------

func privacy_options_required() -> bool:
	return UserMessagingPlatform.consent_information.get_privacy_options_requirement_status() \
		== ConsentInformation.PrivacyOptionsRequirementStatus.REQUIRED


func show_privacy_options() -> void:
	UserMessagingPlatform.show_privacy_options_form()


# --- helpers ----------------------------------------------------------------------

# Dismissed or failed to show: either way the ad is over. `cleanup` frees it and
# preloads the next one; then whoever is waiting in show_*() carries on.
func _closing_callback(cleanup: Callable) -> FullScreenContentCallback:
	var callbacks := FullScreenContentCallback.new()
	callbacks.on_ad_dismissed_full_screen_content = func() -> void:
		cleanup.call()
		_fullscreen_closed.emit()
	callbacks.on_ad_failed_to_show_full_screen_content = func(_error: AdError) -> void:
		cleanup.call()
		_fullscreen_closed.emit()
	return callbacks


func _retry(load: Callable) -> void:
	await _ads.get_tree().create_timer(RETRY_SECONDS).timeout
	load.call()
