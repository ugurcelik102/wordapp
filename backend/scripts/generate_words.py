"""
Kelime havuzunu LLM ile genişletir (hedef: toplam ~2000 kelime).

Ne yapar:
  - Veritabanındaki mevcut kelimeleri okur (tekrar üretmemek için).
  - Her CEFR seviyesi için eksik sayıyı hesaplar, tür (part-of-speech) kotalarına
    göre partiler hâlinde Claude'dan kelime + tanım + Türkçe + IPA ister.
  - Gelenleri doğrular, tekilleştirir ve `words` tablosuna yazar.
  - İstenirse her kelime için 3 adet MCQ çeldiricisi de üretir (--distractors).

Kullanım (backend/ dizininde, venv aktifken):

    # Yerel veritabanı (docker-compose):
    ANTHROPIC_API_KEY=sk-ant-... \
    DB_URL="postgresql://wordapp_user:wordapp_pass@localhost:5432/wordapp" \
    python scripts/generate_words.py --target 2000

    # Railway (canlı):
    ANTHROPIC_API_KEY=sk-ant-... \
    DB_URL="postgresql://...railway..." \
    python scripts/generate_words.py --target 2000

Faydalı seçenekler:
    --target 2000        Toplam hedef kelime sayısı (varsayılan 2000)
    --batch 25           Tek istekte kaç kelime isteneceği (varsayılan 25)
    --dry-run            Veritabanına yazmadan sadece üretip gösterir
    --distractors        Yeni kelimeler için 3'er çeldirici de üretir
    --model ...          Varsayılan: claude-sonnet-4-5 (kalite için)

Script kesilirse tekrar çalıştırmak güvenlidir: mevcut kelimeler atlanır.
"""

from __future__ import annotations

import argparse
import asyncio
import json
import os
import random
import re
import sys
from dataclasses import dataclass

import anthropic
import asyncpg

# backend/.env ve backend/.env.local dosyalarındaki değerleri otomatik yükle
# (ANTHROPIC_API_KEY ve DB_URL orada duruyorsa komut satırında vermeye gerek yok).
try:
    from dotenv import load_dotenv
    from pathlib import Path

    _BACKEND_DIR = Path(__file__).resolve().parents[1]
    load_dotenv(_BACKEND_DIR / ".env")
    load_dotenv(_BACKEND_DIR / ".env.local", override=True)
except ImportError:
    pass

# CEFR seviyeleri (levels tablosundaki id'ler)
LEVELS: list[tuple[int, str, str]] = [
    (1, "A1", "beginner, most common everyday words"),
    (2, "A2", "elementary, common daily-life vocabulary"),
    (3, "B1", "intermediate, general topics: work, travel, health, opinions"),
    (4, "B2", "upper-intermediate, abstract and academic-leaning vocabulary"),
    (5, "C1", "advanced, precise and formal vocabulary"),
    (6, "C2", "mastery, rare, literary and idiomatic vocabulary"),
]

# Tür çeşitliliği: uygulama paketleri türlere göre dönüşümlü seçtiği için
# havuzda her türden yeterli kelime olmalı.
POS_QUOTA: dict[str, float] = {
    "noun": 0.32,
    "verb": 0.28,
    "adjective": 0.22,
    "adverb": 0.09,
    "preposition": 0.03,
    "conjunction": 0.02,
    "interjection": 0.04,
}

VALID_POS = set(POS_QUOTA)

# Kapalı sınıf türler: İngilizcede sayıları sınırlı, seviye başına üst sınır konur.
# Aksi hâlde model tekrar üretir ve boşa istek gider.
CLOSED_CLASS_CAP: dict[str, int] = {
    "preposition": 6,
    "conjunction": 4,
    "interjection": 10,
}


def pos_targets_for(need: int) -> dict[str, int]:
    """Seviyedeki `need` kelimeyi türlere dağıtır; kapalı sınıflar sınırlanır,
    artan miktar isim/fiil/sıfat/zarf arasında paylaştırılır."""
    targets = {p: max(1, round(need * share)) for p, share in POS_QUOTA.items()}
    leftover = 0
    for pos, cap in CLOSED_CLASS_CAP.items():
        if targets[pos] > cap:
            leftover += targets[pos] - cap
            targets[pos] = cap
    open_pos = [p for p in targets if p not in CLOSED_CLASS_CAP]
    for i in range(leftover):
        targets[open_pos[i % len(open_pos)]] += 1
    return targets


@dataclass
class WordRow:
    word: str
    definition: str
    definition_tr: str
    ipa: str | None
    pos: str
    level_id: int


# ----------------------------------------------------------------------------- LLM


# Aynı istekleri tekrar tekrar sormamak için konu havuzu. Her denemede farklı bir
# konu verilince model daha önce üretmediği kelimelere yönelir.
THEMES: list[str] = [
    "food, cooking and restaurants",
    "travel, transport and directions",
    "health, body and medicine",
    "work, office and business",
    "school, study and exams",
    "home, furniture and housework",
    "city life, shops and services",
    "nature, weather and animals",
    "feelings, personality and relationships",
    "technology, internet and devices",
    "money, shopping and banking",
    "sports, hobbies and free time",
    "clothes, appearance and style",
    "law, government and society",
    "science, research and environment",
    "art, music, film and literature",
    "time, planning and daily routine",
    "communication, media and news",
]


def build_prompt(
    level_code: str, level_desc: str, pos: str, count: int,
    avoid: list[str], theme: str,
) -> str:
    avoid_text = ", ".join(avoid[:500]) if avoid else "(none)"
    return (
        f"You are building an English vocabulary database for Turkish learners.\n\n"
        f"Give me {count} DISTINCT English {pos}s at CEFR level {level_code} "
        f"({level_desc}).\n\n"
        f"Theme for this batch: {theme}. Stay close to this theme.\n\n"
        f"Rules:\n"
        f"- Every item must be a real, commonly taught English word of the requested part of speech.\n"
        f"- Difficulty must genuinely match {level_code}. Do not give words that are much easier or harder.\n"
        f"- definition: a short learner-friendly English definition (max 12 words, no example sentence).\n"
        f"- definition_tr: the Turkish meaning, short (1-4 words where possible).\n"
        f"- ipa: American English IPA in slashes, e.g. /ˈwɪndoʊ/.\n"
        f"- Use only lowercase for the word unless it is a proper noun.\n"
        f"- Do NOT use any of these already-existing words: {avoid_text}\n\n"
        f'Respond ONLY with a JSON array, no prose, no markdown fence:\n'
        f'[{{"word":"...","definition":"...","definition_tr":"...","ipa":"/.../"}}]'
    )


def parse_items(raw: str) -> list[dict]:
    start, end = raw.find("["), raw.rfind("]")
    if start == -1 or end == -1:
        return []
    try:
        data = json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return []
    return data if isinstance(data, list) else []


def clean_row(item: dict, pos: str, level_id: int) -> WordRow | None:
    word = str(item.get("word", "")).strip()
    definition = str(item.get("definition", "")).strip()
    definition_tr = str(item.get("definition_tr", "")).strip()
    ipa = str(item.get("ipa", "")).strip()

    if not word or not definition or not definition_tr:
        return None
    if not re.fullmatch(r"[A-Za-z][A-Za-z '\-]{0,30}", word):
        return None
    if ipa and not ipa.startswith("/"):
        ipa = f"/{ipa.strip('/')}/"

    return WordRow(
        word=word.lower(),
        definition=definition,
        definition_tr=definition_tr,
        ipa=ipa or None,
        pos=pos,
        level_id=level_id,
    )


class FatalAPIError(RuntimeError):
    """Tekrar denemenin anlamsız olduğu hatalar (kredi bitti, anahtar geçersiz)."""


def is_fatal(err: Exception) -> bool:
    text = str(err).lower()
    return any(s in text for s in (
        "credit balance is too low",
        "invalid x-api-key",
        "authentication_error",
        "permission_error",
    ))


def ask_claude(client: anthropic.Anthropic, model: str, prompt: str) -> str:
    message = client.messages.create(
        model=model,
        max_tokens=4000,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text.strip()


def generate_distractors(client: anthropic.Anthropic, model: str, rows: list[WordRow]) -> dict[str, list[str]]:
    """Her kelime için, doğru tanımına benzer ama yanlış 3 tanım üretir."""
    payload = [{"word": r.word, "definition": r.definition} for r in rows]
    prompt = (
        "For each item below, write 3 WRONG but plausible English definitions "
        "(same style and length as the correct one). They must be clearly wrong "
        "for that word but believable as multiple-choice distractors.\n\n"
        f"{json.dumps(payload, ensure_ascii=False)}\n\n"
        'Respond ONLY with JSON: {"word": ["wrong1","wrong2","wrong3"], ...}'
    )
    raw = ask_claude(client, model, prompt)
    start, end = raw.find("{"), raw.rfind("}")
    if start == -1 or end == -1:
        return {}
    try:
        data = json.loads(raw[start:end + 1])
    except json.JSONDecodeError:
        return {}
    return {k: [str(x) for x in v][:3] for k, v in data.items() if isinstance(v, list)}


# ----------------------------------------------------------------------------- DB


async def fetch_existing(
    conn: asyncpg.Connection,
) -> tuple[set[str], dict[int, int], int, dict[tuple[int, str], list[str]]]:
    """Mevcut kelimeler, seviye sayıları, en yüksek frequency_rank ve
    (seviye, tür) kırılımında kelime listesi."""
    rows = await conn.fetch(
        "SELECT lower(word) AS w, level_id, lower(coalesce(part_of_speech, 'other')) AS pos FROM words"
    )
    existing = {r["w"] for r in rows}
    per_level: dict[int, int] = {}
    by_level_pos: dict[tuple[int, str], list[str]] = {}
    for r in rows:
        per_level[r["level_id"]] = per_level.get(r["level_id"], 0) + 1
        by_level_pos.setdefault((r["level_id"], r["pos"]), []).append(r["w"])
    max_rank = await conn.fetchval("SELECT COALESCE(MAX(frequency_rank), 0) FROM words")
    return existing, per_level, int(max_rank or 0), by_level_pos


async def insert_rows(
    conn: asyncpg.Connection,
    rows: list[WordRow],
    start_rank: int,
    distractors: dict[str, list[str]] | None,
) -> int:
    inserted = 0
    for i, r in enumerate(rows):
        word_id = await conn.fetchval(
            """
            INSERT INTO words (word, definition, definition_tr, ipa, part_of_speech,
                               frequency_rank, level_id, is_active)
            SELECT $1, $2, $3, $4, $5, $6, $7, TRUE
            WHERE NOT EXISTS (SELECT 1 FROM words w WHERE lower(w.word) = lower($1))
            RETURNING id
            """,
            r.word, r.definition, r.definition_tr, r.ipa, r.pos,
            start_rank + i + 1, r.level_id,
        )
        if word_id is None:
            continue
        inserted += 1
        for d in (distractors or {}).get(r.word, []):
            await conn.execute(
                "INSERT INTO word_mcq_distractors (word_id, distractor) VALUES ($1, $2)",
                word_id, d,
            )
    return inserted


# ----------------------------------------------------------------------------- Ana akış


async def main() -> None:
    parser = argparse.ArgumentParser(description="Kelime havuzunu LLM ile genişletir.")
    parser.add_argument("--target", type=int, default=2000, help="Toplam hedef kelime sayısı")
    parser.add_argument("--add", type=int, default=0,
                        help="Mevcut sayının üzerine eklenecek kelime (verilirse --target yok sayılır)")
    parser.add_argument("--batch", type=int, default=25, help="Tek istekte istenecek kelime sayısı")
    parser.add_argument("--model", default="claude-sonnet-4-5", help="Kullanılacak model")
    parser.add_argument("--dry-run", action="store_true", help="Veritabanına yazma")
    parser.add_argument("--distractors", action="store_true", help="MCQ çeldiricileri de üret")
    args = parser.parse_args()

    api_key = os.environ.get("ANTHROPIC_API_KEY", "").strip()
    db_url = os.environ.get("DB_URL", "").strip() or os.environ.get("RAILWAY_DB_URL", "").strip()
    if not api_key:
        sys.exit("HATA: ANTHROPIC_API_KEY boş.")
    if not db_url:
        sys.exit("HATA: DB_URL (veya RAILWAY_DB_URL) boş.")
    db_url = db_url.replace("postgresql+asyncpg://", "postgresql://")

    client = anthropic.Anthropic(api_key=api_key)

    # Ön kontrol: model/anahtar çalışmıyorsa hemen anla, saatlerce boşa deneme.
    print(f"Model kontrol ediliyor ({args.model})...")
    try:
        await asyncio.to_thread(ask_claude, client, args.model, "Reply with exactly: OK")
        print("  model erişimi tamam.")
    except Exception as e:
        sys.exit(f"HATA: Modele erişilemedi → {type(e).__name__}: {e}")

    conn = await asyncpg.connect(db_url)
    print(f"Veritabanı: {db_url.split('@')[-1]}")
    if args.dry_run:
        print("DRY-RUN: veritabanına HİÇBİR ŞEY yazılmayacak.\n")

    try:
        existing, per_level, max_rank, by_level_pos = await fetch_existing(conn)
        total_now = len(existing)

        # --add verildiyse hedef "mevcut + N" olarak hesaplanır (paket paket ilerleme).
        target = total_now + args.add if args.add > 0 else args.target

        missing_total = max(0, target - total_now)
        print(f"Mevcut kelime: {total_now} | hedef: {target} | eklenecek: {missing_total}")
        if missing_total == 0:
            print("Hedefe zaten ulaşılmış.")
            return

        # Seviye başına eşit hedef; zaten dolu olan seviyelerden eksiği diğerlerine yayılır.
        per_level_target = target // len(LEVELS)
        needs: dict[int, int] = {}
        for level_id, code, _ in LEVELS:
            have = per_level.get(level_id, 0)
            needs[level_id] = max(0, per_level_target - have)
            print(f"  {code}: {have} var → {needs[level_id]} eklenecek")

        rank = max_rank
        added_total = 0

        for level_id, code, desc in LEVELS:
            need = needs[level_id]
            if need <= 0:
                continue

            # Tür kotalarını bu seviyenin ihtiyacına dağıt
            pos_targets = pos_targets_for(need)

            for pos, pos_need in pos_targets.items():
                produced = 0
                attempts = 0
                # Açık sınıflarda her denemede farklı bir konu sorulur; konu sayısı kadar dene.
                max_attempts = 4 if pos in CLOSED_CLASS_CAP else len(THEMES)
                while produced < pos_need and attempts < max_attempts:
                    attempts += 1
                    want = min(args.batch, pos_need - produced)

                    # Çakışmanın asıl kaynağı aynı seviye + aynı türdeki kelimeler:
                    # onların TAMAMINI yasak listesine koy, üstüne genel bir örneklem ekle.
                    same_bucket = by_level_pos.get((level_id, pos), [])
                    other_pool = [w for w in existing if w not in set(same_bucket)]
                    avoid = same_bucket[-400:] + random.sample(
                        other_pool, min(100, len(other_pool))
                    )
                    theme = THEMES[(attempts - 1) % len(THEMES)]
                    prompt = build_prompt(code, desc, pos, want, avoid, theme)

                    try:
                        raw = await asyncio.to_thread(ask_claude, client, args.model, prompt)
                    except Exception as e:
                        # Kredi/anahtar hatasında denemeye devam etmenin anlamı yok.
                        if is_fatal(e):
                            print(f"\nDURDURULDU — {e}")
                            print(f"O ana kadar eklenen kelime: {added_total}")
                            print("Sorunu giderdikten sonra aynı komutu tekrar çalıştır, "
                                  "kaldığı yerden devam eder.")
                            return
                        print(f"    [{code}/{pos}] istek hatası: {type(e).__name__}: {e}")
                        await asyncio.sleep(3)
                        continue

                    rows: list[WordRow] = []
                    for item in parse_items(raw):
                        row = clean_row(item, pos, level_id)
                        if row and row.word not in existing:
                            existing.add(row.word)
                            by_level_pos.setdefault((level_id, pos), []).append(row.word)
                            rows.append(row)

                    if not rows:
                        print(f"    [{code}/{pos}] yeni kelime çıkmadı — konu: {theme}")
                        continue

                    dmap = None
                    if args.distractors:
                        try:
                            dmap = await asyncio.to_thread(
                                generate_distractors, client, args.model, rows
                            )
                        except Exception:
                            dmap = None

                    if args.dry_run:
                        for r in rows:
                            print(f"    {code} {pos:12s} {r.word:20s} {r.definition_tr}")
                        inserted = len(rows)
                    else:
                        inserted = await insert_rows(conn, rows, rank, dmap)
                        rank += len(rows)

                    produced += inserted
                    added_total += inserted
                    print(f"    [{code}/{pos}] +{inserted} (bu tür: {produced}/{pos_need}, toplam +{added_total})")

        final_total = await conn.fetchval("SELECT count(*) FROM words")
        print(f"\nBitti. Eklenen: {added_total} | veritabanındaki toplam: {final_total}")

        dist = await conn.fetch(
            "SELECT level_id, part_of_speech, count(*) FROM words "
            "GROUP BY level_id, part_of_speech ORDER BY level_id, count DESC"
        )
        current_level = None
        for r in dist:
            if r["level_id"] != current_level:
                current_level = r["level_id"]
                print(f"  seviye {current_level}:", end=" ")
            print(f"{r['part_of_speech']}={r['count']}", end="  ")
        print()

    finally:
        await conn.close()


if __name__ == "__main__":
    asyncio.run(main())
