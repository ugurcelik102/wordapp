# Vocabee — Ekran Görüntüsü ve Submission Rehberi

## 1. Gerekli Ekran Görüntüsü Boyutları

App Store Connect, en az şu setleri ister (App Icon zaten 1024x1024 hazır):

| Cihaz | Çözünürlük | Zorunlu mu |
|---|---|---|
| 6.9" (iPhone 16 Pro Max vb.) | 1320 x 2868 | Evet |
| 6.5" (iPhone 11 Pro Max / XS Max) | 1284 x 2778 veya 1242 x 2688 | Genelde otomatik türetilir, yine de önerilir |
| iPad Pro 13" (varsa iPad desteği) | 2064 x 2752 | Uygulama iPad'i destekliyorsa evet |

Her cihaz boyutu için en az 1, en fazla 10 ekran görüntüsü yüklenebilir. En az 3-5 tane, uygulamanın ana özelliklerini gösteren ekran önerilir (Ana ekran, Öğrenme akışı, Okuma, İlerleme).

## 2. Ekran Görüntüsü Nasıl Alınır

1. Xcode'da projeyi aç, üstteki cihaz seçiciden **iPhone 16 Pro Max** simülatörünü seç.
2. Uygulamayı çalıştır (▶).
3. İstediğin ekrana git, simülatör menüsünden **Device > Screenshot** veya **Cmd+S**.
4. Görseller varsayılan olarak masaüstüne kaydedilir.
5. Aynı işlemi iPad simülatörüyle de tekrarla (iPad desteği varsa).

İstersen bu adımı birlikte, ekran paylaşımı üzerinden (computer-use) yürütebilirim — Xcode'u açman yeterli.

## 3. Xcode'da Arşivleme (Archive)

1. Üstteki cihaz seçiciden **Any iOS Device (arm64)** seç (simülatör değil).
2. **Product > Archive** menüsünden arşiv oluştur.
3. Archive tamamlanınca açılan Organizer penceresinde **Distribute App** tıkla.
4. **App Store Connect > Upload** seçeneklerini takip et, imzalama otomatikse (Automatic) devam et.

## 4. App Store Connect'te Kayıt

1. https://appstoreconnect.apple.com adresine giriş yap.
2. **My Apps > +  > New App**.
3. Bundle ID olarak `com.ugurcelik102.vocabee` seç (proje ile eşleşmeli).
4. Uygulama adı: **Vocabee**, birincil dil: Türkçe.
5. **App Information** sekmesinde kategori, gizlilik politikası URL'sini gir (bkz. `gizlilik_politikasi.md`).
6. **Pricing and Availability** belirle.
7. **App Privacy** sekmesinde `appstore_metadata.md` içindeki veri toplama beyanını işaretle.
8. **Prepare for Submission**: açıklama, anahtar kelimeler, promosyon metni (`appstore_metadata.md`'den), ekran görüntülerini yükle.
9. Xcode'dan yüklediğin build'i seç.
10. **Submit for Review**.

## 5. Sık Görülen Red Sebepleri (Kontrol Et)

- Gizlilik politikası linki çalışmıyor / eksik → mutlaka canlı bir URL olmalı.
- Demo hesap istenirse (giriş gerektiren uygulamalarda) App Review notlarına test kullanıcı bilgisi ekle.
- Boş/placeholder ekran görüntüsü kullanma.
- "Sign in with Apple" sunmuyorsan ve sadece e-posta/şifre girişi varsa, Apple bazen üçüncü taraf girişler (Google vb.) sunuluyorsa Sign in with Apple'ı da zorunlu kılar — Vocabee sadece e-posta/şifre kullandığı için bu genelde sorun değildir.

## 6. Doldurman Gerekenler

- Destek URL'si (support URL)
- Gizlilik politikası için canlı bir link (metni `gizlilik_politikasi.md` içinde hazır, yayınlaman gerekiyor)
- App Review notlarında test için örnek kullanıcı adı/şifre (varsa)
