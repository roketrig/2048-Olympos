# 2048 Olympos

Klasik 2048, bir farkla: Zeus tahtayı izliyor ve şansa bağlı olarak bir taşa yıldırım düşürüp onu **x2** ya da **x4** katlıyor. Oyun tıkandığında ise oyun başına bir kez araya girip bir birleşme imkânı açıyor.

Godot 4.7 ile yazıldı. Android ve iOS hedefleniyor.

## Çalıştırma

`project.godot` dosyasını Godot 4.7 ile açıp F5'e basın. Ok tuşları/WASD veya fareyle sürükleyerek oynanır; mobilde kaydırma.

## Zeus ayarları

`scripts/zeus.gd` içindeki export değişkenleri:

| Değişken | Varsayılan | Açıklama |
|---|---|---|
| `strike_chance` | 0.12 | Her hamlede vurma ihtimali |
| `cooldown_moves` | 3 | İki vuruş arasındaki en az hamle |
| `x4_chance` | 0.2 | Vuruşun x2 yerine x4 olma ihtimali |
| `rescues_per_game` | 1 | Oyun tıkanınca yapılan kurtarma sayısı |
| `portrait` | boş | İsteğe bağlı Zeus görseli |

## Export

- **Android:** `export_presets.cfg` içinde AAB (Gradle) hazır. Release imzası ortam değişkenlerinden okunur: `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `_USER`, `_PASSWORD`. İlk export'tan önce Godot'da *Proje → Android Derleme Şablonunu Yükle*.
- **iOS:** Xcode projesi üretir; derleme için macOS + Xcode ve Apple Developer hesabı gerekir.
