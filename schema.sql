-- ============================================================
-- English Word Learning App — PostgreSQL Schema
-- ============================================================

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- fuzzy word search için

-- ============================================================
-- 1. KULLANICI & PROFİL
-- ============================================================

CREATE TABLE users (
    id              UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    email           TEXT UNIQUE NOT NULL,
    name            TEXT NOT NULL,
    hashed_password TEXT NOT NULL,
    created_at      TIMESTAMPTZ DEFAULT NOW(),
    updated_at      TIMESTAMPTZ DEFAULT NOW()
);

-- CEFR seviyeleri: A1 → C2
CREATE TABLE levels (
    id          SERIAL PRIMARY KEY,
    code        TEXT UNIQUE NOT NULL,  -- 'A1', 'A2', 'B1', 'B2', 'C1', 'C2'
    name        TEXT NOT NULL,         -- 'Beginner', 'Elementary', ...
    description TEXT,
    sort_order  INT NOT NULL           -- sıralama için
);

INSERT INTO levels (code, name, description, sort_order) VALUES
    ('A1', 'Beginner',     'Temel günlük ifadeler ve basit sorular',         1),
    ('A2', 'Elementary',   'Basit ve rutin konularda iletişim',              2),
    ('B1', 'Intermediate', 'İş, okul ve seyahat gibi konularda iletişim',   3),
    ('B2', 'Upper-Inter',  'Karmaşık konuları anlama ve akıcı iletişim',    4),
    ('C1', 'Advanced',     'Karmaşık metinleri anlama, kendiliğinden ifade', 5),
    ('C2', 'Mastery',      'Duyduğunu ve okuduğunu kolayca anlama',         6);

CREATE TABLE user_profiles (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    current_level_id     INT NOT NULL REFERENCES levels(id),
    daily_word_count     INT NOT NULL DEFAULT 6 CHECK (daily_word_count IN (4, 6, 8)),
    streak_count         INT NOT NULL DEFAULT 0,
    longest_streak       INT NOT NULL DEFAULT 0,
    last_active_date     DATE,
    total_words_learned  INT NOT NULL DEFAULT 0,
    created_at           TIMESTAMPTZ DEFAULT NOW(),
    updated_at           TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE user_category_preferences (
    user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    category_id INT NOT NULL,
    PRIMARY KEY (user_id, category_id)
);

-- ============================================================
-- 2. KELİME VE KATEGORİ
-- ============================================================

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        TEXT UNIQUE NOT NULL,
    description TEXT,
    icon        TEXT
);

INSERT INTO categories (name, description, icon) VALUES
    ('Daily Life',     'Günlük hayatta en sık kullanılan kelimeler',  'house'),
    ('Verbs',          'Temel ve sık kullanılan fiiller',              'bolt'),
    ('Idioms',         'Deyimler ve kalıp ifadeler',                  'quote.bubble'),
    ('Conjunctions',   'Bağlaçlar ve geçiş kelimeleri',               'link'),
    ('Phrasal Verbs',  'Fiil + edat kombinasyonları',                 'arrow.triangle.branch'),
    ('Business',       'İş ve profesyonel ortam kelimeleri',          'briefcase'),
    ('Academic',       'Akademik yazı ve okuma kelimeleri',           'book'),
    ('Travel',         'Seyahat ve turizm kelimeleri',                'airplane');

ALTER TABLE user_category_preferences
    ADD CONSTRAINT fk_ucp_category FOREIGN KEY (category_id) REFERENCES categories(id) ON DELETE CASCADE;

CREATE TABLE words (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    word             TEXT NOT NULL,
    definition       TEXT NOT NULL,
    definition_tr    TEXT,
    ipa              TEXT,
    audio_url        TEXT,
    part_of_speech   TEXT,
    register         TEXT DEFAULT 'neutral' CHECK (register IN ('formal', 'informal', 'neutral')),
    frequency_rank   INT,
    level_id         INT NOT NULL REFERENCES levels(id),
    is_active        BOOLEAN DEFAULT TRUE,
    created_at       TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_words_level ON words(level_id);
CREATE INDEX idx_words_frequency ON words(frequency_rank);
CREATE INDEX idx_words_word ON words USING gin(word gin_trgm_ops);

CREATE TABLE word_categories (
    word_id     UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    category_id INT  NOT NULL REFERENCES categories(id) ON DELETE CASCADE,
    PRIMARY KEY (word_id, category_id)
);

CREATE TABLE word_examples (
    id          SERIAL PRIMARY KEY,
    word_id     UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    sentence    TEXT NOT NULL,
    translation TEXT,
    is_primary  BOOLEAN DEFAULT FALSE
);

CREATE TABLE word_family (
    id               SERIAL PRIMARY KEY,
    base_word_id     UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    related_form     TEXT NOT NULL,
    relationship     TEXT NOT NULL
);

CREATE TABLE word_relations (
    word_id         UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    related_word_id UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    relation_type   TEXT NOT NULL CHECK (relation_type IN ('synonym', 'antonym')),
    PRIMARY KEY (word_id, related_word_id, relation_type)
);

CREATE TABLE word_mcq_distractors (
    id         SERIAL PRIMARY KEY,
    word_id    UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    distractor TEXT NOT NULL
);

-- ============================================================
-- 3. SEVİYE TESPİT TESTİ
-- ============================================================

CREATE TABLE placement_tests (
    id         SERIAL PRIMARY KEY,
    name       TEXT NOT NULL,
    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE TABLE placement_test_questions (
    id              SERIAL PRIMARY KEY,
    test_id         INT  NOT NULL REFERENCES placement_tests(id) ON DELETE CASCADE,
    word_id         UUID NOT NULL REFERENCES words(id),
    question_type   TEXT NOT NULL CHECK (question_type IN ('definition_mcq', 'fill_blank', 'synonym')),
    target_level_id INT  NOT NULL REFERENCES levels(id),
    sort_order      INT  NOT NULL
);

CREATE TABLE user_placement_results (
    id                   UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id              UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    test_id              INT  NOT NULL REFERENCES placement_tests(id),
    score                NUMERIC(5,2),
    recommended_level_id INT REFERENCES levels(id),
    final_level_id       INT REFERENCES levels(id),
    answers              JSONB,
    completed_at         TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 4. GÜNLÜK KELİME PAKETİ
-- ============================================================

CREATE TABLE word_packages (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    level_id     INT  NOT NULL REFERENCES levels(id),
    package_date DATE NOT NULL DEFAULT CURRENT_DATE,
    word_count   INT  NOT NULL CHECK (word_count IN (4, 6, 8)),
    status       TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'active', 'completed')),
    created_at   TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, package_date)
);

CREATE TABLE word_package_items (
    id         SERIAL PRIMARY KEY,
    package_id UUID NOT NULL REFERENCES word_packages(id) ON DELETE CASCADE,
    word_id    UUID NOT NULL REFERENCES words(id),
    sort_order INT  NOT NULL,
    UNIQUE (package_id, word_id)
);

-- Günlük görevlerin tamamlanma kaydı (öncelik sırası: review → new_words → sentence_usage)
CREATE TABLE daily_task_completions (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    task_key     TEXT NOT NULL CHECK (task_key IN ('review', 'new_words', 'sentence_usage')),
    task_date    DATE NOT NULL DEFAULT CURRENT_DATE,
    completed_at TIMESTAMPTZ DEFAULT NOW(),
    UNIQUE (user_id, task_key, task_date)
);

-- ============================================================
-- 5. SPACED REPETITION (SRS)
-- ============================================================

CREATE TABLE user_word_progress (
    id               UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    word_id          UUID NOT NULL REFERENCES words(id) ON DELETE CASCADE,
    status           TEXT NOT NULL DEFAULT 'new' CHECK (status IN ('new', 'learning', 'review', 'mastered')),
    ease_factor      NUMERIC(4,2) DEFAULT 2.5,
    interval_days    INT DEFAULT 1,
    repetitions      INT DEFAULT 0,
    next_review_date DATE DEFAULT CURRENT_DATE,
    last_reviewed_at TIMESTAMPTZ,
    correct_count    INT DEFAULT 0,
    incorrect_count  INT DEFAULT 0,
    UNIQUE (user_id, word_id)
);

CREATE INDEX idx_uwp_next_review ON user_word_progress(user_id, next_review_date)
    WHERE status != 'mastered';

-- ============================================================
-- 6. SESSION & EGZERSİZLER
-- ============================================================

CREATE TABLE sessions (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    package_id   UUID NOT NULL REFERENCES word_packages(id),
    status       TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'abandoned')),
    started_at   TIMESTAMPTZ DEFAULT NOW(),
    completed_at TIMESTAMPTZ,
    duration_sec INT
);

CREATE TABLE session_exercises (
    id             UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id     UUID NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    word_id        UUID NOT NULL REFERENCES words(id),
    exercise_type  TEXT NOT NULL CHECK (exercise_type IN ('overview', 'mcq', 'sentence_fill', 'pronunciation')),
    is_correct     BOOLEAN,
    selected_answer TEXT,
    response_time_ms INT,
    completed_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 7. OKUMA PARÇASI (AI Generated)
-- ============================================================

CREATE TABLE reading_passages (
    id           UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    session_id   UUID UNIQUE NOT NULL REFERENCES sessions(id) ON DELETE CASCADE,
    content      TEXT NOT NULL,
    word_count   INT,
    target_words UUID[],
    prompt_used  TEXT,
    model_used   TEXT,
    created_at   TIMESTAMPTZ DEFAULT NOW()
);

-- ============================================================
-- 8. YARDIMCI FONKSİYONLAR
-- ============================================================

CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE TRIGGER trg_user_profiles_updated_at
    BEFORE UPDATE ON user_profiles
    FOR EACH ROW EXECUTE FUNCTION update_updated_at();

CREATE OR REPLACE FUNCTION update_user_streak(p_user_id UUID)
RETURNS VOID AS $$
DECLARE
    v_last_date DATE;
    v_streak    INT;
BEGIN
    SELECT last_active_date, streak_count
    INTO v_last_date, v_streak
    FROM user_profiles WHERE user_id = p_user_id;

    IF v_last_date = CURRENT_DATE THEN
        RETURN;
    ELSIF v_last_date = CURRENT_DATE - 1 THEN
        v_streak := v_streak + 1;
    ELSE
        v_streak := 1;
    END IF;

    UPDATE user_profiles SET
        streak_count     = v_streak,
        longest_streak   = GREATEST(longest_streak, v_streak),
        last_active_date = CURRENT_DATE
    WHERE user_id = p_user_id;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- 9. VIEWS
-- ============================================================

CREATE VIEW v_words_due_today AS
SELECT
    uwp.user_id,
    w.word,
    w.definition,
    w.ipa,
    w.audio_url,
    uwp.status,
    uwp.ease_factor,
    uwp.next_review_date
FROM user_word_progress uwp
JOIN words w ON w.id = uwp.word_id
WHERE uwp.next_review_date <= CURRENT_DATE
  AND uwp.status != 'mastered';

CREATE VIEW v_user_stats AS
SELECT
    u.id AS user_id,
    u.name,
    l.code AS level,
    up.streak_count,
    up.longest_streak,
    up.total_words_learned,
    up.daily_word_count,
    COUNT(uwp.word_id) FILTER (WHERE uwp.status = 'mastered')  AS mastered_count,
    COUNT(uwp.word_id) FILTER (WHERE uwp.status = 'review')    AS review_count,
    COUNT(uwp.word_id) FILTER (WHERE uwp.status = 'learning')  AS learning_count
FROM users u
JOIN user_profiles up ON up.user_id = u.id
JOIN levels l ON l.id = up.current_level_id
LEFT JOIN user_word_progress uwp ON uwp.user_id = u.id
GROUP BY u.id, u.name, l.code, up.streak_count, up.longest_streak,
         up.total_words_learned, up.daily_word_count;
