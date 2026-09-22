# Deploy B Planı — Railway CLI ile Manuel Deploy

İlgili: AYD-512 — Railway'in GitHub App entegrasyonu 17.08.2026'da hata verip
otomatik deploy'u durdurmuştu. Bu doküman, aynı durumda GitHub'a hiç
bağımlı olmadan backend'i elden deploy etmek için izlenecek adımları anlatır.

## Ne zaman kullanılır

- `main` branch'ine push yapıldığı halde Railway'de yeni deployment
  tetiklenmiyorsa (Railway dashboard → Deployments sekmesinde hareket yoksa).
- Railway'in GitHub App'i "reconnect" istiyorsa veya webhook hatası
  veriyorsa ve hemen deploy çıkmak gerekiyorsa.

## Ön koşul (tek seferlik, bu makinede tamamlandı — 2026-09-22)

```bash
brew install railway   # railway CLI kurulu değilse
railway login          # ugurcelik102 hesabıyla giriş
cd /Users/ugur_celik/Projeler/wordapp
railway link \
  --project 6e7bd0a7-f5ce-45f8-92d4-eda7d186a920 \
  --environment 2e3b590e-3613-440a-ab3c-6b1390bed0b1 \
  --service 9e21b863-6af4-4833-9f0d-0d64acca19bf
```

Bu adım sadece bu dizini Railway projesine (`bountiful-spirit` →
`production` → `wordapp` servisi) bağlar, herhangi bir deploy tetiklemez.
Link bilgisi bu makinede `~/.railway/config.json` içinde tutulur — başka
bir makineden fallback deploy yapılacaksa `railway link` orada da bir kez
çalıştırılmalı.

## Acil durumda deploy adımları

1. Deploy edilecek kodu güncelle:
   ```bash
   cd /Users/ugur_celik/Projeler/wordapp
   git checkout main
   git pull origin main
   ```
2. Servisin kök dizini `backend/` olduğu için (Dockerfile orada), oraya geçip
   CLI ile doğrudan upload+deploy yap:
   ```bash
   cd backend
   railway up --service wordapp --environment production \
     -m "manual fallback deploy - GitHub entegrasyon hatası"
   ```
   Bu komut GitHub'ı hiç kullanmaz; dizini paketleyip doğrudan Railway'e
   yükler ve build/deploy sürecini başlatır. Terminalde build/deploy
   loglarını canlı gösterir (arka plana almak için `-d`/`--detach`
   eklenebilir).
3. Deploy'u doğrula:
   ```bash
   railway status
   railway logs --lines 100
   curl -sf https://wordapp-production-bf22.up.railway.app/ -o /dev/null && echo OK
   ```

## GitHub entegrasyonu düzeldikten sonra

Manuel `railway up` ile deploy etmek, servisin GitHub App bağlantısını
bozmaz. Entegrasyon düzelince `main`'e yapılan bir sonraki push otomatik
deploy'u yine tetikler; ekstra bir işlem gerekmez.

Eğer Railway servisin kaynağını tamamen GitHub'a yeniden bağlamak/
doğrulamak gerekirse:
```bash
railway service source connect --repo ugurcelik102/wordapp --branch main --service wordapp
```

## Notlar

- `railway up`, `.gitignore`'daki dosyaları otomatik hariç tutar
  (`--no-gitignore` ile devre dışı bırakılabilir).
- Environment değişkenleri (DATABASE_URL, SMTP_*, ANTHROPIC_API_KEY vb.)
  Railway servisinde zaten tanımlı olduğundan CLI deploy'unda tekrar
  girilmesine gerek yoktur.
- Bu yöntem production'a gerçek bir deploy yapar — sadece gerçekten
  otomatik deploy çalışmıyorsa kullanılmalıdır.
