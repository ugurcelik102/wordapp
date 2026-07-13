-- Ek kelime havuzu: her CEFR seviyesine daha fazla kelime.
-- "Yeni Kelimeler" akışında çeşitlilik için. Mevcut seed'deki kelimeler tekrar edilmez.
-- Çalıştırma:  psql "$DATABASE_URL" -f seed_words_extra.sql

INSERT INTO words (id, word, definition, definition_tr, ipa, part_of_speech, frequency_rank, level_id) VALUES
-- A1 (level 1)
(gen_random_uuid(), 'water',     'A clear liquid that people and animals drink',        'su',            '/ˈwɔːtər/',     'noun',         5,  1),
(gen_random_uuid(), 'friend',    'A person you know well and like',                     'arkadaş',       '/frend/',       'noun',         6,  1),
(gen_random_uuid(), 'happy',     'Feeling pleasure or joy',                             'mutlu',         '/ˈhæpi/',       'adjective',    7,  1),
(gen_random_uuid(), 'small',     'Not large in size',                                   'küçük',         '/smɔːl/',       'adjective',    8,  1),
(gen_random_uuid(), 'run',       'To move quickly on your feet',                        'koşmak',        '/rʌn/',         'verb',         9,  1),
(gen_random_uuid(), 'book',      'A set of printed pages you read',                     'kitap',         '/bʊk/',         'noun',         14, 1),
(gen_random_uuid(), 'open',      'To make something no longer closed',                  'açmak',         '/ˈoʊpən/',      'verb',         15, 1),
(gen_random_uuid(), 'cold',      'Having a low temperature',                            'soğuk',         '/koʊld/',       'adjective',    16, 1),
(gen_random_uuid(), 'morning',   'The early part of the day',                           'sabah',         '/ˈmɔːrnɪŋ/',    'noun',         17, 1),
(gen_random_uuid(), 'walk',      'To move on your feet at a normal speed',              'yürümek',       '/wɔːk/',        'verb',         18, 1),
(gen_random_uuid(), 'family',    'A group of people related to each other',             'aile',          '/ˈfæməli/',     'noun',         19, 1),
(gen_random_uuid(), 'help',      'To make it easier for someone to do something',       'yardım etmek',  '/help/',        'verb',         20, 1),

-- A2 (level 2)
(gen_random_uuid(), 'travel',    'To go from one place to another, often far',          'seyahat etmek', '/ˈtrævəl/',     'verb',         21, 2),
(gen_random_uuid(), 'decide',    'To make a choice after thinking',                     'karar vermek',  '/dɪˈsaɪd/',     'verb',         22, 2),
(gen_random_uuid(), 'careful',   'Giving attention to avoid mistakes or danger',        'dikkatli',      '/ˈkerfəl/',     'adjective',    23, 2),
(gen_random_uuid(), 'healthy',   'In good physical condition',                          'sağlıklı',      '/ˈhelθi/',      'adjective',    24, 2),
(gen_random_uuid(), 'market',    'A place where people buy and sell goods',             'pazar',         '/ˈmɑːrkɪt/',    'noun',         25, 2),
(gen_random_uuid(), 'remember',  'To keep something in your mind',                      'hatırlamak',    '/rɪˈmembər/',   'verb',         26, 2),
(gen_random_uuid(), 'invite',    'To ask someone to come somewhere',                    'davet etmek',   '/ɪnˈvaɪt/',     'verb',         27, 2),
(gen_random_uuid(), 'prepare',   'To get something ready',                              'hazırlamak',    '/prɪˈper/',     'verb',         28, 2),
(gen_random_uuid(), 'comfortable','Giving a pleasant, relaxed feeling',                 'rahat',         '/ˈkʌmftəbəl/',  'adjective',    29, 2),
(gen_random_uuid(), 'language',   'A system of words used to communicate',              'dil',           '/ˈlæŋɡwɪdʒ/',   'noun',         30, 2),
(gen_random_uuid(), 'busy',      'Having a lot to do',                                  'meşgul',        '/ˈbɪzi/',       'adjective',    31, 2),
(gen_random_uuid(), 'repair',    'To fix something that is broken',                     'tamir etmek',   '/rɪˈper/',      'verb',         32, 2),

-- B1 (level 3)
(gen_random_uuid(), 'consider',  'To think about something carefully',                  'göz önünde bulundurmak','/kənˈsɪdər/','verb',     54, 3),
(gen_random_uuid(), 'available', 'Able to be used or obtained',                         'mevcut',        '/əˈveɪləbəl/',  'adjective',    55, 3),
(gen_random_uuid(), 'recognize', 'To know someone or something you have seen before',   'tanımak',       '/ˈrekəɡnaɪz/',  'verb',         56, 3),
(gen_random_uuid(), 'encourage', 'To give someone confidence or support',              'cesaretlendirmek','/ɪnˈkɜːrɪdʒ/','verb',         57, 3),
(gen_random_uuid(), 'sufficient','As much as is needed',                                'yeterli',       '/səˈfɪʃənt/',   'adjective',    58, 3),
(gen_random_uuid(), 'attitude',  'A way of thinking or feeling about something',        'tutum',         '/ˈætɪtuːd/',    'noun',         59, 3),
(gen_random_uuid(), 'generate',  'To produce or create something',                      'üretmek',       '/ˈdʒenəreɪt/',  'verb',         60, 3),
(gen_random_uuid(), 'reliable',  'Able to be trusted to do what is expected',           'güvenilir',     '/rɪˈlaɪəbəl/',  'adjective',    61, 3),
(gen_random_uuid(), 'occasion',  'A particular time when something happens',            'durum, vesile', '/əˈkeɪʒən/',    'noun',         62, 3),
(gen_random_uuid(), 'persuade',  'To make someone agree by giving reasons',             'ikna etmek',    '/pərˈsweɪd/',   'verb',         63, 3),
(gen_random_uuid(), 'maintain',  'To keep something in good condition',                 'sürdürmek',     '/meɪnˈteɪn/',   'verb',         64, 3),
(gen_random_uuid(), 'frequent',  'Happening often',                                     'sık',           '/ˈfriːkwənt/',  'adjective',    65, 3),

-- B2 (level 4)
(gen_random_uuid(), 'comprehensive','Including everything that is necessary',           'kapsamlı',      '/ˌkɑːmprɪˈhensɪv/','adjective', 204, 4),
(gen_random_uuid(), 'deliberate', 'Done on purpose; intentional',                       'kasıtlı',       '/dɪˈlɪbərət/',  'adjective',    205, 4),
(gen_random_uuid(), 'inevitable', 'Certain to happen; unavoidable',                     'kaçınılmaz',    '/ɪnˈevɪtəbəl/', 'adjective',    206, 4),
(gen_random_uuid(), 'substantial','Large in amount or importance',                      'önemli, hatırı sayılır','/səbˈstænʃəl/','adjective',207, 4),
(gen_random_uuid(), 'coherent',   'Logical and clearly connected',                      'tutarlı',       '/koʊˈhɪrənt/',  'adjective',    208, 4),
(gen_random_uuid(), 'advocate',   'To publicly support an idea or plan',                'savunmak',      '/ˈædvəkeɪt/',   'verb',         209, 4),
(gen_random_uuid(), 'diminish',   'To make or become smaller or less',                  'azaltmak',      '/dɪˈmɪnɪʃ/',    'verb',         210, 4),
(gen_random_uuid(), 'plausible',  'Seeming reasonable or probable',                     'makul',         '/ˈplɔːzəbəl/',  'adjective',    211, 4),
(gen_random_uuid(), 'anticipate', 'To expect something and prepare for it',             'öngörmek',      '/ænˈtɪsɪpeɪt/', 'verb',         212, 4),
(gen_random_uuid(), 'versatile',  'Able to be used in many different ways',             'çok yönlü',     '/ˈvɜːrsətəl/',  'adjective',    213, 4),

-- C1 (level 5)
(gen_random_uuid(), 'meticulous', 'Showing great attention to detail',                  'titiz',         '/məˈtɪkjələs/', 'adjective',    504, 5),
(gen_random_uuid(), 'ubiquitous', 'Present or found everywhere',                        'her yerde olan','/juːˈbɪkwɪtəs/','adjective',    505, 5),
(gen_random_uuid(), 'candid',     'Honest and direct in speech',                        'açık sözlü',    '/ˈkændɪd/',     'adjective',    506, 5),
(gen_random_uuid(), 'resilient',  'Able to recover quickly from difficulties',          'dirençli',      '/rɪˈzɪliənt/',  'adjective',    507, 5),
(gen_random_uuid(), 'articulate', 'Able to express ideas clearly',                      'iyi ifade eden','/ɑːrˈtɪkjələt/','adjective',    508, 5),
(gen_random_uuid(), 'prevalent',  'Widespread; common in a particular area',            'yaygın',        '/ˈprevələnt/',  'adjective',    509, 5),
(gen_random_uuid(), 'intricate',  'Very detailed and complicated',                      'karmaşık',      '/ˈɪntrɪkət/',   'adjective',    510, 5),
(gen_random_uuid(), 'alleviate',  'To make pain or a problem less severe',              'hafifletmek',   '/əˈliːvieɪt/',  'verb',         511, 5),
(gen_random_uuid(), 'tenacious',  'Holding firmly to a purpose; persistent',            'azimli',        '/təˈneɪʃəs/',   'adjective',    512, 5),
(gen_random_uuid(), 'paramount',  'More important than anything else',                  'en önemli',     '/ˈpærəmaʊnt/',  'adjective',    513, 5),

-- C2 (level 6)
(gen_random_uuid(), 'quintessential','Representing the most perfect example',           'tipik örnek',   '/ˌkwɪntɪˈsenʃəl/','adjective', 1004, 6),
(gen_random_uuid(), 'surreptitious','Done secretly to avoid being noticed',             'gizli',         '/ˌsɜːrəpˈtɪʃəs/','adjective',  1005, 6),
(gen_random_uuid(), 'magnanimous', 'Generous and forgiving, especially to a rival',     'âlicenap',      '/mæɡˈnænɪməs/', 'adjective',    1006, 6),
(gen_random_uuid(), 'pernicious',  'Having a harmful effect, often gradually',          'sinsi zararlı', '/pərˈnɪʃəs/',   'adjective',    1007, 6),
(gen_random_uuid(), 'ostensible',  'Stated as true but perhaps not real',               'görünürdeki',   '/ɑːˈstensəbəl/','adjective',    1008, 6),
(gen_random_uuid(), 'juxtapose',   'To place things close together for contrast',       'yan yana koymak','/ˈdʒʌkstəpoʊz/','verb',       1009, 6),
(gen_random_uuid(), 'salient',     'Most noticeable or important',                      'göze çarpan',   '/ˈseɪliənt/',   'adjective',    1010, 6),
(gen_random_uuid(), 'fastidious',  'Very attentive to detail; hard to please',          'müşkülpesent',  '/fæˈstɪdiəs/',  'adjective',    1011, 6),
(gen_random_uuid(), 'obfuscate',   'To make something unclear or hard to understand',   'bulanıklaştırmak','/ˈɑːbfəskeɪt/','verb',      1012, 6),
(gen_random_uuid(), 'vociferous',  'Expressing opinions loudly and forcefully',         'yaygaracı',     '/voʊˈsɪfərəs/', 'adjective',    1013, 6);

-- Distractor üret: distractor'ı olmayan her kelimeye, aynı seviyeden 3 farklı tanım.
INSERT INTO word_mcq_distractors (word_id, distractor)
SELECT w.id, d.definition
FROM words w
CROSS JOIN LATERAL (
    SELECT x.definition
    FROM words x
    WHERE x.level_id = w.level_id AND x.id <> w.id
    ORDER BY random()
    LIMIT 3
) d
WHERE NOT EXISTS (
    SELECT 1 FROM word_mcq_distractors md WHERE md.word_id = w.id
);
