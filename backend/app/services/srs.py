"""
SM-2 Spaced Repetition algoritması.
Her egzersiz sonucunda çağrılır ve bir sonraki tekrar tarihini hesaplar.

Referans: https://www.supermemo.com/en/archives1990-2015/english/ol/sm2
"""
from datetime import date, timedelta
from math import ceil


def update_srs(
    ease_factor: float,
    interval_days: int,
    repetitions: int,
    is_correct: bool,
    quality: int | None = None,  # 0-5 arası; None ise is_correct'ten türetilir
) -> tuple[float, int, int, date]:
    """
    SM-2 hesaplaması.

    Returns:
        (new_ease_factor, new_interval_days, new_repetitions, next_review_date)
    """
    if quality is None:
        quality = 4 if is_correct else 1  # doğru → iyi, yanlış → çok kötü

    if quality < 3:
        # Yanlış cevap: sıfırdan başla
        new_repetitions = 0
        new_interval = 1
    else:
        # Doğru cevap: SM-2 formülü
        if repetitions == 0:
            new_interval = 1
        elif repetitions == 1:
            new_interval = 6
        else:
            new_interval = ceil(interval_days * ease_factor)
        new_repetitions = repetitions + 1

    # Ease factor güncelle (minimum 1.3)
    new_ease = max(1.3, ease_factor + 0.1 - (5 - quality) * (0.08 + (5 - quality) * 0.02))

    next_date = date.today() + timedelta(days=new_interval)

    return new_ease, new_interval, new_repetitions, next_date


def get_new_status(repetitions: int, interval_days: int) -> str:
    """Tekrar sayısına göre kelime durumunu belirler.

    DİKKAT: Bu fonksiyon yalnızca kullanıcı bir cevap verdikten SONRA
    çağrılır; yani kelime artık "hiç çalışılmamış" değildir. Bu yüzden asla
    "new" dönmez. "new" durumu sadece kelime kaydı ilk oluşturulurken
    (henüz hiç çalışılmamışken) atanır.

    Yanlış cevapta SM-2 repetitions'ı 0'a sıfırlar; bu durumda kelime
    "new" değil, yeniden öğrenilen ("learning") bir kelimedir ve tekrar
    havuzunda KALMALIDIR. Önceki "repetitions == 0 -> new" mantığı,
    yanlış cevaplanan her kelimeyi tekrar havuzundan da yeni-kelime
    havuzundan da düşürerek "kelime tekrarı"nı bozuyordu.
    """
    if repetitions < 3:
        return "learning"
    elif interval_days < 21:
        return "review"
    else:
        return "mastered"
