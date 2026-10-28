# 2048 Olympos

8-bit retro tarzında klasik 2048, üç Olympos tanrısıyla. Her hamleden sonra en fazla bir tanrı şansa bağlı olarak devreye girer:

- **Zeus:** Bir taşa yıldırım düşürüp **x2** ya da **x4** katlar. Nadiren yıldırım taştan taşa sekerek birkaç taşı birden **x2** yapar. Oyun tıkanınca oyun başına bir kez araya girip bir birleşme imkânı açar.
- **Eros:** Yan yana duran bütün eş sayıları aynı anda birleştirir. Birleştirme yaptıkça ara sıra **aşk iksiri** düşürür: iksirle bir taşı tahtadan alıp istediğin zaman boş bir kareye geri koyabilirsin.
- **Ares:** Savaş çığlığı atar: tahtadaki bütün 2'leri temizler ve 8 hamle boyunca kazanılan skoru **x1.5** yapar.

Godot 4.7 ile yazıldı; 180x320 piksel çözünürlükte çizilip ekrana ölçeklenir. Font, Zeus sprite'ı ve chiptune sesler kodla üretilir, harici asset yok. Android ve iOS hedefleniyor.

## Çalıştırma

`project.godot` dosyasını Godot 4.7 ile açıp F5'e basın. Ok tuşları/WASD veya fareyle sürükleyerek oynanır; mobilde kaydırma.

## Tanrı ayarları

Olasılıklar ve süreler `scripts/zeus.gd`, `scripts/eros.gd` ve `scripts/ares.gd` içindeki export değişkenleridir. Zeus için:

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `strike_chance` | 0.12 | Her hamlede vurma ihtimali |
| `cooldown_moves` | 3 | İki vuruş arasındaki en az hamle |
| `x4_chance` | 0.2 | Vuruşun x2 yerine x4 olma ihtimali |
| `chain_chance` | 0.2 | Vuruşun zincirleme yıldırım olma ihtimali |
| `rescues_per_game` | 1 | Oyun tıkanınca yapılan kurtarma sayısı |

Eros: `merge_chance` 0.08, `cooldown_moves` 4, `potion_chance` 0.06 (birleştirme olan hamle başına). Ares: `scream_chance` 0.07, `cooldown_moves` 6, `rage_moves` 8, `score_multiplier` 1.5.

## Export

- **Android:** `export_presets.cfg` içinde AAB (Gradle) hazır. Release imzası ortam değişkenlerinden okunur: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD`. İlk export'tan önce Godot'da *Proje → Android Derleme Şablonunu Yükle*.
- **iOS:** Xcode projesi üretir; derleme için macOS + Xcode ve Apple Developer hesabı gerekir.

## Reklamlar

Alt/üst banner, sıklık sınırlı interstitial ve isteğe bağlı ödüllü reklamlar `scripts/ads.gd` üzerinden yönetilir. AdMob kurulumu, uygulanan kurallar ve mağaza adımları için [ADS.md](ADS.md); gizlilik politikası taslağı için [PRIVACY.md](PRIVACY.md).
