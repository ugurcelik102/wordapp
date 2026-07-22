import uuid
import json
from datetime import date, datetime, timezone
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, not_, delete, func
from sqlalchemy.orm import selectinload
from starlette.concurrency import run_in_threadpool
import anthropic

from app.core.config import settings
from app.models.user import UserProfile
from app.models.word import Word, WordExample
from app.models.package import WordPackage, WordPackageItem
from app.models.progress import UserWordProgress
from app.services.srs import update_srs, get_new_status


async def _pick_diverse_new_words(
    db: AsyncSession,
    user_id: uuid.UUID,
    level_id: int,
    limit: int,
    exclude_ids: list[uuid.UUID],
    same_level_only: bool = True,
) -> list[uuid.UUID]:
    """Görülmemiş kelimelerden tür (part-of-speech) çeşitliliği olan bir seçki döner.

    Sıklık sırasına göre geniş bir aday havuzu çekilir, sonra türlere göre
    sırayla (noun → verb → adjective → …) seçilir. Böylece paket tek türe
    (ör. hep 'verb') kilitlenmez.
    """
    if limit <= 0:
        return []

    seen_subq = select(UserWordProgress.word_id).where(UserWordProgress.user_id == user_id)

    conditions = [
        Word.is_active == True,
        not_(Word.id.in_(seen_subq)),
    ]
    if exclude_ids:
        conditions.append(not_(Word.id.in_(exclude_ids)))
    if same_level_only:
        conditions.append(Word.level_id == level_id)

    order_by = [Word.frequency_rank.nullslast()]
    if not same_level_only:
        order_by.insert(0, func.abs(Word.level_id - level_id))

    # Aday havuzu: istenenden çok daha geniş tut ki her türden kelime bulunabilsin.
    result = await db.execute(
        select(Word.id, Word.part_of_speech)
        .where(*conditions)
        .order_by(*order_by)
        .limit(max(limit * 25, 100))
    )
    candidates = result.all()
    if not candidates:
        return []

    buckets: dict[str, list[uuid.UUID]] = {}
    for word_id, pos in candidates:
        buckets.setdefault((pos or "other").lower(), []).append(word_id)

    # Az bulunan türler öne gelsin ki isim/fiil çoğunluğu her şeyi doldurmasın.
    order = sorted(buckets, key=lambda p: (len(buckets[p]), p))

    picked: list[uuid.UUID] = []
    while len(picked) < limit:
        added = False
        for pos in order:
            if not buckets[pos]:
                continue
            picked.append(buckets[pos].pop(0))
            added = True
            if len(picked) == limit:
                break
        if not added:
            break

    return picked


async def get_or_create_today_package(
    db: AsyncSession, user_id: uuid.UUID
) -> WordPackage:
    today = date.today()

    result = await db.execute(
        select(WordPackage)
        .where(WordPackage.user_id == user_id, WordPackage.package_date == today)
        .options(selectinload(WordPackage.items).selectinload(WordPackageItem.word).selectinload(Word.examples))
    )
    existing = result.scalar_one_or_none()
    if existing:
        return existing

    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one()
    word_count = profile.daily_word_count
    level_id = profile.current_level_id

    selected_word_ids: list[uuid.UUID] = []

    srs_result = await db.execute(
        select(UserWordProgress.word_id)
        .where(
            UserWordProgress.user_id == user_id,
            UserWordProgress.next_review_date <= today,
            UserWordProgress.status.in_(["learning", "review"]),
        )
        .order_by(UserWordProgress.next_review_date)
        .limit(word_count // 2)
    )
    selected_word_ids.extend(srs_result.scalars().all())

    remaining = word_count - len(selected_word_ids)
    if remaining > 0:
        selected_word_ids.extend(
            await _pick_diverse_new_words(
                db, user_id, level_id, remaining, selected_word_ids
            )
        )

    # Hâlâ yetersizse: en yakın seviyelerden görülmemiş kelimelerle doldur.
    if len(selected_word_ids) < word_count:
        selected_word_ids.extend(
            await _pick_diverse_new_words(
                db, user_id, level_id,
                word_count - len(selected_word_ids),
                selected_word_ids,
                same_level_only=False,
            )
        )

    # Havuz tamamen tükendiyse: en uzun süredir çalışılmayan kelimeleri
    # rastgelelik katarak yeniden kullan (her gün aynı kelimeler gelmesin).
    if len(selected_word_ids) < word_count:
        fallback_result = await db.execute(
            select(UserWordProgress.word_id)
            .where(
                UserWordProgress.user_id == user_id,
                not_(UserWordProgress.word_id.in_(selected_word_ids)),
            )
            .order_by(
                UserWordProgress.last_reviewed_at.asc().nullsfirst(),
                func.random(),
            )
            .limit(word_count - len(selected_word_ids))
        )
        selected_word_ids.extend(fallback_result.scalars().all())

    package = WordPackage(
        user_id=user_id,
        level_id=level_id,
        package_date=today,
        word_count=len(selected_word_ids),
        status="active",
    )
    db.add(package)
    await db.flush()

    for i, word_id in enumerate(selected_word_ids):
        db.add(WordPackageItem(package_id=package.id, word_id=word_id, sort_order=i))

    for word_id in selected_word_ids:
        exists_result = await db.execute(
            select(UserWordProgress).where(
                UserWordProgress.user_id == user_id,
                UserWordProgress.word_id == word_id,
            )
        )
        if not exists_result.scalar_one_or_none():
            db.add(UserWordProgress(user_id=user_id, word_id=word_id, status="new"))

    await db.commit()

    result = await db.execute(
        select(WordPackage)
        .where(WordPackage.id == package.id)
        .options(selectinload(WordPackage.items).selectinload(WordPackageItem.word).selectinload(Word.examples))
    )
    return result.scalar_one()


async def create_new_package(db: AsyncSession, user_id: uuid.UUID) -> WordPackage:
    """Bugünkü paketi yeniden üretir. Paketi silmek yerine mevcut satırı
    yeniden kullanır (session/exercise FK'larına dokunmadan)."""
    today = date.today()

    # DİKKAT: items'ı selectinload ETME. Koleksiyon yüklenmezse delete-orphan
    # reconciliation tetiklenmez ve db.add deseni (get_or_create ile birebir) çalışır.
    existing = await db.execute(
        select(WordPackage)
        .where(WordPackage.user_id == user_id, WordPackage.package_date == today)
    )
    package = existing.scalar_one_or_none()

    profile_result = await db.execute(select(UserProfile).where(UserProfile.user_id == user_id))
    profile = profile_result.scalar_one()
    word_count = profile.daily_word_count
    level_id = profile.current_level_id

    selected_word_ids: list[uuid.UUID] = []

    srs_result = await db.execute(
        select(UserWordProgress.word_id).where(
            UserWordProgress.user_id == user_id,
            UserWordProgress.next_review_date <= today,
            UserWordProgress.status.in_(["learning", "review"]),
        ).order_by(UserWordProgress.next_review_date).limit(word_count // 2)
    )
    selected_word_ids.extend(srs_result.scalars().all())

    remaining = word_count - len(selected_word_ids)
    if remaining > 0:
        selected_word_ids.extend(
            await _pick_diverse_new_words(
                db, user_id, level_id, remaining, selected_word_ids
            )
        )

    # Hâlâ yetersizse: en yakın seviyelerden görülmemiş kelimelerle doldur.
    if len(selected_word_ids) < word_count:
        selected_word_ids.extend(
            await _pick_diverse_new_words(
                db, user_id, level_id,
                word_count - len(selected_word_ids),
                selected_word_ids,
                same_level_only=False,
            )
        )

    # Havuz tamamen tükendiyse: en uzun süredir çalışılmayan kelimeleri
    # rastgelelik katarak yeniden kullan (her gün aynı kelimeler gelmesin).
    if len(selected_word_ids) < word_count:
        fallback_result = await db.execute(
            select(UserWordProgress.word_id)
            .where(
                UserWordProgress.user_id == user_id,
                not_(UserWordProgress.word_id.in_(selected_word_ids)),
            )
            .order_by(
                UserWordProgress.last_reviewed_at.asc().nullsfirst(),
                func.random(),
            )
            .limit(word_count - len(selected_word_ids))
        )
        selected_word_ids.extend(fallback_result.scalars().all())

    if not selected_word_ids:
        from fastapi import HTTPException
        raise HTTPException(status_code=404, detail="Veritabanında hiç kelime bulunamadı")

    if package:
        # Mevcut paketi yeniden kullan: eski item'ları SQL düzeyinde sil
        # (koleksiyon yüklü olmadığı için orphan reconciliation olmaz).
        await db.execute(
            delete(WordPackageItem).where(WordPackageItem.package_id == package.id)
        )
        package.level_id = level_id
        package.word_count = len(selected_word_ids)
        package.status = "active"
        await db.flush()
    else:
        package = WordPackage(
            user_id=user_id, level_id=level_id, package_date=today,
            word_count=len(selected_word_ids), status="active",
        )
        db.add(package)
        await db.flush()

    # get_or_create ile birebir aynı desen: db.add + package_id.
    for i, word_id in enumerate(selected_word_ids):
        db.add(WordPackageItem(package_id=package.id, word_id=word_id, sort_order=i))

    for word_id in selected_word_ids:
        exists_result = await db.execute(
            select(UserWordProgress).where(
                UserWordProgress.user_id == user_id,
                UserWordProgress.word_id == word_id,
            )
        )
        if not exists_result.scalar_one_or_none():
            db.add(UserWordProgress(user_id=user_id, word_id=word_id, status="new"))

    await db.commit()

    result = await db.execute(
        select(WordPackage).where(WordPackage.id == package.id)
        .options(selectinload(WordPackage.items).selectinload(WordPackageItem.word).selectinload(Word.examples))
    )
    return result.scalar_one()


async def get_word_detail(db: AsyncSession, word_id: uuid.UUID) -> Word | None:
    result = await db.execute(
        select(Word)
        .where(Word.id == word_id)
        .options(
            selectinload(Word.examples),
            selectinload(Word.mcq_distractors),
        )
    )
    return result.scalar_one_or_none()


def _generate_example_sync(word_text: str, pos: str, definition: str) -> tuple[str, str | None] | None:
    """LLM ile tek bir örnek cümle + Türkçe çevirisi üretir (senkron; threadpool'da çağrılır)."""
    prompt = (
        f'Create ONE short, natural example sentence in English using the word '
        f'"{word_text}" ({pos}, meaning: {definition}), suitable for an English learner. '
        f'Then give its Turkish translation. '
        f'Respond ONLY with JSON, no extra text: {{"sentence": "...", "translation": "..."}}'
    )
    client = anthropic.Anthropic(api_key=settings.ANTHROPIC_API_KEY)
    message = client.messages.create(
        model="claude-haiku-4-5-20251001",
        max_tokens=200,
        messages=[{"role": "user", "content": prompt}],
    )
    raw = message.content[0].text.strip()
    start, end = raw.find("{"), raw.rfind("}")
    if start == -1 or end == -1:
        return None
    data = json.loads(raw[start:end + 1])
    sentence = (data.get("sentence") or "").strip()
    translation = (data.get("translation") or "").strip() or None
    return (sentence, translation) if sentence else None


async def ensure_word_example(db: AsyncSession, word: Word) -> Word:
    """Kelimenin örnek cümlesi yoksa LLM ile bir tane üretip DB'ye kaydeder.
    Bir kez üretilir; sonraki isteklerde DB'den gelir. Üretim başarısızsa
    sessizce geçer (kullanıcı akışı bozulmaz)."""
    if word.examples or not settings.ANTHROPIC_API_KEY:
        return word
    try:
        result = await run_in_threadpool(
            _generate_example_sync,
            word.word,
            word.part_of_speech or "word",
            word.definition,
        )
    except Exception:
        return word
    if not result:
        return word
    sentence, translation = result
    db.add(WordExample(word_id=word.id, sentence=sentence, translation=translation, is_primary=True))
    await db.commit()
    await db.refresh(word, attribute_names=["examples"])
    return word


async def get_learned_words(
    db: AsyncSession, user_id: uuid.UUID, offset: int = 0, limit: int = 8
) -> tuple[list[Word], int]:
    """T0'dan itibaren öğrenilmiş (learning/review/mastered) tüm kelimeleri
    kararlı bir sırayla, sayfalı döner. (kelimeler, toplam) verir."""
    learned_filter = (
        UserWordProgress.user_id == user_id,
        UserWordProgress.status.in_(["learning", "review", "mastered"]),
    )

    count_result = await db.execute(
        select(func.count()).select_from(UserWordProgress).where(*learned_filter)
    )
    total = count_result.scalar() or 0

    result = await db.execute(
        select(Word)
        .join(UserWordProgress, UserWordProgress.word_id == Word.id)
        .where(*learned_filter)
        .options(selectinload(Word.examples))
        .order_by(Word.frequency_rank.nullslast(), Word.id)
        .offset(offset)
        .limit(limit)
    )
    return list(result.scalars().all()), total


async def get_review_words(
    db: AsyncSession, user_id: uuid.UUID, limit: int = 20
) -> list[Word]:
    """SRS'e göre bugün tekrarı gelen kelimeleri döner."""
    today = date.today()
    # 1) Tekrarı gelen kelime id'leri
    prog_result = await db.execute(
        select(UserWordProgress.word_id)
        .where(
            UserWordProgress.user_id == user_id,
            UserWordProgress.next_review_date <= today,
            UserWordProgress.status.in_(["learning", "review", "mastered"]),
        )
        .order_by(UserWordProgress.next_review_date)
        .limit(limit)
    )
    word_ids = list(prog_result.scalars().all())
    if not word_ids:
        return []

    # 2) Kelimeleri örnekleriyle yükle (kanıtlı desen, join'siz)
    result = await db.execute(
        select(Word)
        .where(Word.id.in_(word_ids))
        .options(selectinload(Word.examples))
    )
    return list(result.scalars().all())


async def submit_review(
    db: AsyncSession, user_id: uuid.UUID, word_id: uuid.UUID, is_correct: bool
) -> date | None:
    """Tek bir tekrar sonucunu SRS'e işler, sonraki tekrar tarihini döner."""
    result = await db.execute(
        select(UserWordProgress).where(
            UserWordProgress.user_id == user_id,
            UserWordProgress.word_id == word_id,
        )
    )
    progress = result.scalar_one_or_none()
    if not progress:
        return None

    new_ef, new_interval, new_reps, next_date = update_srs(
        ease_factor=float(progress.ease_factor),
        interval_days=progress.interval_days,
        repetitions=progress.repetitions,
        is_correct=is_correct,
    )
    progress.ease_factor = new_ef
    progress.interval_days = new_interval
    progress.repetitions = new_reps
    progress.next_review_date = next_date
    progress.last_reviewed_at = datetime.now(timezone.utc)
    progress.status = get_new_status(new_reps, new_interval)
    if is_correct:
        progress.correct_count += 1
    else:
        progress.incorrect_count += 1

    await db.commit()
    return next_date
