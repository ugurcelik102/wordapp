-- Her CEFR seviyesinden örnek kelimeler
-- Placement test için minimum veri

INSERT INTO words (id, word, definition, definition_tr, ipa, part_of_speech, frequency_rank, level_id) VALUES
-- A1
(gen_random_uuid(), 'hello',     'A greeting used when meeting someone',           'merhaba',     '/həˈloʊ/',   'interjection', 1,  1),
(gen_random_uuid(), 'eat',       'To put food in your mouth and swallow it',       'yemek yemek', '/iːt/',      'verb',         2,  1),
(gen_random_uuid(), 'house',     'A building where people live',                   'ev',          '/haʊs/',     'noun',         3,  1),
(gen_random_uuid(), 'big',       'Large in size',                                  'büyük',       '/bɪɡ/',      'adjective',    4,  1),

-- A2
(gen_random_uuid(), 'journey',   'A long trip from one place to another',          'yolculuk',    '/ˈdʒɜːrni/', 'noun',         10, 2),
(gen_random_uuid(), 'explain',   'To make something clear or easy to understand',  'açıklamak',   '/ɪkˈspleɪn/','verb',         11, 2),
(gen_random_uuid(), 'weather',   'The condition of the atmosphere at a given time','hava durumu', '/ˈweðər/',   'noun',         12, 2),
(gen_random_uuid(), 'choose',    'To select from a number of possibilities',       'seçmek',      '/tʃuːz/',    'verb',         13, 2),

-- B1
(gen_random_uuid(), 'achieve',   'To successfully reach a goal after effort',      'başarmak',    '/əˈtʃiːv/',  'verb',         50, 3),
(gen_random_uuid(), 'opinion',   'A personal view or judgment about something',    'görüş',       '/əˈpɪnjən/', 'noun',         51, 3),
(gen_random_uuid(), 'improve',   'To make or become better',                       'geliştirmek', '/ɪmˈpruːv/', 'verb',         52, 3),
(gen_random_uuid(), 'suggest',   'To propose an idea or plan for consideration',   'önermek',     '/səˈdʒest/', 'verb',         53, 3),

-- B2
(gen_random_uuid(), 'perceive',  'To become aware of something through the senses','algılamak',  '/pərˈsiːv/', 'verb',         200, 4),
(gen_random_uuid(), 'negotiate', 'To discuss something to reach an agreement',     'müzakere etmek','/nɪˈɡoʊʃieɪt/','verb',    201, 4),
(gen_random_uuid(), 'ambiguous', 'Open to more than one interpretation',           'belirsiz',    '/æmˈbɪɡjuəs/','adjective',  202, 4),
(gen_random_uuid(), 'elaborate', 'To explain something in more detail',            'ayrıntılandırmak','/ɪˈlæbəreɪt/','verb',   203, 4),

-- C1
(gen_random_uuid(), 'eloquent',  'Fluent and persuasive in speaking or writing',   'belagatli',   '/ˈeləkwənt/','adjective',  500, 5),
(gen_random_uuid(), 'pragmatic', 'Dealing with things sensibly and realistically', 'pragmatik',   '/præɡˈmætɪk/','adjective', 501, 5),
(gen_random_uuid(), 'mitigate',  'To make something less severe or serious',       'hafifletmek', '/ˈmɪtɪɡeɪt/','verb',       502, 5),
(gen_random_uuid(), 'nuance',    'A subtle difference in meaning or expression',   'nüans',       '/ˈnjuːɑːns/', 'noun',       503, 5),

-- C2
(gen_random_uuid(), 'ephemeral', 'Lasting for a very short time',                 'geçici',      '/ɪˈfemərəl/','adjective',  1000, 6),
(gen_random_uuid(), 'esoteric',  'Intended for or understood by only a few',       'ezoterik',    '/ˌesəˈterɪk/','adjective', 1001, 6),
(gen_random_uuid(), 'perfidious','Guilty of betrayal or treachery',               'hain',        '/pərˈfɪdiəs/','adjective', 1002, 6),
(gen_random_uuid(), 'loquacious','Tending to talk a great deal',                  'çok konuşan', '/loʊˈkweɪʃəs/','adjective',1003, 6);

-- Her kelime için 3 distractor ekle (aynı seviyeden rastgele)
-- A1 kelimeleri için
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'To move from one place to another'    FROM words w WHERE w.word = 'hello';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A type of animal that lives in water' FROM words w WHERE w.word = 'hello';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'To write something on paper'          FROM words w WHERE w.word = 'hello';

INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'To sleep for a long time'             FROM words w WHERE w.word = 'eat';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A greeting used when meeting someone' FROM words w WHERE w.word = 'eat';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'To run very fast'                     FROM words w WHERE w.word = 'eat';

INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A type of vehicle'                    FROM words w WHERE w.word = 'house';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A feeling of happiness'               FROM words w WHERE w.word = 'house';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'To put food in your mouth and swallow'FROM words w WHERE w.word = 'house';

INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A building where people live'         FROM words w WHERE w.word = 'big';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'Moving quickly'                       FROM words w WHERE w.word = 'big';
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, 'A sound made by animals'              FROM words w WHERE w.word = 'big';

-- Örnek cümleler
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'Hello, how are you today?', 'Merhaba, bugün nasılsın?', true FROM words w WHERE w.word = 'hello';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'I eat breakfast every morning.', 'Her sabah kahvaltı yaparım.', true FROM words w WHERE w.word = 'eat';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'They live in a big house.', 'Büyük bir evde yaşıyorlar.', true FROM words w WHERE w.word = 'house';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'This is a big problem.', 'Bu büyük bir sorun.', true FROM words w WHERE w.word = 'big';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'She achieved her goals.', 'Hedeflerine ulaştı.', true FROM words w WHERE w.word = 'achieve';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'The word is ambiguous without context.', 'Kelime bağlam olmadan belirsizdir.', true FROM words w WHERE w.word = 'ambiguous';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'His speech was eloquent and moving.', 'Konuşması belagatli ve etkileyiciydi.', true FROM words w WHERE w.word = 'eloquent';
INSERT INTO word_examples (word_id, sentence, translation, is_primary)
SELECT w.id, 'The beauty of the moment was ephemeral.', 'Anın güzelliği geçiciydi.', true FROM words w WHERE w.word = 'ephemeral';
