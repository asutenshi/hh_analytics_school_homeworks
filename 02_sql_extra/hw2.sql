-- ============================================================
-- Домашнее задание к лекции «Продвинутый SQL»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Шишкин Артём Дмитриевич
-- ============================================================
-- Формат: один .sql файл, задания по порядку, каждое начинается
-- с комментария с номером. Под каждым итоговым запросом — контрольные
-- значения и короткий вывод в комментариях.
-- Вывод — обязательная часть задания.
-- ============================================================
--
-- Шаблон sql файла с условиями заданий был сгенерирован на основе
-- шаблона из первого ДЗ. Финальное форматирование тоже было произведено
-- с помощью ИИ для единообразия и читаемости (говорю честно, не скрываю).
--

SET search_path TO hh_school;

SELECT
  'responses' table_name,
  count(*) rows_cnt
FROM responses
UNION ALL
SELECT
  'calls',
  count(*)
FROM calls
UNION ALL
SELECT
  'messages',
  count(*)
FROM messages;
-- responses = 628   calls = 251   messages = 2862


-- ============================================================
-- БЛОК А. Качество и подготовка данных
-- ============================================================

-- ЗАДАНИЕ 1. Аудит качества данных (1,5 балла)
-- Исследовать таблицы calls и messages, найти записи, которые могут
-- исказить дальнейший анализ. Набор проверок определить самостоятельно.
-- Подумать:
--  - можно ли корректно связать событие с откликом;
--  - согласуются ли идентификаторы в связанных таблицах;
--  - может ли событие находиться в указанной точке времени относительно отклика;
--  - согласуются ли значения внутри одной строки;
--  - есть ли пропуски, которые понадобятся дальше;
--  - есть ли значения, заметно отличающиеся от основной массы.
--
-- Для каждого типа проблемы:
--  - количество строк;
--  - call_id / message_id проблемных записей;
--  - комментарий: влияет на сам факт коммуникации или только на атрибут события.

-- Проверка 1. Пропуски по колонкам calls
SELECT
  count(*) total_cnt,
  count(response_id) resp_cnt,
  count(employer_id) empl_cnt,
  count(applicant_id) applic_cnt,
  count(vacancy_id) vac_cnt,
  count(caller_role) caller_role_cnt,
  count(call_duration) call_duration_cnt,
  count(status) status_cnt,
  count(call_at) call_at_cnt,
  count(call_tags) call_tags_cnt
FROM calls;
-- total_cnt = 251, resp_cnt = 243, call_duration_cnt = 181, остальные = 251
--
-- Пропуски только в двух колонках:
--   response_id:   251 - 243 = 8 звонков без отклика;
--   call_duration: 251 - 181 = 70 звонков без длительности.

-- Проверка 2. Звонки без длительности
SELECT
  status,
  count(*) calls_cnt,
  count(call_duration) with_duration_cnt
FROM calls
WHERE call_duration IS NULL
GROUP BY status
ORDER BY calls_cnt DESC;
-- unsuccessful | 69 | 0
-- error        |  1 | 0
--
-- Комментарий: проблемой не является. Длительность пуста только у
-- неуспешных звонков (69) и звонка с ошибкой (1) — звонка, который не
-- состоялся, длительности быть не может. У всех 181 успешных звонков
-- длительность заполнена. Факт коммуникации не искажается: NULL в
-- call_duration надо просто не включать в расчёты.


-- Проверка 3. Звонки без response_id
SELECT
  call_id,
  status,
  call_duration,
  call_at
FROM calls
WHERE response_id IS NULL
ORDER BY call_id;
-- 8 строк. call_id:
--   неуспешные (5, длительности нет): 700244, 700245, 700246, 700249, 700250
--   успешные   (3, длительность есть): 700247 (66 с), 700248 (380 с), 700251 (356 с)
--
-- Комментарий: проблема влияет на сам факт коммуникации. Звонок реальный, но без
-- response_id его нельзя отнести к конкретному отклику.


-- Проверка 4. Пропуски по колонкам messages
SELECT
  count(*) total_cnt,
  count(response_id) resp_cnt,
  count(vacancy_id) vac_cnt,
  count(employer_id) empl_cnt,
  count(applicant_id) applic_cnt,
  count(sent_at) sent_at_cnt,
  count(sender_role) sender_role_cnt,
  count(message_text) message_text_cnt,
  count(message_meta) message_meta_cnt
FROM messages;
-- total_cnt = 2862, во всех остальных колонках тоже 2862
--
-- Пропусков нет ни в одной колонке. В том числе в response_id: в отличие
-- от звонков, каждое сообщение привязано к отклику.

-- Проверка 5. Сообщения без текста
SELECT
  sender_role,
  count(*) messages_cnt,
  count(*) FILTER (WHERE message_text IS NULL) null_text_cnt,
  count(*) FILTER (WHERE btrim(message_text) = '') empty_text_cnt
FROM messages
GROUP BY sender_role
ORDER BY sender_role;
-- applicant | 1431 | 0 | 0
-- employer  | 1431 | 0 | 0
--
-- Комментарий: проблемных записей нет. Текст есть у всех сообщений обеих
-- ролей; пустых строк и строк из одних пробелов тоже нет. Роли
-- распределены поровну (по 1431), message_id для списка не нужны.


-- Проверка 6. calls: совпадение vacancy_id и employer_id звонка с откликом
SELECT
  c.call_id,
  c.response_id,
  c.vacancy_id call_vacancy_id,
  r.vacancy_id response_vacancy_id,
  c.employer_id call_employer_id,
  v.employer_id vacancy_employer_id
FROM calls c
JOIN responses r ON r.response_id = c.response_id
JOIN vacancies v ON v.vacancy_id = r.vacancy_id
WHERE c.vacancy_id <> r.vacancy_id
  OR c.employer_id <> v.employer_id
ORDER BY c.call_id;
-- 0 строк
--
-- Комментарий: расхождений нет, звонки не «перепутаны» с чужими откликами,
-- вакансиями или работодателями. Проблемных записей нет.


-- Проверка 7. messages: совпадение vacancy_id и employer_id сообщения с откликом
SELECT
  m.message_id,
  m.response_id,
  m.vacancy_id message_vacancy_id,
  r.vacancy_id response_vacancy_id,
  m.employer_id message_employer_id,
  v.employer_id vacancy_employer_id
FROM messages m
JOIN responses r ON r.response_id = m.response_id
JOIN vacancies v ON v.vacancy_id = r.vacancy_id
WHERE m.vacancy_id <> r.vacancy_id
  OR m.employer_id <> v.employer_id
ORDER BY m.message_id;
-- 0 строк
--
-- Комментарий: расхождений нет, все сообщения согласованы с откликом.


-- Проверка 8. applicant_id: согласованность с откликом и между событиями
SELECT
  'calls' source,
  count(*) events_cnt,
  count(*) FILTER (WHERE e.applicant_id <> r.resume_id) mismatch_cnt
FROM calls e
JOIN responses r ON r.response_id = e.response_id
UNION ALL
SELECT
  'messages',
  count(*),
  count(*) FILTER (WHERE e.applicant_id <> r.resume_id)
FROM messages e
JOIN responses r ON r.response_id = e.response_id;
-- calls    | 243  | 0
-- messages | 2862 | 0
--
-- Дополнительно: откликов, у которых в событиях больше одного applicant_id
-- (отдельно по звонкам и по сообщениям, а также между ними) = 0.
--
-- Комментарий: applicant_id события везде равен resume_id отклика, значит
-- по этой связи события не перепутаны.


-- Проверка 9. calls: время звонка относительно отклика
SELECT
  c.call_id,
  c.response_id,
  c.call_at,
  r.created_at response_created_at
FROM calls c
JOIN responses r ON r.response_id = c.response_id
WHERE c.call_at < r.created_at
ORDER BY c.call_id;
-- 0 строк
--
-- Комментарий: звонков раньше отклика среди связанных с откликом нет.
-- Проблемных записей нет.


-- Проверка 10. messages: время сообщения относительно отклика
SELECT
  m.message_id,
  m.response_id,
  m.sent_at,
  r.created_at response_created_at
FROM messages m
JOIN responses r ON r.response_id = m.response_id
WHERE m.sent_at < r.created_at
ORDER BY m.message_id;
-- 0 строк
--
-- Комментарий: сообщений раньше отклика нет. Проблемных записей нет.


-- Проверка 11. calls: согласованность значений внутри строки
-- status сверяется с call_duration и техническими тегами, caller_role — с
-- тегом направления (inbound / outbound).
SELECT
  count(*) calls_cnt,
  count(*) FILTER (
    WHERE (status = 'successful') <> (call_duration IS NOT NULL)
  ) AS status_duration_mismatch,
  count(*) FILTER (
    WHERE (status = 'successful') <> ('connected' = ANY(call_tags))
      OR (status = 'unsuccessful') <> ('no_answer' = ANY(call_tags))
      OR (status = 'error') <> ('technical_error' = ANY(call_tags))
  ) AS status_tag_mismatch,
  count(*) FILTER (
    WHERE (caller_role = 'applicant') <> ('inbound' = ANY(call_tags))
      OR (caller_role = 'employer') <> ('outbound' = ANY(call_tags))
  ) AS role_tag_mismatch
FROM calls;
-- 251 | 0 | 0 | 0
--
-- Комментарий: противоречий нет: длительность есть ровно у успешных
-- звонков, технический тег соответствует статусу, тег направления
-- соответствует caller_role. Проблемных записей нет.

-- Проверка 12. calls: дубли
-- Дубль: несколько звонков, у которых совпадают все поля, кроме call_id.
SELECT
  response_id,
  employer_id,
  applicant_id,
  vacancy_id,
  caller_role,
  call_duration,
  status,
  call_at,
  call_tags,
  count(*) calls_cnt
FROM calls
GROUP BY response_id, employer_id, applicant_id, vacancy_id, caller_role,
  call_duration, status, call_at, call_tags
HAVING count(*) > 1
ORDER BY response_id;
-- 0 строк
--
-- Комментарий: дублей нет. Совпадений по response_id и call_at тоже нет.


-- Проверка 13. messages: дубли
-- Дубль: несколько сообщений, у которых совпадают все поля, кроме message_id.
SELECT
  response_id,
  vacancy_id,
  employer_id,
  applicant_id,
  sent_at,
  sender_role,
  message_text,
  message_meta,
  count(*) messages_cnt,
  array_agg(message_id ORDER BY message_id) message_ids
FROM messages
GROUP BY response_id, vacancy_id, employer_id, applicant_id, sent_at,
  sender_role, message_text, message_meta
HAVING count(*) > 1
ORDER BY response_id;
-- 0 строк
--
-- Комментарий: дублей нет. Одинаковых текстов внутри одного отклика
-- у одной роли тоже нет.

-- Отдельно call_duration успешных звонков (там, где значение можно
-- содержательно интерпретировать):
--  - средняя длительность;
--  - медиана;
--  - 99-й перцентиль;
--  - количество звонков выше 99-го перцентиля;
--  - средняя длительность без значений выше 99-го перцентиля.

-- Длительность успешных звонков:
WITH stats AS (
  SELECT
    percentile_cont(0.99) WITHIN GROUP (ORDER BY call_duration) p99_duration
  FROM calls
  WHERE status = 'successful'
)
SELECT
  count(*) calls_cnt,
  round(avg(c.call_duration), 1) avg_duration,
  percentile_cont(0.5) WITHIN GROUP (ORDER BY c.call_duration) p50_duration,
  s.p99_duration,
  count(*) FILTER (WHERE c.call_duration > s.p99_duration) above_p99_cnt,
  round(avg(c.call_duration) FILTER (WHERE c.call_duration <= s.p99_duration), 1)
 avg_duration_without_outliers
FROM calls c
CROSS JOIN stats s
WHERE c.status = 'successful'
GROUP BY s.p99_duration;
-- calls_cnt = 181, avg = 467.3, p50 = 438, p99 = 890.4,
-- выше p99 = 2 звонка, avg без значений выше p99 = 462.5


-- Вывод:
-- Найденные проблемы и контрольные значения:
-- 1. 8 звонков без response_id (700244, 700245, 700246, 700247, 700248,
--    700249, 700250, 700251). Их нельзя отнести ни к одному отклику, это
--    влияет на сам факт коммуникации после отклика. Исключаю их из
--    аналитического слоя.
-- 2. 70 звонков без call_duration (69 неуспешных и 1 с ошибкой) не
--    проблема: у неуспешного звонка длительности быть не может. Просто не
--    учитываю их в расчётах длительности.
-- Длительность успешных звонков (181): среднее 467,3 с, медиана 438 с,
-- p99 = 890,4 с, выше p99 два звонка (700159 — 892 с, 700199 — 899 с),
-- среднее без них 462,5 с.
--
-- Значения выше p99 — ошибки или допустимые выбросы? Как поступил бы
-- при расчёте типичной длительности звонка:
-- Считаю допустимыми значениями, а не ошибками. Длительность распределена
-- равномерно от 51 до 899 с, 892 и 899 с лежат внутри этого диапазона
-- и от остальных не отделены: p99 отсекает 2 звонка из 181 просто по
-- определению. После исключения среднее меняется всего с 467,3 до 462,5 с.
-- Для типичной длительности беру медиану (438 с): она не зависит от
-- крайних значений, и исключать звонки выше p99 не нужно.


-- ============================================================
-- БЛОК Б. История коммуникаций
-- ============================================================

-- ЗАДАНИЕ 2. Единый слой коммуникаций (0,5 балла)
-- Единый слой коммуникаций со стороны работодателя в первые 7 дней после отклика.
--  - решение декомпозировать с помощью CTE (подготовка исходных таблиц
--    и объединение событий — разные логические этапы);
--  - использовать результаты аудита из задания 1: не включать события,
--    которым нельзя доверять как факту коммуникации после конкретного отклика;
--  - гранулярность: одна строка = одно событие;
--  - колонки минимум: response_id, employer_id, event_id, event_at,
--    event_type (call или message).
-- Итоговым запросом — четыре контрольных значения:
--  общее количество событий, количество различных откликов
--  с коммуникацией, количество звонков, количество сообщений.

WITH calls_form AS (
  SELECT
    c.response_id,
    c.employer_id,
    c.call_id event_id,
    c.call_at event_at,
    'call' event_type
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id event_id,
    m.sent_at event_at,
    'message' event_type
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM calls_form
  UNION ALL
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM messages_form
)
SELECT
  count(*) events_cnt,
  count(DISTINCT response_id) responses_cnt,
  count(*) FILTER (WHERE event_type = 'call') calls_cnt,
  count(*) FILTER (WHERE event_type = 'message') messages_cnt
FROM events;

-- Контрольные значения:
--   всего событий = 1096
--   различных откликов с коммуникацией = 382
--   звонков = 108
--   сообщений = 988
-- Вывод:
-- Работодатели общаются с кандидатами в основном письменно: звонков около
-- десятой части событий. В первую неделю на связь выходят примерно по трём
-- откликам из пяти, по остальным работодатель за 7 дней не написал и не позвонил.
-- Неуспешные звонки (недозвоны) я оставил в слое: это попытка связаться
-- по конкретному отклику, и аудит не нашёл причин ей не доверять. Из-за этого
-- доля откликов, где разговор действительно состоялся, ниже доли откликов
-- с коммуникацией.


-- ЗАДАНИЕ 3. Таймлайн коммуникаций и витрина отклика (1,5 балла)
-- Шаг 1. Слой уровня события (гранулярность таблицы не меняется).
-- Для каждого события определить:
--  - порядковый номер события внутри отклика;
--  - время предыдущего события;
--  - тип следующего события;
--  - количество коммуникаций от начала истории до текущего события включительно;
--  - тип первой коммуникации по отклику;
--  - тип последней коммуникации по отклику.
-- Если у нескольких событий одинаковое время — устойчивый порядок:
-- сначала event_type, затем event_id.
WITH calls_form AS (
  SELECT
    c.response_id,
    c.employer_id,
    c.call_id event_id,
    c.call_at event_at,
    'call' event_type
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id event_id,
    m.sent_at event_at,
    'message' event_type
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM calls_form
  UNION ALL
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM messages_form
)
SELECT
  response_id,
  employer_id,
  event_id,
  event_at,
  event_type,
  row_number() OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  ) AS event_num,
  lag(event_at) OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  ) AS prev_event_at,
  lead(event_type) OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  ) AS next_event_type,
  count(*) OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
  ) AS comms_cnt_to_date,
  first_value(event_type) OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
  ) AS first_event_type,
  last_value(event_type) OVER (
    PARTITION BY response_id
    ORDER BY event_at, event_type, event_id
    ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
  ) AS last_event_type
FROM events;


-- Шаг 2. Витрина уровня отклика (одна строка = один response_id).
-- Колонки минимум:
--  - response_id, employer_id, professional_role;
--  - статус отклика;
--  - количество коммуникаций, звонков и сообщений;
--  - время первой коммуникации;
--  - тип первой, второй и последней коммуникации;
--  - время от отклика до первой коммуникации в часах;
--  - максимальный интервал между соседними коммуникациями в часах.
-- Подводный камень: отклики без коммуникаций не должны исчезнуть из витрины.
WITH calls_form AS (
  SELECT
    c.response_id,
    c.employer_id,
    c.call_id event_id,
    c.call_at event_at,
    'call' event_type
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id event_id,
    m.sent_at event_at,
    'message' event_type
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM calls_form
  UNION ALL
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM messages_form
), numbered AS (
  SELECT
    response_id,
    event_type,
    event_at,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS rn_asc,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at DESC, event_type DESC, event_id DESC
    ) AS rn_desc,
    event_at - lag(event_at) OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS gap
  FROM events
), resp_events AS (
  SELECT
    response_id,
    count(*) communication_cnt,
    count(*) FILTER (WHERE event_type = 'call') calls_cnt,
    count(*) FILTER (WHERE event_type = 'message') messages_cnt,
    min(event_at) first_event_at,
    max(event_type) FILTER (WHERE rn_asc = 1) first_event_type,
    max(event_type) FILTER (WHERE rn_asc = 2) second_event_type,
    max(event_type) FILTER (WHERE rn_desc = 1) last_event_type,
    max(extract(epoch FROM gap)) / 3600 max_gap_hours
  FROM numbered
  GROUP BY response_id
)
SELECT
  r.response_id,
  v.employer_id,
  v.professional_role,
  r.status,
  coalesce(e.communication_cnt, 0) communication_cnt,
  coalesce(e.calls_cnt, 0) calls_cnt,
  coalesce(e.messages_cnt, 0) messages_cnt,
  e.first_event_at,
  e.first_event_type,
  e.second_event_type,
  e.last_event_type,
  extract(epoch FROM e.first_event_at - r.created_at) / 3600 hours_to_first_comm,
  e.max_gap_hours
FROM responses r
JOIN vacancies v ON v.vacancy_id = r.vacancy_id
LEFT JOIN resp_events e ON e.response_id = r.response_id;


-- Итоговый запрос по витрине:
--  - количество строк;
--  - количество откликов с коммуникацией;
--  - количество откликов без коммуникации;
--  - количество откликов, где первой коммуникацией было сообщение;
--  - количество откликов, где первой коммуникацией был звонок.
WITH calls_form AS (
  SELECT
    c.response_id,
    c.employer_id,
    c.call_id event_id,
    c.call_at event_at,
    'call' event_type
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id event_id,
    m.sent_at event_at,
    'message' event_type
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM calls_form
  UNION ALL
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM messages_form
), numbered AS (
  SELECT
    response_id,
    event_type,
    event_at,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS rn_asc,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at DESC, event_type DESC, event_id DESC
    ) AS rn_desc,
    event_at - lag(event_at) OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS gap
  FROM events
), resp_events AS (
  SELECT
    response_id,
    count(*) communication_cnt,
    count(*) FILTER (WHERE event_type = 'call') calls_cnt,
    count(*) FILTER (WHERE event_type = 'message') messages_cnt,
    min(event_at) first_event_at,
    max(event_type) FILTER (WHERE rn_asc = 1) first_event_type,
    max(event_type) FILTER (WHERE rn_asc = 2) second_event_type,
    max(event_type) FILTER (WHERE rn_desc = 1) last_event_type,
    max(extract(epoch FROM gap)) / 3600 max_gap_hours
  FROM numbered
  GROUP BY response_id
), mart AS (
  SELECT
    r.response_id,
    v.employer_id,
    v.professional_role,
    r.status,
    coalesce(e.communication_cnt, 0) communication_cnt,
    coalesce(e.calls_cnt, 0) calls_cnt,
    coalesce(e.messages_cnt, 0) messages_cnt,
    e.first_event_at,
    e.first_event_type,
    e.second_event_type,
    e.last_event_type,
    extract(epoch FROM e.first_event_at - r.created_at) / 3600 hours_to_first_comm,
    e.max_gap_hours
  FROM responses r
  JOIN vacancies v ON v.vacancy_id = r.vacancy_id
  LEFT JOIN resp_events e ON e.response_id = r.response_id
)
SELECT
  count(*) rows_cnt,
  count(*) FILTER (WHERE communication_cnt > 0) with_comm_cnt,
  count(*) FILTER (WHERE communication_cnt = 0) without_comm_cnt,
  count(*) FILTER (WHERE first_event_type = 'message') first_message_cnt,
  count(*) FILTER (WHERE first_event_type = 'call') first_call_cnt
FROM mart;

-- Контрольные значения:
--   строк = 628
--   откликов с коммуникацией = 382
--   откликов без коммуникации = 246
--   первая коммуникация — сообщение = 314
--   первая коммуникация — звонок = 68
-- Вывод:
-- Заметная часть откликов остаётся без ответа в первую неделю. Это отдельный
-- сегмент для разбора: работодатель не обрабатывает поток либо вакансия
-- неактуальна. Первым шагом работодатели почти всегда пишут, а не звонят:
-- сообщение дешевле, не требует совпадения по времени и не упирается в недозвон.
-- Дальше общение в основном продолжается перепиской, звонок вторым шагом
-- редкость. Если же первым был звонок, то по значительной части таких откликов
-- дальнейшей коммуникации нет вовсе: вероятно, звонок оказался неуспешным
-- а к сообщению работодатель не перешёл. Поэтому долю звонков как первого контакта
-- нельзя читать как долю состоявшихся разговоров.


-- ============================================================
-- БЛОК В. Сравнение работодателей
-- ============================================================

-- ЗАДАНИЕ 4. Рейтинг работодателей внутри направления (1 балл)
-- По витрине из задания 3 для каждой пары professional_role + employer_id:
--  - количество откликов;
--  - количество откликов с коммуникацией в первые 7 дней;
--  - доля таких откликов, %;
--  - медиана времени до первой коммуникации (по откликам, где она была);
--  - 90-й перцентиль времени до первой коммуникации (по тем же откликам);
--  - конверсия отклика в приглашение, %.
-- В рейтинг — только пары, где не менее 8 откликов.
-- Место внутри каждого направления:
--  1. выше — работодатель с большей долей обработанных откликов;
--  2. при равенстве выше — с меньшей медианой времени до первой коммуникации;
--  3. одинаковым значениям обоих критериев — одинаковое место,
--     следующее место идёт без пропуска номера.
-- Оставить только работодателей на 1-м и 2-м месте в своём направлении.
WITH calls_form AS (
  SELECT
    c.response_id,
    c.employer_id,
    c.call_id event_id,
    c.call_at event_at,
    'call' event_type
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id event_id,
    m.sent_at event_at,
    'message' event_type
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM calls_form
  UNION ALL
  SELECT response_id, employer_id, event_id, event_at, event_type
  FROM messages_form
), numbered AS (
  SELECT
    response_id,
    event_type,
    event_at,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS rn_asc,
    row_number() OVER (
      PARTITION BY response_id
      ORDER BY event_at DESC, event_type DESC, event_id DESC
    ) AS rn_desc,
    event_at - lag(event_at) OVER (
      PARTITION BY response_id
      ORDER BY event_at, event_type, event_id
    ) AS gap
  FROM events
), resp_events AS (
  SELECT
    response_id,
    count(*) communication_cnt,
    count(*) FILTER (WHERE event_type = 'call') calls_cnt,
    count(*) FILTER (WHERE event_type = 'message') messages_cnt,
    min(event_at) first_event_at,
    max(event_type) FILTER (WHERE rn_asc = 1) first_event_type,
    max(event_type) FILTER (WHERE rn_asc = 2) second_event_type,
    max(event_type) FILTER (WHERE rn_desc = 1) last_event_type,
    max(extract(epoch FROM gap)) / 3600 max_gap_hours
  FROM numbered
  GROUP BY response_id
), mart AS (
  SELECT
    r.response_id,
    v.employer_id,
    v.professional_role,
    r.status,
    coalesce(e.communication_cnt, 0) communication_cnt,
    coalesce(e.calls_cnt, 0) calls_cnt,
    coalesce(e.messages_cnt, 0) messages_cnt,
    e.first_event_at,
    e.first_event_type,
    e.second_event_type,
    e.last_event_type,
    extract(epoch FROM e.first_event_at - r.created_at) / 3600 hours_to_first_comm,
    e.max_gap_hours
  FROM responses r
  JOIN vacancies v ON v.vacancy_id = r.vacancy_id
  LEFT JOIN resp_events e ON e.response_id = r.response_id
), pairs AS (
  SELECT
    professional_role,
    employer_id,
    count(*) resp_cnt,
    count(*) FILTER (WHERE communication_cnt > 0) resp_with_comm_cnt,
    100.0 * count(*) FILTER (WHERE communication_cnt > 0) / count(*) resp_with_comm_prc,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm) first_comm_median,
    percentile_cont(0.9) WITHIN GROUP (ORDER BY hours_to_first_comm) first_comm_p90,
    100.0 * count(*) FILTER (WHERE status = 'invited') / count(*) invite_conv
  FROM mart
  GROUP BY professional_role, employer_id
  HAVING count(*) >= 8
), ranked AS (
  SELECT
    professional_role,
    employer_id,
    resp_cnt,
    resp_with_comm_cnt,
    resp_with_comm_prc,
    first_comm_median,
    first_comm_p90,
    invite_conv,
    dense_rank() OVER (
      PARTITION BY professional_role
      ORDER BY resp_with_comm_prc DESC, first_comm_median
    ) AS place
  FROM pairs
)
SELECT
  professional_role,
  employer_id,
  resp_cnt,
  resp_with_comm_cnt,
  round(resp_with_comm_prc, 1) resp_with_comm_prc,
  round(first_comm_median::numeric, 1) first_comm_median,
  round(first_comm_p90::numeric, 1) first_comm_p90,
  round(invite_conv, 1) invite_conv,
  place
FROM ranked
WHERE place <= 2
ORDER BY professional_role, place, employer_id;
-- professional_role    | employer_id | откликов | с комм. | % с комм. | медиана ч | p90 ч | конверсия % | место
-- Аналитик данных      | 109 | 19 | 17 | 89.5 | 57.0 | 137.2 | 15.8 | 1
-- Аналитик данных      | 103 | 79 | 67 | 84.8 | 54.3 | 148.7 | 10.1 | 2
-- Дата-инженер         | 106 | 10 |  7 | 70.0 |  9.7 | 109.6 | 10.0 | 1
-- Дата-инженер         | 101 | 24 | 11 | 45.8 | 76.3 | 144.7 | 12.5 | 2
-- Продуктовый аналитик | 103 | 31 | 22 | 71.0 | 55.9 | 145.8 | 12.9 | 1
-- Продуктовый аналитик | 102 | 59 | 38 | 64.4 | 74.0 | 147.5 | 11.9 | 2
-- Разработчик          | 112 | 24 | 20 | 83.3 | 52.6 | 124.2 | 12.5 | 1
-- Разработчик          | 104 | 45 | 36 | 80.0 | 30.8 | 128.4 | 20.0 | 2
-- Тестировщик          | 107 | 17 | 15 | 88.2 | 34.5 |  92.7 | 41.2 | 1
-- Тестировщик          | 108 |  8 |  5 | 62.5 |  5.7 | 108.4 | 37.5 | 2
--
-- Без фильтра place <= 2 в рейтинг попадают 18 пар. Не вошли в топ 8 пар:
-- Аналитик данных      | 110 |  41 | 29 | 70.7 | 49.3 | 146.4 | 12.2 | 3
-- Аналитик данных      | 104 |   9 |  6 | 66.7 | 87.6 | 114.6 |  0.0 | 4
-- Аналитик данных      | 101 | 115 | 53 | 46.1 | 51.0 | 106.6 |  8.7 | 5
-- Аналитик данных      | 102 |  50 | 18 | 36.0 | 78.9 | 134.9 | 24.0 | 6
-- Продуктовый аналитик | 110 |  13 |  3 | 23.1 |  7.5 |   9.5 |  7.7 | 3
-- Разработчик          | 101 |  17 | 11 | 64.7 | 54.7 | 130.0 | 23.5 | 3
-- Разработчик          | 106 |  53 | 15 | 28.3 | 53.7 | 115.5 | 15.1 | 4
-- Тестировщик          | 105 |   8 |  4 | 50.0 | 55.8 | 108.5 | 12.5 | 3

-- Контрольные значения (professional_role | место | employer_id):
--   Аналитик данных      | 1 | 109
--   Аналитик данных      | 2 | 103
--   Дата-инженер         | 1 | 106
--   Дата-инженер         | 2 | 101
--   Продуктовый аналитик | 1 | 103
--   Продуктовый аналитик | 2 | 102
--   Разработчик          | 1 | 112
--   Разработчик          | 2 | 104
--   Тестировщик          | 1 | 107
--   Тестировщик          | 2 | 108
-- Вывод:
-- Доля обработанных откликов и скорость первого контакта почти не связаны:
-- самые быстрые по медиане работодатели (108 у тестировщиков, 110 у продуктовых
-- аналитиков) отвечают быстро лишь тем, кого обработали, а обрабатывают
-- меньшую часть. Из-за порядка критериев (сначала доля, потом скорость)
-- такие работодатели оказываются ниже в рейтинге.
-- Конверсия в приглашение с рейтингом совпадает не везде: у аналитиков данных
-- работодатель 102 последний по обработке, но приглашает чаще остальных.
-- Возможно, он отбирает отклики избирательно или приглашает вне переписки
-- первой недели. Это гипотеза, из расчёта она не следует.


-- ЗАДАНИЕ 5. Скорость ответа работодателя в переписке (0,5 балла)
-- Использовать сообщения, которые корректно связываются с откликом
-- и произошли в первые 7 дней после него.
-- Для каждого сообщения определить, кто и когда отправил предыдущее
-- сообщение в рамках того же отклика. Найти случаи, когда сообщение
-- работодателя идёт непосредственно после сообщения кандидата;
-- для каждой такой пары посчитать время ответа работодателя в часах.
-- Для каждого работодателя:
--  - количество измеренных ответов;
--  - среднее время ответа;
--  - медиана времени ответа;
--  - 90-й перцентиль времени ответа.
-- Результат отсортировать по медиане по возрастанию.
WITH messages_7d AS (
  SELECT
    m.response_id,
    m.employer_id,
    m.message_id,
    m.sender_role,
    m.sent_at
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), with_prev AS (
  SELECT
    employer_id,
    sender_role,
    sent_at,
    lag(sender_role) OVER (
      PARTITION BY response_id
      ORDER BY sent_at, message_id
    ) AS prev_sender_role,
    lag(sent_at) OVER (
      PARTITION BY response_id
      ORDER BY sent_at, message_id
    ) AS prev_sent_at
  FROM messages_7d
), replies AS (
  SELECT
    employer_id,
    extract(epoch FROM sent_at - prev_sent_at) / 3600 reply_hours
  FROM with_prev
  WHERE sender_role = 'employer'
    AND prev_sender_role = 'applicant'
)
SELECT
  employer_id,
  count(*) replies_cnt,
  round(avg(reply_hours), 1) avg_reply_hours,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY reply_hours)::numeric, 1) median_reply_hours,
  round(percentile_cont(0.9) WITHIN GROUP (ORDER BY reply_hours)::numeric, 1) p90_reply_hours
FROM replies
GROUP BY employer_id
ORDER BY median_reply_hours, employer_id;
-- employer_id | ответов | avg | median | p90
--   107 |  28 | 9.4 | 3.9 | 19.9
--   108 |   8 | 6.4 | 4.1 | 13.4
--   110 |  59 | 7.5 | 4.1 | 19.1
--   109 |  35 | 6.9 | 4.4 | 17.9
--   106 |  48 | 7.1 | 4.5 | 18.9
--   103 | 171 | 7.9 | 4.6 | 19.6
--   104 |  85 | 7.4 | 4.6 | 19.0
--   105 |   6 | 6.2 | 4.6 | 13.0
--   101 | 161 | 7.4 | 4.7 | 18.7
--   112 |  43 | 8.6 | 4.7 | 19.3
--   102 | 105 | 9.2 | 4.9 | 20.2

-- Контрольные значения:
--   общее количество найденных ответов = 749
--   employer_id с минимальной медианой = 107
--   значение его медианы = 3.9 ч
-- Вывод:
-- В уже начатой переписке работодатели отвечают быстро и почти одинаково:
-- разброс медиан между работодателями меньше часа. Среднее у всех заметно
-- выше медианы, значит есть хвост ответов на следующий день. На фоне задания
-- 4 видно, что работодатели различаются тем, отвечают ли они на отклик 
-- вообще и как скоро, а не скоростью ответа внутри диалога.
-- Учитываются только ответы, которые были. Сообщение кандидата
-- без ответа в метрику не попадает, поэтому работодатель, который часто
-- молчит, может выглядеть быстрым. Если кандидат пишет несколько сообщений
-- подряд, время считается от последнего. Ответ звонком не учитывается.
-- У 105 и 108 мало ответов, их места в сортировке случайны.


-- ============================================================
-- БЛОК Г. Сложные типы данных
-- ============================================================

-- ЗАДАНИЕ 6.1. Теги звонков (1 балл на оба подпункта)
-- Звонки работодателя в первые 7 дней после отклика.
-- call_tags исследовать как массив, не преобразуя его целиком в строку.
-- Сначала проверить, согласуются ли технические теги звонка с его status.
-- Строки с противоречием в статистике по тегам не участвуют.
-- Затем количество звонков для каждого бизнес-тега:
--  screening, interview, follow_up, details.
-- Дополнительно:
--  - количество валидных звонков, содержащих хотя бы один из этих бизнес-тегов;
--  - среднее количество тегов на один валидный звонок.

-- Проверка: согласуются ли технические теги со status.
WITH employer_calls AS (
  SELECT
    c.call_id,
    c.status,
    c.call_tags
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
)
SELECT
  status,
  count(*) calls_cnt,
  count(*) FILTER (
    WHERE (status = 'successful') <> ('connected' = ANY(call_tags))
      OR (status = 'unsuccessful') <> ('no_answer' = ANY(call_tags))
      OR (status = 'error') <> ('technical_error' = ANY(call_tags))
  ) AS mismatch_cnt
FROM employer_calls
GROUP BY status
ORDER BY status;
-- error        |  1 | 0
-- successful   | 78 | 0
-- unsuccessful | 29 | 0


-- Статистика по бизнес-тегам среди валидных звонков.
WITH employer_calls AS (
  SELECT
    c.call_id,
    c.status,
    c.call_tags
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), valid_calls AS (
  SELECT call_id, call_tags
  FROM employer_calls
  WHERE (status = 'successful') = ('connected' = ANY(call_tags))
    AND (status = 'unsuccessful') = ('no_answer' = ANY(call_tags))
    AND (status = 'error') = ('technical_error' = ANY(call_tags))
)
SELECT
  count(*) valid_calls_cnt,
  count(*) FILTER (WHERE 'screening' = ANY(call_tags)) screening_cnt,
  count(*) FILTER (WHERE 'interview' = ANY(call_tags)) interview_cnt,
  count(*) FILTER (WHERE 'follow_up' = ANY(call_tags)) follow_up_cnt,
  count(*) FILTER (WHERE 'details' = ANY(call_tags)) details_cnt,
  count(*) FILTER (
    WHERE 'screening' = ANY(call_tags)
      OR 'interview' = ANY(call_tags)
      OR 'follow_up' = ANY(call_tags)
      OR 'details' = ANY(call_tags)
  ) AS with_business_tag_cnt,
  round(avg(cardinality(call_tags)), 2) avg_tags_per_call
FROM valid_calls;
-- valid_calls_cnt = 108   screening_cnt = 25   interview_cnt = 31
-- follow_up_cnt = 29   details_cnt = 23   with_business_tag_cnt = 108
-- avg_tags_per_call = 4.00

-- Контрольные значения:
--   screening = 25   interview = 31   follow_up = 29   details = 23
--   валидных звонков с бизнес-тегом = 108
--   среднее число тегов на валидный звонок = 4.00
-- Вывод:
-- Противоречий между status и техническими тегами нет, в статистику попали
-- все звонки работодателя из слоя задания 2. Сумма по бизнес-тегам равна
-- числу звонков, а тегов у каждого звонка ровно четыре: голосовой, технический,
-- направление и один бизнес-тег. Теги проставлены по жёсткому шаблону, поэтому
-- звонок с несколькими целями так описать нельзя. Цели распределены
-- почти равномерно, без явно доминирующего сценария. Бизнес-тег стоит и
-- на неуспешных звонках, то есть он описывает цель звонка, а не то, что
-- произошло: interview на недозвоне не означает проведённого интервью.


-- ЗАДАНИЕ 6.2. Метаданные сообщений
-- Сообщения работодателя в первые 7 дней после отклика.
-- Из message_meta извлечь: канал отправки, признак прочтения,
-- количество вложений.
-- Для каждого канала:
--  - количество сообщений;
--  - количество сообщений, где признак прочтения присутствует;
--  - количество непрочитанных сообщений;
--  - доля непрочитанных среди сообщений с известным признаком прочтения;
--  - количество сообщений хотя бы с одним вложением;
--  - доля сообщений с вложением.
-- Если канал в метаданных отсутствует — выделить такие сообщения
-- в отдельную группу.
WITH employer_messages AS (
  SELECT
    m.message_id,
    m.message_meta ->> 'channel' channel,
    (m.message_meta ->> 'is_read')::boolean is_read,
    coalesce(jsonb_array_length(m.message_meta -> 'attachments'), 0) attachments_cnt
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
)
SELECT
  coalesce(channel, 'unknown') channel,
  count(*) messages_cnt,
  count(is_read) with_read_flag_cnt,
  count(*) FILTER (WHERE NOT is_read) unread_cnt,
  round(100.0 * count(*) FILTER (WHERE NOT is_read) / nullif(count(is_read), 0), 1) unread_prc,
  count(*) FILTER (WHERE attachments_cnt > 0) with_attachments_cnt,
  round(100.0 * count(*) FILTER (WHERE attachments_cnt > 0) / count(*), 1) with_attachments_prc
FROM employer_messages
GROUP BY coalesce(channel, 'unknown')
ORDER BY messages_cnt DESC;

-- Контрольные значения по каналам:
--   channel    | сообщений | с признаком прочтения | непрочитанных | % непрочит. | с вложением | % с вложением
--   web        | 628 | 628 | 52 |  8.3 | 25 | 4.0
--   mobile_app | 360 | 360 | 36 | 10.0 | 14 | 3.9
--   сообщений без канала нет, группа unknown пустая
-- Вывод:
-- Метаданные заполнены полностью, поэтому группа без канала и сообщения без
-- признака прочтения в результат не попали. Основной канал работодателей — веб.
-- Непрочитанных в мобильном приложении чуть больше, но разница составляет
-- несколько сообщений и вполне может быть случайной. Вложения редки и
-- встречаются в обоих каналах одинаково часто.


-- ============================================================
-- БЛОК Д. Самостоятельное исследование
-- ============================================================

-- ЗАДАНИЕ 7. Что связано с приглашением? (2,5 балла)
-- Вопрос продукта: отличаются ли коммуникации по откликам, которые
-- заканчиваются приглашением, от коммуникаций по остальным откликам —
-- и если отличаются, то чем именно.
--
-- До написания SQL — две проверяемые гипотезы:
--   Гипотеза 1: по откликам с приглашением работодатель чаще выходит на связь
--     в первые 7 дней и делает это быстрее, чем по остальным откликам.
--   Гипотеза 2: приглашению чаще предшествует «живой» двусторонний контакт:
--     среди откликов с коммуникацией у приглашённых чаще есть успешный звонок
--     работодателя и ответное сообщение кандидата.
--
-- Требования:
--  - не менее трёх характеристик коммуникации;
--  - характеристики описывают минимум два разных аспекта коммуникации;
--  - минимум один расчёт новый: показатель или разрез, напрямую не
--    запрошенный в заданиях 1–6;
--  - для каждой сравниваемой группы показать количество откликов,
--    на котором рассчитаны показатели;
--  - каждая гипотеза завершается выводом «подтверждается»,
--    «не подтверждается» или «данных недостаточно» и опирается на числа.
-- Подводный камень: простое повторение показателей или рейтингов из
-- предыдущих заданий без нового расчёта не засчитывается.
--
-- Выбранные показатели и разрезы:
--   Разрез: invited (status = 'invited') против остальных (new, viewed, rejected).
--   1) охват и скорость: доля откликов с коммуникацией работодателя в первые
--      7 дней и медиана часов до первой коммуникации;
--   2) интенсивность: среднее число коммуникаций работодателя на отклик
--      с коммуникацией;
--   3) канал: доля откликов с коммуникацией, где был
--      хотя бы один успешный звонок работодателя;
--   4) двусторонность: доля откликов с коммуникацией,
--      где кандидат тоже написал хотя бы одно сообщение в первые 7 дней.
WITH calls_form AS (
  SELECT
    c.response_id,
    c.call_at event_at,
    c.status = 'successful' is_successful_call
  FROM calls c
  JOIN responses r ON r.response_id = c.response_id
  WHERE c.caller_role = 'employer'
    AND c.call_at >= r.created_at
    AND c.call_at <= r.created_at + INTERVAL '7 days'
), messages_form AS (
  SELECT
    m.response_id,
    m.sent_at event_at,
    FALSE is_successful_call
  FROM messages m
  JOIN responses r ON r.response_id = m.response_id
  WHERE m.sender_role = 'employer'
    AND m.sent_at >= r.created_at
    AND m.sent_at <= r.created_at + INTERVAL '7 days'
), events AS (
  SELECT response_id, event_at, is_successful_call
  FROM calls_form
  UNION ALL
  SELECT response_id, event_at, is_successful_call
  FROM messages_form
), resp_events AS (
  SELECT
    response_id,
    count(*) communication_cnt,
    min(event_at) first_event_at,
    count(*) FILTER (WHERE is_successful_call) > 0 has_successful_call
  FROM events
  GROUP BY response_id
), mart AS (
  SELECT
    r.response_id,
    CASE WHEN r.status = 'invited' THEN 'invited' ELSE 'other' END response_group,
    coalesce(e.communication_cnt, 0) communication_cnt,
    extract(epoch FROM e.first_event_at - r.created_at) / 3600 hours_to_first_comm,
    coalesce(e.has_successful_call, FALSE) has_successful_call,
    e.response_id IS NOT NULL
      AND EXISTS (
        SELECT 1
        FROM messages am
        WHERE am.response_id = r.response_id
          AND am.sender_role = 'applicant'
          AND am.sent_at >= r.created_at
          AND am.sent_at <= r.created_at + INTERVAL '7 days'
      ) AS is_two_way
  FROM responses r
  LEFT JOIN resp_events e ON e.response_id = r.response_id
)
SELECT
  response_group,
  count(*) responses_cnt,
  count(*) FILTER (WHERE communication_cnt > 0) with_comm_cnt,
  round(100.0 * count(*) FILTER (WHERE communication_cnt > 0) / count(*), 1) with_comm_prc,
  round(percentile_cont(0.5) WITHIN GROUP (ORDER BY hours_to_first_comm)::numeric, 1) median_hours_to_first_comm,
  round(avg(communication_cnt) FILTER (WHERE communication_cnt > 0), 2) avg_comm_cnt,
  round(
    100.0 * count(*) FILTER (WHERE has_successful_call)
      / count(*) FILTER (WHERE communication_cnt > 0),
    1
  ) AS successful_call_prc,
  round(
    100.0 * count(*) FILTER (WHERE is_two_way)
      / count(*) FILTER (WHERE communication_cnt > 0),
    1
  ) AS two_way_prc
FROM mart
GROUP BY response_group
ORDER BY response_group;

-- Результаты:
--   группа  | откликов | с коммуникацией | % с комм. | медиана ч до 1-й | комм. на отклик | % с усп. звонком | % двусторонних
--   invited |  92 |  54 | 58.7 | 51.1 | 2.78 | 22.2 | 87.0
--   other   | 536 | 328 | 61.2 | 54.7 | 2.88 | 19.5 | 90.5
--   Доли по звонку и двусторонности посчитаны от откликов с коммуникацией
--   (54 и 328): успешный звонок у 12 и 64, двусторонняя переписка у 47 и 297.
-- Вывод:
-- Гипотеза 1: не подтверждается. Приглашённые отклики обрабатываются
-- в первую неделю даже чуть реже остальных, а первый контакт по ним
-- случается лишь на несколько часов раньше при медиане около двух суток.
-- Обе разницы соответствуют одному-двум откликам из 92, это шум.
-- Гипотеза 2: не подтверждается. Успешный звонок у приглашённых встречается
-- чуть чаще, но разница меньше двух откликов. Двусторонняя переписка,
-- наоборот, встречается чуть реже. Интенсивность коммуникации тоже одинакова.
-- Итого по всем четырём показателям коммуникации первой недели приглашённые
-- отклики не отличаются от остальных. Возможно, приглашение определяется
-- не коммуникацией, а профилем кандидата и требованиями вакансии, или
-- происходит уже после окна 7 дней.


-- ============================================================
-- ИТОГ
-- ============================================================

-- ЗАДАНИЕ 8. Итог исследования (1,5 балла)
-- Единый итог для продакт-менеджера на основе заданий 1–7, 7–10 предложений.
-- Обязательно:
--  - не менее четырёх конкретных числовых результатов минимум из трёх разных заданий;
--  - вывод о том, как в целом работодатели взаимодействуют с откликами после их получения;
--  - вывод о различиях между работодателями или профессиональными направлениями;
--  - вывод о том, какие особенности коммуникации связаны с приглашением (по заданию 7);
--  - минимум одно ограничение проведённого анализа;
--  - один следующий исследовательский вопрос: что ещё посчитать или
--    какие дополнительные данные запросить.
-- Не пересказывать таблицы по порядку: связать расчёты в одну картину
-- и отделить наблюдаемую связь от причинно-следственного вывода.
--
-- Итог:
-- В первую неделю после отклика работодатели выходят на связь примерно
-- по 61% откликов (382 из 628) и почти всегда начинают с сообщения:
-- 314 первых контактов против 68 звонков. Узкое место — первый контакт,
-- а не диалог: медиана времени до первой коммуникации около 54 часов,
-- тогда как на сообщение кандидата в начатой переписке работодатели
-- отвечают за 4–5 часов, и этот показатель почти одинаков у всех
-- (задание 5). Сильнее всего работодатели различаются охватом: в парах
-- «направление + работодатель» доля обработанных откликов составляет от 23 до 90%,
-- и большой поток откликов не гарантирует обработку. У работодателя 101
-- в аналитике данных обработано меньше половины из 115 откликов (задание 4).
-- По коммуникациям первой недели приглашённые отклики от остальных
-- не отличаются: с коммуникацией 58,7% против 61,2%, частота успешных
-- звонков и двусторонней переписки тоже близка (задание 7). Значит,
-- по этим данным нельзя утверждать, что быстрый или активный контакт
-- связан с приглашением, и тем более что он к приглашению приводит.
-- Главное ограничение: статус отклика известен только на момент выгрузки,
-- без даты, а коммуникации ограничены 7 днями, поэтому порядок событий
-- «контакт → приглашение» не установлен. Кроме того, приглашённых откликов
-- всего 92, а в слое остаются неуспешные звонки.
