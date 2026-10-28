# Reklamlar (AdMob)

Oyundaki bütün reklamlar `scripts/ads.gd` içindeki `Ads` katmanından geçer. Oyunun geri kalanı AdMob'u doğrudan çağırmaz.

## Şu anki durum

- AdMob eklentisi **henüz kurulu değil**.
- Debug build'lerde reklamların yerinde açıkça **"TEST AD"** yazan yer tutucular görünür. Bunlar banner kutuları ile tam ekran interstitial ve ödüllü reklam ekranlarıdır. Amaçları düzeni ve akışları masaüstünde denemektir.
- Release build'de eklenti yoksa hiç reklam gösterilmez. Oyun reklamsız da sorunsuz çalışır.
- `Ads.IDS` içinde Google'ın herkese açık **test** ID'leri var. Yayından önce kendi ID'lerinizle değiştirin.

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

## Eklentiyi bağlamak

1. Bir AdMob hesabı açın. Android ve iOS için iki ayrı uygulama ekleyin. Her biri için **anchored adaptive banner**, **interstitial** ve **rewarded** reklam birimleri oluşturun.
2. Godot 4 için bir AdMob eklentisi kurun. Örneğin Asset Library'de "AdMob" diye arayın; yaygın olanı poing-studios'un eklentisidir. Eklentinin Godot 4.7 sürümünü desteklediğinden emin olun ve kendi kurulum adımlarını izleyin. Android'de Gradle build zaten açık.
3. `scripts/admob_backend.gd` dosyasını oluşturun. Bu dosya, `ads.gd` içindeki `_find_backend()` yorumunda listelenen fonksiyonları eklentinin API'sine bağlar:
   - `initialize(ids)`: Önce UMP onay formunu, iOS'ta da ATT izin penceresini gösterir, sonra SDK'yı başlatır ve reklamları önceden yükler.
   - `show_banners(top, bottom)`
   - `show_interstitial()` ve `show_rewarded() -> bool`: Reklam kapanınca dönen coroutine'ler. `show_rewarded` ödül kazanıldıysa `true` döner.
   - `rewarded_ready() -> bool`, `privacy_options_required() -> bool`, `show_privacy_options()`
4. `_find_backend()` fonksiyonunda eklentinin singleton'ı varsa bu nesneyi döndürün.
5. `Ads.IDS` içindeki test ID'lerini kendi ID'lerinizle değiştirin. iOS uygulama ID'sini `export_presets.cfg` dosyasındaki `GADApplicationIdentifier` alanına yazın. Android uygulama ID'si eklentinin ayarlarına girer.
6. Test ederken kendi telefonunuzu AdMob'da **test cihazı** olarak ekleyin. Kendi canlı reklamlarınıza asla tıklamayın; hesabınız kapatılabilir.

## Mağaza tarafında yapılacaklar

- **Gizlilik politikası:** `PRIVACY.md` taslağını düzenleyip herkese açık bir adreste yayınlayın (örneğin GitHub Pages). Linkini iki mağazaya da girin.
- **Google Play:** "Data safety" formunu doldurun (reklam kimliği, yaklaşık konum, uygulama etkileşimleri, AdMob üzerinden). Uygulamada reklam var olarak işaretleyin. Hedef kitleyi **13+** seçin.
- **App Store:** "App Privacy" etiketlerini doldurun. ATT metni `NSUserTrackingUsageDescription` olarak hazır.
- **app-ads.txt:** AdMob'un verdiği satırı geliştirici web sitenizin köküne koyun. Önerilen bir adımdır, reklam gelirini korur.
- **SKAdNetwork:** iOS için Google'ın güncel SKAdNetwork listesini `export_presets.cfg` dosyasına ekleyin. Şu an yalnızca Google'ın kendi kimliği var.
