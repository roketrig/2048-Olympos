# 2048 Olympos — Yayın Yol Haritası

Yayına kadar kalan her şey burada, yapılma sırasına göre. Bir adımı bitirince `[ ]` işaretini `[x]` yapın. Takıldığınız bir adımda bu dosyayı açıp Claude'a "YAYIN.md'deki X adımı" diye sorabilirsiniz.

_Son güncelleme: 29 Ekim 2026_

---

## ✅ Bitenler

- [x] Oyun Godot 4.7'ye taşındı; Android'de kaydırmayla oynanıyor.
- [x] 8-bit retro görünüm, chiptune sesler, piksel ikon.
- [x] Tanrılar:
  - Zeus: x2/x4 çarpan, zincirleme yıldırım ve oyun başına bir kurtarma.
  - Eros: toplu birleştirme ve aşk iksiri.
  - Ares: 2'leri temizleme ve x1.5 skor.
- [x] Nasıl oynanır rehberi; portreye dokununca tanrı kartı açılıyor.
- [x] Reklam altyapısı (`scripts/ads.gd`). Şimdilik "TEST AD" yer tutucularıyla çalışıyor:
  - Banner'lara göre ayarlanan ekran düzeni.
  - Sıklık sınırlı interstitial.
  - Ödüllü devam ve ödüllü iksir.
  - PRIVACY butonu.
- [x] Android (AAB + test APK) ve iOS export ayarları.
- [x] Credits / Lisans ekranı: "?" → HAKKINDA. Godot MIT bildirimi ve tüm alt bileşenlerin lisansları burada.
- [x] Türkçe ve İngilizce dil desteği. Telefon Türkçeyse oyun Türkçe açılır; "?" ekranındaki TR/EN butonuyla dil değiştirilebilir.
- [x] **Kaos boss savaşı** (ilk 2048 taşında, oyun başına bir kez):
  - Tanrılar yok oluyor, kendi müziğiyle Kaos geliyor. Kaos'un 3000 canı var.
  - Her birleştirme, taşın değeri kadar hasar veriyor.
  - Kaos tanrıların tersini yapıyor, ama daha düşük ihtimalle: taşı yarılıyor (Zeus'un tersi), taşları ikiye bölüp iksir çalıyor (Eros'un tersi), tahtaya 2'ler döküp vuruşları yarıya indiriyor (Ares'in tersi).
  - Kaos yenilince tanrılar geri dönüyor ve +2048 bonus geliyor.
- [x] **Kaos'un Elçisi** (ilk 512 taşında, oyun başına bir kez): 500 canlı mini boss. Taş yarılar ve 2 döker; bölme ve iksir çalma yok. Yenilince +512 bonus. 2048'e Elçi'yi atlayarak ulaşılırsa Elçi gelmez.
- [x] **Kaos'un huyu:** Her savaşta üç gücünden biri 1,8 kat sık, diğerleri 0,6 kat. Huy, giriş kartında yazıyor.
- [x] **Kaos rekoru:** Zafer kartı kaç hamlede yendiğinizi ve rekorunuzu gösteriyor.
- [x] **Başarılar:** Başlıktaki kupa butonu 6 başarıyı gösteriyor (Zeus zinciri, aşk birleşmesi, Ares çığlığı, Elçi, Kaos, 8192). Açılınca altta altın renkli mesaj çıkıyor; telefona kaydediliyor.
- [x] **Boss rehberleri:** Elçi'ye ve Kaos'a ilk kez ulaşıldığında kendi rehberleri açılıyor (bir kez). Baştaki rehberde yer almıyorlar; boss'un portresine dokunarak tekrar açılabiliyorlar.
- [x] Tanrıların olasılıkları test geri bildirimine göre yaklaşık %15-20 düşürüldü (Zeus 0.10, Eros 0.065, Ares 0.055).
- [x] **Son taş 8192.** 8192 artık birleşmez, Zeus çarpmaz, Kaos dokunmaz; altın çerçeveyle işaretli. Değiştirmek için `board.gd` içindeki `MAX_LEVEL` (12 = 8192, 13 = 16384).
- [x] Zeus büyük taşları çok daha nadir vuruyor: her seviye ihtimali 0.55 ile çarpılıyor (64 ≈ 20 kat, 1024 ≈ 200 kat daha az).
- [x] Android geri tuşu: önce açık pencereyi kapatır, en son oyundan çıkar.
- [x] Kaldığın yerden devam: Uygulama kapansa da tahta, skor, iksirler ve Ares'in öfkesi kaydediliyor.
- [x] Büyük anlarda kısa titreşim (Zeus, Ares, kazanma, oyun sonu). Ses butonu titreşimi de kapatıyor.
- [x] Otomatik testler repoda (`tests/test_game.gd`, 91 kontrol). Testler export'a dahil edilmiyor.
- [x] Gizlilik politikası yayında: https://roketrig.github.io/2048-olympos/privacy
- [x] Geliştirici sitesi: https://roketrig.github.io

---

## 1. Oyun içi son işler

- [ ] **Telefonda test.** Debug APK'yı kurup oynayın ve notlarınızı alın:
  - Tanrıların ne sıklıkla geldiği
  - Sesler
  - Kaydırma hassasiyeti
  - Yazıların okunurluğu
  - Rehberin anlaşılır olup olmadığı
- [ ] **Oran ayarı.** Testten gelen geri bildirime göre olasılıkları ayarlayın:
  - `zeus.gd`: `strike_chance` 0.10, `chain_chance` 0.2, `big_tile_falloff` 0.55 (küçüldükçe büyük taşlar daha az vurulur)
  - `eros.gd`: `merge_chance` 0.065, `potion_chance` 0.06
  - `ares.gd`: `scream_chance` 0.055
  - `chaos.gd`: `max_hp` 3000, `halve_chance` 0.06, `split_chance` 0.045, `flood_chance` 0.04, huy için `MOOD_BOOST` 1.8 / `MOOD_DAMPEN` 0.6
  - `herald.gd`: `max_hp` 500, `halve_chance` 0.05, `flood_chance` 0.04
- [ ] **Boss savaşlarını deneyin.** Elçi'nin canının (500) ve Kaos'un canının (3000) savaşın ne kadar sürdüğüne uygun olup olmadığına bakın. Hızlı denemek için `main.gd` içindeki `BOSS_LEVEL` değerini geçici olarak 6 yapın; o zaman Kaos 128'de gelir (Elçi için `HERALD_LEVEL`; 5 yaparsanız 64'te gelir). Rehberleri yeniden görmek için uygulama verisini silin.
- [ ] Mağaza ekran görüntüleri ve öne çıkan görsel (1024×500). _(Claude üretebilir.)_

## 2. Release imza anahtarı (keystore)

- [x] Keystore'u oluşturun. Android Studio'yu açmanıza gerek yok; içindeki `keytool` aracını terminalden çalıştırıyoruz. Şifreyi kendiniz belirleyin, hiçbir yere yazmayın, repoya da koymayın. PowerShell'de:
  ```powershell
  & "C:\Program Files\Android\Android Studio\jbr\bin\keytool.exe" -genkeypair -v -keystore "$env:USERPROFILE\olympos2048-release.keystore" -alias olympos2048 -keyalg RSA -keysize 2048 -validity 10000
  ```
  Sorular: şifre (iki kez, yazarken görünmez), ad soyad, birim/kurum (boş geçilebilir), şehir, il, ülke kodu `TR`, en sonda onay için `yes`.
- [ ] Keystore dosyasının ve şifresinin **yedeğini** güvenli bir yere alın, örneğin bir şifre yöneticisine. Kaybederseniz güncelleme yükleyemezsiniz.
- [ ] **Release AAB'yi alın.** Şifre hiçbir yere kaydedilmez; betik sorar, build bitince unutur. Terminalde:
  ```powershell
  powershell -ExecutionPolicy Bypass -File "$env:USERPROFILE\OneDrive\Masaüstü\godot\tools\release.ps1"
  ```
  Sonunda yeşil `DONE` yazısı ve `Masaüstü\build\android\2048-olympos.aab` dosyası çıkar. Play Console'a yüklenecek dosya budur.
- [ ] Play Console'da **Play App Signing**'i açık bırakın (varsayılan). Bu durumda sizin anahtarınız "yükleme anahtarı" olur; kaybederseniz Google üzerinden sıfırlanabilir.

## 3. AdMob

- [ ] AdMob hesabı açın (Play Console ile aynı Google hesabı olabilir).
- [ ] **Ödeme ve vergi bilgileri:** Banka hesabınızı ve W-8BEN formunu (ABD dışındaki bireyler için) girin.
- [ ] İki uygulama ekleyin: 2048 Olympos (Android) ve 2048 Olympos (iOS).
- [ ] Her biri için üç reklam birimi oluşturun:
  - **Anchored adaptive banner**
  - **Interstitial**
  - **Rewarded**
- [ ] **Privacy & messaging:**
  - GDPR onay mesajını oluşturup yayınlayın.
  - iOS için IDFA açıklama mesajını oluşturun.
  - _Politika "oyun izin istiyor" dediği için bu adım şart._
- [ ] Kendi telefonunuzu **test cihazı** olarak ekleyin. Kendi canlı reklamlarınıza asla tıklamayın.

## 4. AdMob eklentisini oyuna bağlamak _(Claude yapabilir; sizin onayınız gerekir)_

- [ ] Godot 4.7 uyumlu bir AdMob eklentisi kurun (ayrıntılar `ADS.md` içinde).
- [ ] `scripts/admob_backend.gd` dosyasını yazıp `ads.gd` içindeki `_find_backend()` fonksiyonuna bağlayın.
- [ ] Test ID'lerini kendi ID'lerinizle değiştirin:
  - `Ads.IDS`
  - iOS için `export_presets.cfg` içindeki `GADApplicationIdentifier`
  - Android uygulama ID'si (eklenti ayarlarında)
- [ ] iOS için Google'ın güncel SKAdNetwork listesini `export_presets.cfg` dosyasına ekleyin.
- [ ] Telefonda test edin: banner'lar, interstitial, ödüllü reklamlar ve onay formu.

## 5. app-ads.txt

- [ ] AdMob'un verdiği satırı `roketrig.github.io` reposunun köküne `app-ads.txt` adıyla koyun. Bu tek dosya bütün oyunlarınızı kapsar.
- [ ] Mağaza sayfalarında "Website" olarak `https://roketrig.github.io` yazın.

## 6. Google Play

- [x] Play Console'da kimlik doğrulamasını tamamlayın.
- [ ] Uygulamayı oluşturun. Paket adı `com.bugrakasarci.olympos2048`; yayından sonra değiştirilemez.
- [ ] **Mağaza sayfası** için gerekenler:
  - **Ad:** 2048 Olympos
  - **Kısa açıklama:** en fazla 80 karakter
  - **Uzun açıklama:** en fazla 4000 karakter
  - **İkon:** 512×512 _(icon.png'den üretilebilir)_
  - **Öne çıkan görsel:** 1024×500 _(Claude üretebilir)_
  - **Ekran görüntüleri:** telefon için en az 2 adet
- [ ] **Uygulama içeriği** formları:
  - **Gizlilik politikası URL'si:** https://roketrig.github.io/2048-olympos/privacy
  - **Reklam içeriyor:** Evet
  - **Hedef kitle:** 13+ _(çocuklar seçilmemeli)_
  - **İçerik derecelendirmesi (IARC):** Kumar sorusuna **Hayır**; gerçek para ve bahis yok.
  - **Data safety:** AdMob üzerinden toplanan veriler (reklam kimliği, yaklaşık konum, uygulama etkileşimleri). Uygulama kendisi veri toplamıyor.
- [ ] **Kapalı test (yeni kişisel hesaplar için zorunlu):**
  - En az **12 test kullanıcısı**, **14 gün kesintisiz** katılmalı.
  - Sayı 12'nin altına düşerse süre baştan başlayabilir; bir iki yedek kişi bulun.
- [ ] Test süresince gelen geri bildirimlere göre düzeltmeleri yapın.
- [ ] Production erişimine başvurun. Her yeni sürümde `version/code` değerini artırarak imzalı bir release AAB yükleyin.

## 7. iOS / App Store _(Android yayına çıktıktan sonra)_

- [ ] Mac ve Xcode hazırlayın.
- [x] Apple Developer Program'a kaydolun (yılda 99$, bireysel hesap).
- [ ] Mac'teki Godot'ya tam export şablonlarını indirin.
- [ ] `export_presets.cfg` dosyasına `app_store_team_id` değerini girin.
- [ ] Xcode projesini export edin, imzalayın ve TestFlight'a yükleyin.
- [ ] App Store Connect'te şunları hazırlayın:
  - Uygulama sayfası
  - Ekran görüntüleri (6.7" ve 6.5" boyutlarında)
  - **App Privacy** etiketleri
  - Yaş derecelendirmesi
  - Gizlilik politikası URL'si
- [ ] App Review'a gönderin.

## 8. Vergi ve resmi işler

- [ ] İlk ödeme gelmeden önce bir **mali müşavire** danışın. Sorulacaklar:
  - GVK Mükerrer 20/B istisnası
  - AdMob reklam gelirinin bu istisnaya girip girmediği
  - Özel banka hesabı
  - Yıllık sınır
- [ ] Oyun için ayrı bir e-posta adresi düşünün (isteğe bağlı). Şu an Play Console e-postanız herkese açık görünüyor.

---

## Bilinmesi gerekenler

- **Kod:** https://github.com/roketrig/2048-Olympos
  - Yerel klasör: `Masaüstü\godot`
  - Eski Unity sürümü: `Masaüstü\2048`. Oradaki `2048\godot` kopyası artık kullanılmıyor, silinebilir.
- **Test APK'sı:** `Masaüstü\build\android\2048-olympos-debug.apk`. Bu klasör OneDrive'da olduğu için telefondan OneDrive uygulamasıyla indirilebilir.
- **Testler:** `Godot --path . -s tests/test_game.gd` komutuyla çalışır ve sonuçları PASS/FAIL satırları olarak yazar. Kendi kayıt dosyalarınız test sırasında kenara alınır, sonra geri konur.
- **Ayrıntılı belgeler:** Reklamlar için `ADS.md`, gizlilik politikası için `PRIVACY.md`.
