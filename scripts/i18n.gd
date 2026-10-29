class_name I18n
extends RefCounted

# All player-facing text in English and Turkish. The pixel font is uppercase,
# so Turkish strings are written in uppercase directly (İ, I, Ğ, Ş, Ç, Ö, Ü).
# Width limits: hints <= 29 chars, banners <= 15, tutorial lines <= 26.

const LANGUAGES: Array[String] = ["en", "tr"]

static var lang := "en"

const STRINGS := {
	"en": {
		"score": "SCORE",
		"best": "BEST",
		"new_game": "NEW GAME",
		"game_over": "GAME OVER",
		"score_n": "SCORE %d",
		"try_again": "TRY AGAIN",
		"watch_continue": "WATCH AD TO CONTINUE",
		"hint_swipe": "SWIPE TO MERGE TILES",
		"hint_gods": "TAP A GOD TO SEE WHAT IT DOES",
		"hint_pick": "TAP A TILE TO LIFT IT",
		"hint_drop": "TAP EMPTY CELL TO DROP",
		"hint_offer": "TAP AGAIN: AD FOR A POTION",
		"hint_rage": "ARES RAGE: SCORE x%s",
		"banner_rescue": "DIVINE RESCUE!",
		"banner_love": "LOVE MERGE!",
		"banner_roar": "ARES ROARS!",
		"banner_chain": "CHAIN x%d",
		"banner_saves": "ZEUS SAVES YOU!",
		"banner_smites": "ZEUS SMITES!",
		"potion_plus": "+POTION",
		"back": "BACK",
		"next": "NEXT",
		"play": "PLAY",
		"ok": "OK",
		"privacy": "PRIVACY",
		"credits": "CREDITS",
		"chaos": "CHAOS",
		"hp": "HP %d/%d",
		"banner_chaos": "CHAOS AWAKENS!",
		"banner_split": "SHATTER!",
		"banner_flood": "CURSE OF 2S!",
		"potion_minus": "-POTION",
		"hint_boss": "MERGE TILES TO HURT CHAOS",
		"hint_curse": "CHAOS CURSE: HITS x%s",
		"intro_title": "2048!",
		"intro_1": "BUT CHAOS AWAKENS...",
		"intro_2": "THE GODS ARE GONE.",
		"intro_3": "MERGE TILES TO",
		"intro_4": "DAMAGE HIM!",
		"fight": "FIGHT!",
		"victory_title": "VICTORY!",
		"victory_1": "CHAOS IS DEFEATED.",
		"victory_2": "THE GODS RETURN!",
		"victory_3": "+2048 BONUS",
		"victory_4": "",
		"continue": "CONTINUE",
		"credits_by": "A GAME BY",
		"credits_engine": "MADE WITH GODOT ENGINE",
		"credits_licenses": "LICENSES:",
	},
	"tr": {
		"score": "SKOR",
		"best": "EN İYİ",
		"new_game": "YENİ OYUN",
		"game_over": "OYUN BİTTİ",
		"score_n": "SKOR %d",
		"try_again": "TEKRAR DENE",
		"watch_continue": "REKLAM İZLE, DEVAM ET",
		"hint_swipe": "KAYDIR VE BİRLEŞTİR",
		"hint_gods": "TANRIYA DOKUN: NE YAPAR?",
		"hint_pick": "KALDIRMAK İÇİN TAŞA DOKUN",
		"hint_drop": "BOŞ KAREYE DOKUN: BIRAK",
		"hint_offer": "TEKRAR DOKUN: REKLAM = İKSİR",
		"hint_rage": "ARES ÖFKESİ: SKOR x%s",
		"banner_rescue": "İLAHİ KURTARIŞ!",
		"banner_love": "AŞK BİRLEŞMESİ!",
		"banner_roar": "ARES KÜKRÜYOR!",
		"banner_chain": "ZİNCİR x%d",
		"banner_saves": "ZEUS KURTARDI!",
		"banner_smites": "ZEUS VURDU!",
		"potion_plus": "+İKSİR",
		"back": "GERİ",
		"next": "İLERİ",
		"play": "OYNA",
		"ok": "TAMAM",
		"privacy": "GİZLİLİK",
		"credits": "HAKKINDA",
		"chaos": "KAOS",
		"hp": "CAN %d/%d",
		"banner_chaos": "KAOS UYANDI!",
		"banner_split": "PARÇALANMA!",
		"banner_flood": "2'LERİN LANETİ!",
		"potion_minus": "-İKSİR",
		"hint_boss": "BİRLEŞTİR, KAOS'A VUR!",
		"hint_curse": "KAOS LANETİ: HASAR x%s",
		"intro_title": "2048!",
		"intro_1": "AMA KAOS UYANDI...",
		"intro_2": "TANRILAR YOK OLDU.",
		"intro_3": "TAŞLARI BİRLEŞTİR,",
		"intro_4": "KAOS'A HASAR VER!",
		"fight": "SAVAŞ!",
		"victory_title": "ZAFER!",
		"victory_1": "KAOS YENİLDİ.",
		"victory_2": "TANRILAR GERİ DÖNDÜ!",
		"victory_3": "+2048 BONUS",
		"victory_4": "",
		"continue": "DEVAM ET",
		"credits_by": "YAPIMCI",
		"credits_engine": "GODOT ENGINE İLE YAPILDI",
		"credits_licenses": "LİSANSLAR:",
	},
}

const PAGES := {
	"en": [
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
	],
	"tr": [
		{"title": "NASIL OYNANIR", "art": "merge", "lines": [
			"TAŞLARI KAYDIR.",
			"AYNI SAYILAR BİRLEŞİR.",
			"2048'E ULAŞ!",
			"",
			"OLYMPOS TANRILARI",
			"SENİ İZLİYOR...",
		]},
		{"title": "ZEUS", "art": "zeus", "lines": [
			"BİR TAŞA YILDIRIM",
			"DÜŞÜRÜR: x2 VEYA x4.",
			"NADİREN YILDIRIM TAŞTAN",
			"TAŞA SEKER, HER BİRİ x2.",
			"HAMLE KALMAYINCA SENİ",
			"BİR KEZ KURTARIR.",
		]},
		{"title": "EROS", "art": "eros", "lines": [
			"YAN YANA DURAN BÜTÜN",
			"EŞ SAYILARI AYNI ANDA",
			"BİRLEŞTİRİR.",
			"",
			"BİRLEŞTİRDİKÇE ARA SIRA",
			"AŞK İKSİRİ VERİR.",
		]},
		{"title": "AŞK İKSİRİ", "art": "potion", "lines": [
			"KALP BUTONUNA, SONRA",
			"BİR TAŞA DOKUN: TAŞ",
			"TAHTADAN KALKAR.",
			"",
			"İSTEDİĞİN ZAMAN BOŞ BİR",
			"KAREYE DOKUNUP GERİ KOY.",
		]},
		{"title": "ARES", "art": "ares", "lines": [
			"SAVAŞ ÇIĞLIĞI TÜM 2'LERİ",
			"TAHTADAN SİLER.",
			"",
			"SONRAKİ 8 HAMLE BOYUNCA",
			"SKORUN x1.5 OLUR!",
			"",
		]},
	],
}


# Shown when the player taps Chaos; kept out of the regular pages so the boss
# stays a surprise.
const CHAOS_PAGE := {
	"en": {"title": "CHAOS", "art": "chaos", "lines": [
		"LORD OF DISORDER.",
		"MERGE TILES TO HURT HIM.",
		"HE HALVES TILES, SPLITS",
		"THEM, FLOODS THE BOARD",
		"WITH 2S, WEAKENS HITS",
		"AND STEALS POTIONS.",
	]},
	"tr": {"title": "KAOS", "art": "chaos", "lines": [
		"DÜZENSİZLİĞİN EFENDİSİ.",
		"BİRLEŞTİR, HASAR VER.",
		"TAŞLARI YARILAR, BÖLER,",
		"TAHTAYI 2'LERLE DOLDURUR,",
		"VURUŞLARINI ZAYIFLATIR,",
		"İKSİR ÇALAR.",
	]},
}


static func t(key: String) -> String:
	return STRINGS[lang].get(key, STRINGS["en"].get(key, key))


static func pages() -> Array:
	return PAGES[lang]


static func chaos_page() -> Dictionary:
	return CHAOS_PAGE[lang]


# Turkish phones start in Turkish, everything else in English.
static func detect() -> String:
	return "tr" if OS.get_locale_language() == "tr" else "en"
