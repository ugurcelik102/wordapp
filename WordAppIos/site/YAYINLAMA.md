# Geliştirici sitesini yayınlama (GitHub Pages) + app-ads.txt

AdMob doğrulaması, App Store listendeki geliştirici sitesinin **kök dizininde**
`app-ads.txt` dosyasını arar. Bu klasör tam olarak o siteyi içeriyor.

Önemli: GitHub Pages'te **kullanıcı sitesi** gerekiyor
(`https://ugurcelik102.github.io/app-ads.txt`).
Proje sitesi (`.../WordAppIos/app-ads.txt`) kök sayılmaz, AdMob kabul etmez.

## 1. app-ads.txt içeriğini doldur

`app-ads.txt` şu an şablon:

```
google.com, pub-XXXXXXXXXXXXXXXX, DIRECT, f08c47fec0942fa0
```

AdMob → Uygulamalar → app-ads.txt talimatları ekranında sana **birebir** bu satır
gösteriliyor; oradaki `pub-...` numarasını kopyalayıp `XXXXXXXXXXXXXXXX` yerine yaz.
Satırın sonundaki `f08c47fec0942fa0` Google'ın sabit kimliğidir, değişmez.

## 2. GitHub'da kullanıcı sitesi deposu aç

GitHub → New repository → depo adı **tam olarak**:

```
ugurcelik102.github.io
```

Public olmalı, README ekleme.

## 3. Bu klasörü depoya gönder

```
cd ~/Projeler/WordAppIos/site
git init
git add .
git commit -m "Vocabee tanıtım sitesi + app-ads.txt"
git branch -M main
git remote add origin https://github.com/ugurcelik102/ugurcelik102.github.io.git
git push -u origin main
```

Birkaç dakika içinde yayına girer:

- https://ugurcelik102.github.io
- https://ugurcelik102.github.io/app-ads.txt
- https://ugurcelik102.github.io/gizlilik.html

Tarayıcıda `app-ads.txt` adresini açıp içeriği düz metin olarak gördüğünden emin ol.

## 4. App Store Connect'te siteyi tanıt

App Store Connect → Vocabee → Uygulama Bilgileri / Sürüm bilgileri:

- **Marketing URL / Pazarlama URL'si**: `https://ugurcelik102.github.io`
- **Support URL / Destek URL'si**: `https://ugurcelik102.github.io`
- **Privacy Policy URL**: `https://ugurcelik102.github.io/gizlilik.html`

AdMob bu alandaki adrese bakarak dosyayı arar; adres eşleşmezse doğrulama yine başarısız olur.

## 5. AdMob'da doğrulamayı tetikle

AdMob → uygulama → "Güncellemeleri kontrol edin". Google'ın taraması bazen
24 saate kadar sürebilir; hemen olmazsa ertesi gün tekrar bak.

## Sık yapılan hatalar

- Proje sitesi kullanmak (`/WordAppIos/app-ads.txt`) → kök değil, geçersiz.
- Dosyayı `.txt` yerine HTML olarak yayınlamak.
- App Store'daki site adresiyle dosyanın bulunduğu alan adının farklı olması.
- `pub-` numarasını yanlış kopyalamak (AdMob yayıncı kimliği, uygulama ID'si değil).
