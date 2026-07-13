from pydantic import BaseModel


class SentenceExerciseSchema(BaseModel):
    type: str                                  # "order" | "blank"
    word: str                                  # hedef İngilizce kelime
    word_id: str | None = None
    prompt: str                                # gösterilen cümle (yöne göre en/tr)
    prompt_lang: str = "en"                    # gösterilen cümlenin dili: "en" | "tr"
    english: str                               # tam İngilizce cümle
    turkish: str                               # tam Türkçe çeviri
    answer_tokens: list[str] | None = None     # order: doğru sıralama
    chips: list[str] | None = None             # order: karışık kelime çipleri
    options: list[str] | None = None           # blank: 4 İngilizce seçenek
    blank_english: str | None = None           # blank: ____ içeren İngilizce cümle


class SentenceExercisesResponse(BaseModel):
    count: int
    exercises: list[SentenceExerciseSchema]
