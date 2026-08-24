# Ödüllü Reklam — AdMob Entegrasyonu

Gerçek AdMob ödüllü reklamları entegre edildi. Sahte reklam ekranı kaldırıldı.

## Kimlikler

- Uygulama kimliği: `ca-app-pub-5049340562241701~8159764413`
- Ödüllü reklam birimi: `ca-app-pub-5049340562241701/2177355163`
- Geliştirme (DEBUG): Google'ın test birimi `ca-app-pub-3940256099942544/1712485313`

`AdConfig.swift` DEBUG'da test, RELEASE'de gerçek birimi kullanır. Gerçek birimle
test etmek (kendi reklamına bakmak/tıklamak) politika ihlalidir.

## Yapı

- `Core/Ads/AdConfig.swift` — reklam kimlikleri.
- `Core/Ads/RewardedAdManager.swift`
  - `AdGatedFeature`: reklamla açılan özellikler (`reading`, `exam`).
  - SDK başlatma (`start()`), önden yükleme (`preload()`), gösterim (`run(...)`).
  - "Bugün açık" kaydı UserDefaults'ta, kullanıcı + özellik + tarih bazlı.
  - `FullScreenContentDelegate`: reklam kapanınca ödül verilir; yarıda kapatılırsa verilmez.
- `Info.plist` — `GADApplicationIdentifier` + `SKAdNetworkItems` (50 kimlik).
- `WordAppIosApp.init()` — açılışta `RewardedAdManager.shared.start()`.

## Davranış

- Sıklık: **günde bir kez**. Reklam izlenince o özellik gün boyu açık.
- **Reklam yüklenemezse özellik yine açılır.** Envanter yokluğu, ağ hatası veya
  hesabın henüz onaylanmamış olması kullanıcıyı özellikten mahrum bırakmamalı.
- Kilit kaydı cihazda tutulur; kullanıcı uygulamayı silip kurarsa sıfırlanır.
  Bu yeterli değilse kilit backend'e taşınabilir (günlük görevlerdeki gibi).

## Kurulum (yeni bir makinede)

Xcode → File > Add Package Dependencies →
`https://github.com/googleads/swift-package-manager-google-mobile-ads.git`
(Up to Next Major Version)

## Notlar

- AdMob'da uygulama doğrulaması `app-ads.txt` üzerinden yapılır; App Store
  kaydındaki Marketing URL `https://ugurcelik102.github.io` olmalıdır.
- Hesap onayı ("İnceleme gerekli") tamamlanana kadar gerçek reklam dolmayabilir.
- ATT izni istenecekse `NSUserTrackingUsageDescription` ve UMP SDK eklenmelidir;
  şu an istenmiyor.
