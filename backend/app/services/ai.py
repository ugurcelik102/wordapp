"""
Durumsuz (stateless) yapay zekâ üretimi: okuma parçası, deneme sınavı,
cümle içinde kullanım alıştırmaları ve kelime örnek cümleleri.

Veritabanı YOKTUR. Üretim için gereken her şeyi (seviye + hedef kelimeler)
istemci gönderir; sunucu yalnızca Claude'a giden ince bir aracıdır.
Anthropic anahtarı istemciye gömülemeyeceği için bu katman sunucuda kalır.
"""
import json
import random
import re

import anthropic
from starlette.concurrency import run_in_threadpool

from app.core.config import settings
from app.schemas.ai import AIWord

MODEL_NAME = "claude-haiku-4-5-20251001"

# CEFR seviyeleri statik veridir; DB'den okumaya gerek yok.
LEVEL_NAMES: dict[str, str] = {
    "A1": "Beginner",
    "A2": "Elementary",
    "B1": "Intermediate",
    "B2": "Upper-Intermediate",
    "C1": "Advanced",
    "C2": "Mastery",
}

# Seviyeye özel pedagojik yönergeler (CEFR)
_LEVEL_GUIDANCE = {
    "A1": "Use very short, simple sentences (about 6-8 words). Only present simple tense. Only the most common everyday words. No relative or subordinate clauses.",
    "A2": "Use short, simple sentences (about 8-10 words). Present and past simple and 'going to' future. Common connectors (and, but, because, so). Everyday high-frequency vocabulary.",
    "B1": "Use clear sentences of moderate length (up to ~15 words). Present, past and future, and present perfect. Simple relative clauses (who, which, that) and common phrasal verbs. Familiar everyday topics.",
    "B2": "Use varied sentences with some complexity. All common tenses, conditionals, passive voice, and subordinate clauses. Some idiomatic and topic-specific vocabulary.",
    "C1": "Use complex, well-structured sentences with advanced grammar, nuanced and less common vocabulary, and clear cohesive devices.",
    "C2": "Use sophisticated, near-native language: complex structures, precise and idiomatic vocabulary, and subtle nuance.",
}

# Seviyeye göre ortalama cümle uzunluğu üst sınırı (okunabilirlik kontrolü için)
_LEVEL_MAX_SENTENCE_LEN = {"A1": 9, "A2": 12, "B1": 16, "B2": 22, "C1": 30, "C2": 40}


def _level_name(code: str) -> str:
    return LEVEL_NAMES.get(code, LEVEL_NAMES["B1"])


def _level_guidance(code: str) -> str:
    return _LEVEL_GUIDANCE.get(code, _LEVEL_GUIDANCE["B1"])


def _message_text(message) -> str:
    """Yanıttaki metin bloklarını birleştirir.

    DİKKAT: content[0] her zaman metin DEĞİLDİR — bazı modeller önce bir
    "thinking" bloğu döndürür ve o bloğun .text alanı None'dır. Doğrudan
    content[0].text almak bu modellerde AttributeError verir.
    """
    parts = [
        b.text for b in message.content
        if getattr(b, "type", None) == "text" and getattr(b, "text", None)
    ]
    return "".join(parts).strip()


def _ask_claude(prompt: str, max_tokens: int) -> str:
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    message = client.messages.create(
        model=MODEL_NAME,
        max_tokens=max_tokens,
        messages=[{"role": "user", "content": prompt}],
    )
    return _message_text(message)


def _extract_json(raw: str, opener: str, closer: str):
    start, end = raw.find(opener), raw.rfind(closer)
    if start == -1 or end == -1:
        return None
    try:
        return json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return None


# --------------------------------------------------------------------- Okuma


def _avg_sentence_length(text: str) -> float:
    sentences = [s for s in re.split(r"[.!?]+", text) if s.strip()]
    words = [w for w in text.split() if w.strip()]
    if not sentences:
        return float(len(words))
    return len(words) / len(sentences)


def _output_format_instruction() -> str:
    return (
        "\n\nRespond ONLY as JSON (no markdown, no extra text) in exactly this shape:\n"
        "{\n"
        '  "passage": "the reading text; keep line breaks for dialogue lines",\n'
        '  "glossary": [ {"word": "<a harder English word or phrase from the passage>", "tr": "<short simple Turkish meaning>"} ]\n'
        "}\n"
        "The glossary must contain 5-8 of the more difficult words or phrases from the passage "
        "at this level, each with a short, simple Turkish meaning."
    )


def _parse_reading_json(raw: str) -> tuple[str, list[dict]]:
    data = _extract_json(raw, "{", "}")
    if not isinstance(data, dict):
        return raw.strip(), []
    passage = str(data.get("passage", "")).strip() or raw.strip()
    glossary: list[dict] = []
    for item in (data.get("glossary") or []):
        if isinstance(item, dict):
            w = str(item.get("word", "")).strip()
            tr = str(item.get("tr", "")).strip()
            if w and tr:
                glossary.append({"word": w, "tr": tr})
    return passage, glossary


def _build_word_prompt(level_code: str, words: list[AIWord]) -> str:
    word_list = "\n".join(
        f"- {w.word} ({w.part_of_speech or 'word'}): {w.definition}" for w in words
    )
    return f"""You are an English language teacher creating a reading passage for a student at {level_code} ({_level_name(level_code)}) level.

Create a short, engaging reading passage (150-200 words) that naturally uses ALL of the following words:

{word_list}

Level guidance for {level_code}: {_level_guidance(level_code)}

Requirements:
- The passage must be appropriate for {level_code} level English learners
- Each target word must appear at least once, used naturally in context
- The story should be coherent and interesting (a short story, anecdote, or descriptive piece)
- Do NOT bold or highlight the target words
{_output_format_instruction()}"""


def _build_topic_prompt(level_code: str, topic: str, as_dialogue: bool) -> str:
    if as_dialogue:
        form = (
            "Write it as a natural, realistic back-and-forth DIALOGUE between two people. "
            "Label the speakers (for example 'A:' and 'B:'), with 6-10 short exchanges."
        )
    else:
        form = "Write it as a short, engaging passage of 120-180 words."
    return f"""You are an English teacher creating reading material for a {level_code} ({_level_name(level_code)}) level learner.

Topic / scenario: {topic}

{form}

Level guidance for {level_code}: {_level_guidance(level_code)}

Requirements:
- Use simple, clear language appropriate for {level_code} level English learners.
- Make it realistic and useful for real everyday situations.
{_output_format_instruction()}"""


def _generate_reading_sync(prompt: str, level_code: str, max_tokens: int) -> tuple[str, list[dict]]:
    """Metni + mini sözlükçeyi üretir; cümleler seviyeye göre fazla uzunsa bir kez sadeleştirir."""
    passage, glossary = _parse_reading_json(_ask_claude(prompt, max_tokens))
    max_len = _LEVEL_MAX_SENTENCE_LEN.get(level_code, 16)
    if _avg_sentence_length(passage) > max_len * 1.4:
        simpler = prompt + (
            f"\n\nIMPORTANT: Your previous version was too hard for this level. "
            f"Rewrite with SHORTER, SIMPLER sentences (under {max_len} words each), "
            f"returning the SAME JSON shape."
        )
        passage, glossary = _parse_reading_json(_ask_claude(simpler, max_tokens))
    return passage, glossary


async def generate_reading(
    level_code: str,
    words: list[AIWord],
    topic: str | None = None,
    as_dialogue: bool = False,
) -> dict:
    """Konu verildiyse konu bazlı, aksi halde hedef kelimelerden parça üretir."""
    if topic:
        prompt = _build_topic_prompt(level_code, topic, as_dialogue)
        max_tokens = 700
    else:
        prompt = _build_word_prompt(level_code, words)
        max_tokens = 500

    content, glossary = await run_in_threadpool(
        _generate_reading_sync, prompt, level_code, max_tokens
    )
    return {
        "content": content,
        "word_count": len(content.split()),
        "target_word_texts": [] if topic else [w.word for w in words],
        "model_used": MODEL_NAME,
        "glossary": glossary,
    }


# --------------------------------------------------------------------- Sınav


def _build_exam_prompt(level_code: str, count: int) -> str:
    return f"""You are creating an English level test for a {level_code} ({_level_name(level_code)}) level learner.

Create {count} multiple-choice questions, MIXED between VOCABULARY and GRAMMAR, all suitable for {level_code} level.
- Vocabulary: choose the correct word to complete a sentence, or the word closest in meaning.
- Grammar: choose the correct verb form/tense, preposition, article, or structure to complete a sentence.

Rules:
- Each question has EXACTLY 4 options, with exactly one correct.
- Keep difficulty appropriate for {level_code}.
- The question and options are in English; the explanation is a SHORT Turkish sentence.

Respond ONLY as a JSON array (no markdown, no extra text). Each item:
{{
  "type": "vocab" | "grammar",
  "question": "a sentence with a blank ____ or a short prompt",
  "options": ["option A", "option B", "option C", "option D"],
  "answer": "the exact text of the correct option",
  "explanation": "kısa Türkçe açıklama"
}}"""


def _generate_exam_sync(level_code: str, count: int) -> list[dict]:
    raw = _ask_claude(_build_exam_prompt(level_code, count), max_tokens=4000)
    return _extract_json(raw, "[", "]") or []


async def generate_exam(level_code: str, count: int = 20) -> list[dict]:
    try:
        raw_items = await run_in_threadpool(_generate_exam_sync, level_code, count)
    except Exception:
        return []

    questions: list[dict] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        q = str(item.get("question", "")).strip()
        options = [str(o).strip() for o in item.get("options", []) if str(o).strip()]
        answer = str(item.get("answer", "")).strip()
        if not q or len(options) < 2 or answer not in options:
            continue
        options = options[:4]
        random.shuffle(options)
        qtype = item.get("type") if item.get("type") in ("vocab", "grammar") else "vocab"
        questions.append({
            "type": qtype,
            "question": q,
            "options": options,
            "answer": answer,
            "explanation": (str(item.get("explanation", "")).strip() or None),
        })
    return questions


# ------------------------------------------------------- Cümle içinde kullanım


def _tokenize(sentence: str) -> list[str]:
    """Cümleyi çipler için kelimelere böler; cümle sonu ve kenar noktalamayı atar."""
    cleaned = sentence.strip().rstrip("?.!")
    toks = [t.strip('.,!?;:"\'') for t in cleaned.split()]
    return [t for t in toks if t]


def _build_sentence_prompt(words: list[AIWord]) -> str:
    listing = "\n".join(f'- {w.word} ({w.definition_tr or w.definition})' for w in words)
    return f"""You create English practice exercises for a Turkish speaker learning English.
For EACH target word below, create ONE exercise. Randomly pick its "type": "order" or "blank".

Target words:
{listing}

For each word output a JSON object with:
- "word": the exact target English word (as given above)
- "type": "order" or "blank"
- "english": a short, natural English sentence (6-10 words) that uses the target word exactly once
- "turkish": the correct, natural Turkish translation of that sentence
- "distractors_en": for "blank" -> 3 plausible WRONG English words similar to the target; for "order" -> 2 extra English distractor words NOT in the sentence
- "distractors_tr": for "order" -> 2 extra Turkish distractor words that are NOT in the sentence

Rules:
- For "blank", the target word MUST appear in "english" exactly once.
- Keep the language simple and learner-friendly.
- Respond with ONLY a JSON array (no markdown fences, no extra text)."""


def _generate_sentences_sync(words: list[AIWord]) -> list[dict]:
    raw = _ask_claude(_build_sentence_prompt(words), max_tokens=2500)
    return _extract_json(raw, "[", "]") or []


async def generate_sentence_exercises(words: list[AIWord]) -> list[dict]:
    by_text = {w.word.lower(): w for w in words}
    try:
        raw_items = await run_in_threadpool(_generate_sentences_sync, words)
    except Exception:
        return []

    exercises: list[dict] = []
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        word_text = str(item.get("word", "")).strip()
        etype = item.get("type")
        english = str(item.get("english", "")).strip()
        turkish = str(item.get("turkish", "")).strip()
        if not word_text or not english or not turkish:
            continue

        src = by_text.get(word_text.lower())
        word_id = src.id if src else None

        if etype == "order":
            # Türkçe cümle gösterilir, İngilizce kelime çipleriyle çeviri kurulur.
            dist_en = [str(d).strip() for d in item.get("distractors_en", []) if str(d).strip()][:2]
            tokens = _tokenize(english)
            if len(tokens) < 2:
                continue
            chips = tokens + dist_en
            random.shuffle(chips)
            exercises.append({
                "type": "order",
                "word": word_text,
                "word_id": word_id,
                "prompt": turkish,
                "prompt_lang": "tr",
                "english": english,
                "turkish": turkish,
                "answer_tokens": tokens,
                "chips": chips,
                "options": None,
                "blank_english": None,
            })

        elif etype == "blank":
            distractors = [str(d).strip() for d in item.get("distractors_en", []) if str(d).strip()][:3]
            if not distractors:
                continue
            pattern = re.compile(r'\b' + re.escape(word_text) + r'\b', re.IGNORECASE)
            blank_english, n = pattern.subn("____", english, count=1)
            if n == 0:
                continue
            options = distractors + [word_text]
            random.shuffle(options)
            exercises.append({
                "type": "blank",
                "word": word_text,
                "word_id": word_id,
                "prompt": turkish,
                "prompt_lang": "tr",
                "english": english,
                "turkish": turkish,
                "answer_tokens": None,
                "chips": None,
                "options": options,
                "blank_english": blank_english,
            })

    random.shuffle(exercises)
    return exercises


# ------------------------------------------------------------ Örnek cümleler


def _build_examples_prompt(level_code: str, words: list[AIWord]) -> str:
    listing = "\n".join(
        f"- {w.word} ({w.part_of_speech or 'word'}): {w.definition}" for w in words
    )
    return f"""You write example sentences for a Turkish speaker learning English at {level_code} ({_level_name(level_code)}) level.

For EACH word below, create ONE short, natural English example sentence that uses the word
in the given meaning, then give its natural Turkish translation.

Words:
{listing}

Level guidance for {level_code}: {_level_guidance(level_code)}

Respond with ONLY a JSON array (no markdown fences, no extra text). Each item:
{{"word": "<the exact word as given above>", "sentence": "...", "translation": "..."}}"""


def _generate_examples_sync(level_code: str, words: list[AIWord]) -> list[dict]:
    raw = _ask_claude(_build_examples_prompt(level_code, words), max_tokens=1500)
    return _extract_json(raw, "[", "]") or []


async def generate_examples(level_code: str, words: list[AIWord]) -> list[dict]:
    """Kelime başına bir örnek cümle + Türkçe çeviri. Kelime havuzundaki çoğu
    kayıtta örnek olmadığı için istemci bunu bir kez isteyip cihazda saklar."""
    by_text = {w.word.lower(): w for w in words}
    try:
        raw_items = await run_in_threadpool(_generate_examples_sync, level_code, words)
    except Exception:
        return []

    examples: list[dict] = []
    seen: set[str] = set()
    for item in raw_items:
        if not isinstance(item, dict):
            continue
        word_text = str(item.get("word", "")).strip()
        sentence = str(item.get("sentence", "")).strip()
        src = by_text.get(word_text.lower())
        # Model listede olmayan bir kelime uydurursa ya da tekrar ederse alma.
        if not src or not sentence or src.word.lower() in seen:
            continue
        seen.add(src.word.lower())
        examples.append({
            "word_id": src.id,
            "word": src.word,
            "sentence": sentence,
            "translation": str(item.get("translation", "")).strip() or None,
        })
    return examples
