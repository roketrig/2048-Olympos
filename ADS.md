# Reklamlar (AdMob)

Oyundaki bütün reklamlar `scripts/ads.gd` içindeki `Ads` katmanından geçer. Oyunun geri kalanı AdMob'u doğrudan çağırmaz.

## Şu anki durum

- **AdMob eklentisi kurulu:** Poing Studios godot-admob-plugin v5.1.0 (MIT), `addons/admob`. Android ve iOS reklam paketleri `addons/admob/*/bin` içinde, repoya dahil.
- Eklentiyle oyun arasındaki köprü `scripts/admob_backend.gd`. Açılış sırası Google'ın kurallarına göre: önce onay (UMP; GDPR mesajı gereken ülkelerde form çıkar), sonra SDK, sonra reklamlar yüklenir. Geçiş ve ödüllü reklamlar önceden yüklenir ve her gösterimden sonra yenisi yüklenir.
- Android uygulama ID'si `project.godot` içinde (`admob/general/android/app_id`); build sırasında manifest'e yazılır.
- Android reklam birimi ID'lerimiz `Ads.LIVE_IDS` içinde. Bunları **sadece release build'ler** kullanır.
- Debug build'ler (telefonda test ettiğiniz APK dahil) her zaman Google'ın herkese açık **test** ID'lerini (`Ads.TEST_IDS`) kullanır. Telefonda "Test Ad" yazan gerçek Google test reklamları görürsünüz; kendi canlı reklamınız test sırasında hiç görünmez.
- Masaüstünde (eklenti yokken) debug çalıştırmalarda "TEST AD" yazan yer tutucular görünür; düzeni ve akışları denemek için.
- Banner yüksekliği AdMob'un bildirdiği gerçek adaptive yükseklikten alınır; oyun banner'ların arasına sığacak şekilde yeniden yerleşir.
- Eklentinin MIT lisans bildirimi "?" → HAKKINDA ekranındaki lisanslarda.
- iOS uygulaması AdMob'a eklenince iOS ID'leri `Ads.LIVE_IDS` ve `project.godot` (`admob/general/ios/app_id`) içine girilecek.

## Yerleşim ve kurallar (koda işlendi)

| Kural | Uygulama |
|---|---|
| Banner, butonlara yapışık olmamalı (yanlışlıkla tıklama) | Banner ile oyun arasında en az `AD_GAP` (6 oyun pikseli ≈ 18dp) boşluk |
| Notch / home bar'ın altında kalmamalı | Güvenli alan (safe area) hesaba katılıyor |
| Kısa ekranlar (16:9) | Önce üst banner kapanıyor; yine sığmazsa oyun tam piksel ölçeğinde küçülüyor |
| Interstitial beklenmedik anda çıkmamalı | Sadece Game Over'dan sonra **TRY AGAIN**'e basınca, yeni oyuna geçerken |
| Interstitial sıklığı | En fazla 2 oyun sonunda bir, en az 2 dakika arayla, oturumun ilk dakikasında hiç |
| Ödüllü reklam isteğe bağlı ve ödülü açık olmalı | "WATCH AD TO CONTINUE" butonu (oyun başına 1 kez). Kalp butonunda "AD" yazar ve ilk dokunuş sadece teklif eder ("TAP AGAIN: AD FOR A POTION"), ikinci dokunuş reklamı açar (oyun başına 2 iksir) |
| Reklam sırasında oyun sesi | Tam ekran reklam boyunca oyun sesi kısılıyor |
| Onay (GDPR/UMP) değiştirilebilmeli | "?" ekranında **PRIVACY** butonu (SDK gerekli dediğinde görünür) |

## Eklentiyi güncellemek

1. https://github.com/poingstudios/godot-admob-plugin/releases adresinden Godot sürümünüze uyan `poing-godot-admob-vX.zip`, `android-template-v<godot>.zip` ve `ios-template-v<godot>.zip` dosyalarını indirin.
2. `addons/admob` klasörünü yenisiyle değiştirin (`csharp` ve `skills` klasörleri gerekmez). Şablonların içindeki `package.gd` ve `ads` klasörünü `addons/admob/android/bin` ve `addons/admob/ios/bin` içine koyun.
3. Testleri çalıştırıp yeni bir APK alın ve telefonda reklamları deneyin.

## Mağaza tarafında yapılacaklar

- **Gizlilik politikası:** `PRIVACY.md` taslağını düzenleyip herkese açık bir adreste yayınlayın (örneğin GitHub Pages). Linkini iki mağazaya da girin.
- **Google Play:** "Data safety" formunu doldurun (reklam kimliği, yaklaşık konum, uygulama etkileşimleri, AdMob üzerinden). Uygulamada reklam var olarak işaretleyin. Hedef kitleyi **13+** seçin.
- **App Store:** "App Privacy" etiketlerini doldurun. ATT metni `NSUserTrackingUsageDescription` olarak hazır.
- **app-ads.txt:** AdMob'un verdiği satırı geliştirici web sitenizin köküne koyun. Önerilen bir adımdır, reklam gelirini korur.
- **SKAdNetwork:** iOS için Google'ın güncel SKAdNetwork listesini `export_presets.cfg` dosyasına ekleyin. Şu an yalnızca Google'ın kendi kimliği var.
