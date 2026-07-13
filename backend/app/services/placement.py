import random
import uuid
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from sqlalchemy.orm import selectinload

from app.models.placement import PlacementTest, PlacementTestQuestion, UserPlacementResult
from app.models.word import Word, WordMcqDistractor
from app.models.user import Level, UserProfile
from app.schemas.placement import PlacementQuestion, QuestionAnswer, PlacementResult


async def get_or_create_default_test(db: AsyncSession) -> PlacementTest:
    """Varsayılan placement testini getirir, yoksa oluşturur."""
    result = await db.execute(select(PlacementTest).limit(1))
    test = result.scalar_one_or_none()
    if not test:
        test = PlacementTest(name="Genel Seviye Testi")
        db.add(test)
        await db.commit()
        await db.refresh(test)
    return test


async def build_questions(
    db: AsyncSession, test: PlacementTest
) -> list[PlacementQuestion]:
    """
    Her CEFR seviyesinden 3-4 kelime seçip MCQ soruları oluşturur.
    Toplam ~20 soru, adaptif sıralama (A1'den C2'ye).
    """
    # Her seviyeden kelime çek
    levels_result = await db.execute(select(Level).order_by(Level.sort_order))
    levels = levels_result.scalars().all()

    questions: list[PlacementQuestion] = []
    q_id_counter = 1

    for level in levels:
        # Bu seviyeden rastgele 3-4 kelime al
        words_result = await db.execute(
            select(Word)
            .where(Word.level_id == level.id, Word.is_active == True)
            .order_by(Word.frequency_rank.nullslast())
            .limit(4)
        )
        words = words_result.scalars().all()

        for word in words:
            # Distractors'ı çek
            dist_result = await db.execute(
                select(WordMcqDistractor).where(WordMcqDistractor.word_id == word.id)
            )
            distractors = [d.distractor for d in dist_result.scalars().all()]

            # En az 3 distractor yoksa aynı seviyedeki başka kelimelerin tanımlarını kullan
            if len(distractors) < 3:
                other_result = await db.execute(
                    select(Word.definition)
                    .where(Word.level_id == level.id, Word.id != word.id, Word.is_active == True)
                    .limit(3 - len(distractors))
                )
                distractors += [r for r in other_result.scalars().all()]

            options = distractors[:3] + [word.definition]
            random.shuffle(options)

            questions.append(PlacementQuestion(
                question_id=q_id_counter,
                word=word.word,
                question_type="definition_mcq",
                question_text=f'"{word.word}" kelimesinin anlamı nedir?',
                options=options,
                target_level_code=level.code,
            ))
            q_id_counter += 1

    return questions


def calculate_score(
    questions: list[PlacementQuestion],
    answers: list[QuestionAnswer],
    correct_definitions: dict[int, str],  # question_id → doğru tanım
) -> tuple[float, dict[str, int], int]:
    """
    Skoru ve seviyeye göre breakdown'ı hesaplar.
    Returns: (score_0_100, breakdown, recommended_level_id)
    """
    answer_map = {a.question_id: a.selected_option for a in answers}
    breakdown: dict[str, int] = {}
    correct_total = 0

    for q in questions:
        correct_def = correct_definitions.get(q.question_id)
        if not correct_def:
            continue
        level_code = q.target_level_code
        breakdown.setdefault(level_code, 0)
        if answer_map.get(q.question_id) == correct_def:
            breakdown[level_code] += 1
            correct_total += 1

    score = (correct_total / len(questions)) * 100 if questions else 0

    # Seviye belirleme: her seviyede en az %60 doğru yaptığı en yüksek seviye
    level_order = ["A1", "A2", "B1", "B2", "C1", "C2"]
    level_id_map = {"A1": 1, "A2": 2, "B1": 3, "B2": 4, "C1": 5, "C2": 6}

    recommended_code = "A1"
    for code in level_order:
        total_in_level = sum(1 for q in questions if q.target_level_code == code)
        if total_in_level == 0:
            continue
        ratio = breakdown.get(code, 0) / total_in_level
        if ratio >= 0.6:
            recommended_code = code
        else:
            break  # zinciri kır, üst seviyeye geçme

    return score, breakdown, level_id_map[recommended_code]


async def save_result(
    db: AsyncSession,
    user_id: uuid.UUID,
    test_id: int,
    score: float,
    recommended_level_id: int,
    answers_payload: dict,
) -> UserPlacementResult:
    result = UserPlacementResult(
        user_id=user_id,
        test_id=test_id,
        score=score,
        recommended_level_id=recommended_level_id,
        final_level_id=recommended_level_id,
        answers=answers_payload,
    )
    db.add(result)

    # Kullanıcı profilini güncelle
    profile_result = await db.execute(
        select(UserProfile).where(UserProfile.user_id == user_id)
    )
    profile = profile_result.scalar_one_or_none()
    if profile:
        profile.current_level_id = recommended_level_id

    await db.commit()
    await db.refresh(result)
    return result
