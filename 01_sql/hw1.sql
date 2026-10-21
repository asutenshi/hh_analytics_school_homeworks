-- ============================================================
-- Домашнее задание к лекции «SQL. Введение»
-- Школа Аналитиков · учебная база hh_school
-- Автор: Шишкин Артём Дмитриевич
-- ============================================================
-- Формат: задания по порядку, каждое начинается с комментария
-- с номером; под каждым запросом — вывод (2–3 предложения).
-- Запрос без вывода не засчитывается.
-- ============================================================

SET search_path TO hh_school;
SELECT 'areas' AS table_name, count(*) AS rows FROM areas
UNION ALL SELECT 'employers',       count(*) FROM employers
UNION ALL SELECT 'vacancies',       count(*) FROM vacancies
UNION ALL SELECT 'vacancy_details', count(*) FROM vacancy_details
UNION ALL SELECT 'responses',       count(*) FROM responses
UNION ALL SELECT 'calls',           count(*) FROM calls
UNION ALL SELECT 'messages',        count(*) FROM messages;

-- ============================================================
-- БЛОК А. Разминка: термины и структура (текстом)
-- ============================================================

-- ЗАДАНИЕ А1
-- 1. Категория и конкретный тип колонок:
--    vacancies.salary_from        — категория: числовой        тип: INT
--    vacancies.vacancy_name       — категория: строковый       тип: *TEXT
--    vacancies.published_at       — категория: дата и время    тип: DATETIME
--    employers.is_accredited_it   — категория: логический      тип: BOOLEAN
--    responses.created_at         — категория: дата и время    тип: DATETIME
--
--    *:
--    TEXT в PostgreSQL хранит строку любой длины. VARCHAR без (n) ведёт себя
--    так же, а VARCHAR(n) дополнительно проверяет длину. На скорость это не влияет.
--
-- 2. Первичные ключи таблиц:
--    areas: area_id
--    employers: employer_id
--    vacancies: vacancy_id
--    vacancy_details: vacancy_id (чем особенный: повторяет первичный ключ из vacancy, чтобы обеспечить одну строку информации на одну вакансию; первичный ключ сразу является и внешним ключом)
--    responses: response_id
--
-- 3. Почему vacancy_name не может быть первичным ключом:
--    Название вакансии может повторяться от записи к записи
--    Запрос для подтверждения числом:

--    Запрос:
SELECT vacancy_name, count(vacancy_name) AS count
FROM vacancies
GROUP BY vacancy_name
ORDER BY count DESC
LIMIT 1;

--    Вывод:
--    vacancy_name | count
--    Стажёр: аналитик данных | 6

--    Интерпретация:
--    Первичный ключ обязан быть уникальным для каждой строки.
--    Название вакансии не может служить первичным ключом, так как оно дублируется:
--    самое частое название "Стажёр: аналитик данных" встречается 6 раз.
--    Если бы мы назначили vacancy_name первичным ключом, то база не позволила бы
--    создать несколько одноименных вакансий от разных работадателей (или в рамках одного работадателя).
--
-- 4. Что произойдёт при записи строки «по договорённости» в salary_from:
--    Получим ошибку, ведь мы не можем записать строковый тип в колонку типа INT.
--    Это хорошо, ведь мы избегаем смешивания типов данных в рамках колонки,
--    которое бы усложнило нам работу с агрегирующими функциями

--    Запрос
--    INSERT INTO vacancies (vacancy_id, employer_id, area_id, vacancy_name, professional_role, experience,
--    employment, salary_from, salary_to, currency, published_at, closed_at) VALUES
--    (100001, 101, 1, 'Стажёр: аналитик данных', 'Аналитик данных', 'Нет опыта', 'Стажировка', 35000, 'по договорённости', 'RUR', TIMESTAMP '2026-05-14 06:00:00', NULL);

--    Вывод:
--    ERROR: invalid input syntax for type integer: "по договорённости"
-- 


-- ============================================================
-- БЛОК Б. Первые запросы: SELECT, WHERE, ORDER BY
-- ============================================================

-- ЗАДАНИЕ Б1
-- Запрос: experience
select
  experience,
  count(*) as cnt
from vacancies
GROUP BY experience
ORDER BY cnt desc, experience;
-- Нет опыта	28
-- От 1 года до 3 лет	15
-- От 3 до 6 лет	9

-- Запрос: employment
select
  employment,
  count(*) as cnt
from vacancies
GROUP BY employment
ORDER BY cnt desc, employment;
-- Полная занятость	28
-- Стажировка	19
-- Частичная занятость	5

-- Запрос: professional_role
select
  professional_role,
  count(*) as cnt
from vacancies
GROUP BY professional_role
ORDER BY cnt desc, professional_role;
-- Аналитик данных	16
-- Разработчик	15
-- Дата-инженер	7
-- Продуктовый аналитик	7
-- Тестировщик	7

-- Вывод:
-- В колонке опыта и типе занятости по 3 уникальных значения, а в
-- колонке профессий 5 уникальных значений.
-- Проблемы: как учитывать вакансии, которые требуют более 6 лет опыта?
-- (если такие в теории могут быть);
-- возможно разница между значениями стажировка и частичная занятость не совсем понятны
-- (и стажировка и частичная занятость может бы по 20 часов в неделю);
-- по идее аналитик данных может включать в себя профессию продуктовый аналитик.
-- NULL у нас нет ни в одной из этих колонок, так как GROUP BY выводит и NULL группу тоже


-- ЗАДАНИЕ Б2
-- Запрос 1: стажировки в Москве без опыта, вакансия открыта
select
  v.vacancy_id,
  v.vacancy_name,
  v.salary_from,
  v.published_at
  -- ar.area_name,
  -- v.experience,
  -- v.closed_at
from vacancies v
join areas ar on v.area_id = ar.area_id
where v.experience = 'Нет опыта'
  and ar.area_name = 'Москва'
  and v.employment = 'Стажировка'
  and v.closed_at is NULL
ORDER BY v.published_at DESC;

-- Запрос 2: топ-10 вакансий по salary_from
select
  vacancy_id,
  vacancy_name,
  professional_role,
  salary_from
  -- убедился, что все зарплаты в рублях
  -- currency
from vacancies
where salary_from is not NULL
ORDER BY salary_from desc, vacancy_id
limit 10;


-- Вывод:
-- Открытых стажировок в Москве без опыта 8. Это 42% от всех стажировок
-- в базе (8 из 19) и 80% открытых стажировок без опыта (8 из 10; без
-- условия про Москву запрос вернул бы 10 строк), то есть почти все такие
-- вакансии сосредоточены в Москве. Но свежих среди них нет: самая новая
-- опубликована 03.06.2026, а последние публикации в базе датированы
-- 29.07.2026, то есть откликаться нужно быстро, часть уже может быть неактуальна.
--
-- В топ-10 по нижней границе зарплаты лидирует Senior разработчик
-- (от 195 000), за ним Senior дата-инженер (190 000). Все зарплаты в RUR,
-- поэтому сравнение корректно.
--


-- ЗАДАНИЕ Б3
-- Ловушка 1. NULL — выполнить и объяснить результат
SELECT count(*) FROM vacancies WHERE closed_at = NULL; -- 0
SELECT count(*) FROM vacancies WHERE closed_at IS NULL; -- 33

-- Ловушка 2. AND / OR — выполнить и объяснить результат
SELECT count(*) FROM vacancies
WHERE area_id = 1 OR area_id = 2 AND experience = 'Нет опыта'; -- 31

SELECT count(*) FROM vacancies
WHERE (area_id = 1 OR area_id = 2) AND experience = 'Нет опыта'; -- 20

-- Вывод:
-- Ловушка 1. Сравнение любого значения с NULL даёт UNKNOWN, а WHERE
-- пропускает только TRUE, поэтому closed_at = NULL не вернул ни одной
-- строки (0), хотя открытых вакансий 33. Ошибки при этом нет: запрос
-- выполняется и показывает правдоподобный «0». Это опаснее ошибки, потому
-- что ошибку сразу видно, а неверное число легко принять за ответ
-- («открытых вакансий нет») и использовать в выводах.
-- Содержательно NULL в closed_at означает, что вакансия ещё открыта.
--
-- Ловушка 2. AND имеет более высокий приоритет, чем OR, поэтому первое
-- условие читается как: area_id = 1 (Москва, любая вакансия, в том числе
-- с опытом) ИЛИ (area_id = 2 (Санкт-Петербург) И experience = 'Нет опыта').
-- Так получилось 31 строка вместо 20: добавились 11 московских вакансий
-- с опытом.
-- На вопрос «вакансии из Москвы или Санкт-Петербурга, но обязательно без
-- опыта» отвечает второй запрос, со скобками (20 вакансий): скобки
-- заставляют сначала выполнить OR, а потом применить AND к обоим городам.
select * from areas where area_id in (1, 2);
-- 1	Москва	Центральный ФО
-- 2	Санкт-Петербург	Северо-Западный ФО



-- ============================================================
-- БЛОК В. Агрегации и метрики
-- ============================================================

-- ЗАДАНИЕ В1
-- Запрос 1: счётчики (строки, зарплата указана, направления, работодатели)
SELECT
  count(*) as row_cnt,
  count(salary_from) as vac_with_salary_from_cnt,
  count(DISTINCT professional_role) as prof_role_cnt,
  count(DISTINCT employer_id) as empl_cnt
FROM vacancies;
-- 52	44	5	12

-- Запрос 2: доля активных вакансий (без JOIN)
SELECT
  count(case when closed_at is null then 1 end) as open_cnt,
  count(closed_at) as closed_cnt,
  round((count(case when closed_at is null then 1 end) * 100.0) / count(*), 1) as open_perc
FROM vacancies;
-- 33	19	63.5


-- Вывод:
-- count(*) считает все строки таблицы: 52 вакансии. count(salary_from)
-- пропускает NULL и даёт 44: у 8 вакансий зарплата не указана.
-- count(DISTINCT professional_role) считает уникальные значения: 5 направлений,
-- count(DISTINCT employer_id) даёт 12 работодателей на 52 вакансии.
--
-- Ответ руководителю: сейчас открыто 33 из 52 вакансий (63,5%),
-- остальные 19 закрыты.


-- ЗАДАНИЕ В2
-- Запрос 1: направления — вакансии, работодатели, средняя зарплата
SELECT
  professional_role,
  count(DISTINCT vacancy_id) vacancy_cnt,
  count(DISTINCT employer_id) employer_cnt,
  round(avg(salary_from), 0) avg_salary_from
FROM vacancies
GROUP BY professional_role
ORDER BY count(vacancy_id) DESC;

-- Запрос 2: то же, только направления с ≥ 5 открытыми вакансиями (WHERE + HAVING)
SELECT
  professional_role,
  count(DISTINCT vacancy_id)  AS vacancy_cnt,
  count(DISTINCT employer_id) AS employer_cnt,
  round(avg(salary_from), 0)  AS avg_salary_from
FROM vacancies
WHERE closed_at IS NULL
GROUP BY professional_role
HAVING count(*) >= 5
ORDER BY vacancy_cnt DESC;

-- Вывод:
-- 1. Аналитик данных (11) и Разработчик (8) вместе дают 19 из 33 открытых
--    вакансий, то есть 58% рынка. Соискатель по этой таблице решил бы, что
--    лучше идти в аналитику или разработку, где больше всего предложений.
--    Но в таблице нет откликов: много вакансий не значит, что легко найти
--    работу, если на каждую приходят десятки откликов. Нет и конверсии в
--    приглашение, и динамики по времени, поэтому такой вывод не обоснован.
--
-- 2. Условие «только открытые» стоит в WHERE: оно отбирает строки до
--    группировки. Условие «не менее пяти» стоит в HAVING, потому что
--    count(*) считается по группе, то есть после GROUP BY. При записи
--    WHERE count(*) >= 5 будет ошибка: aggregate functions are not
--    allowed in WHERE.
--
-- 3. avg(salary_from) отвечает на вопрос «какая в среднем нижняя граница
--    зарплаты у открытых вакансий направления, где зарплата указана»
--    (NULL в среднем не участвуют). Он не отвечает, сколько реально
--    платят: это нижняя граница вилки, а не фактическая зарплата, и не
--    средняя по рынку, так как закрытые вакансии не учтены.



-- ============================================================
-- БЛОК Г. Соединение таблиц
-- ============================================================

-- ЗАДАНИЕ Г1
-- Запрос: топ-5 по salary_from с названием компании и городом (псевдонимы таблиц)
SELECT
  vacancy_name,
  employer_name,
  area_name,
  salary_from
FROM vacancies v
LEFT JOIN areas ar ON ar.area_id = v.area_id
LEFT JOIN employers em ON em.employer_id = v.employer_id
WHERE salary_from IS NOT NULL
ORDER BY salary_from DESC
LIMIT 5;

-- Вывод:
-- Все пять вакансий с самой высокой нижней границей зарплаты — Senior:
-- от 195 000 (Senior разработчик, «Северный Код», Санкт-Петербург) до
-- 140 000 (Senior аналитик данных, «ТехноБанк», Москва). Высокие
-- зарплаты не сосредоточены в одном городе: в топ-5 Санкт-Петербург,
-- Екатеринбург, Новосибирск и Москва. Это нижняя граница вилки, поэтому
-- реальные зарплаты могут быть выше.
--
-- Если убрать псевдонимы и написать просто area_id, база выдаст ошибку
-- column reference "area_id" is ambiguous: такая колонка есть сразу в
-- трёх таблицах запроса (vacancies, areas, employers), и без префикса
-- (псевдонима таблицы) СУБД не знает, какую из них взять.


-- ЗАДАНИЕ Г2
-- Запрос 1: все работодатели, число вакансий и откликов (LEFT JOIN)
SELECT
  em.employer_name,
  count(DISTINCT vac.vacancy_id) vac_cnt,
  count(DISTINCT res.response_id) responses_cnt
FROM employers em
LEFT JOIN vacancies vac ON vac.employer_id = em.employer_id
LEFT JOIN responses res ON res.vacancy_id = vac.vacancy_id
GROUP BY employer_name
ORDER BY count(res.response_id) DESC;
-- total row cnt = 12

-- Запрос 2: тот же запрос с INNER JOIN
SELECT
  em.employer_name,
  count(DISTINCT vac.vacancy_id) vac_cnt,
  count(DISTINCT res.response_id) responses_cnt
FROM employers em
INNER JOIN vacancies vac ON vac.employer_id = em.employer_id
INNER JOIN responses res ON res.vacancy_id = vac.vacancy_id
GROUP BY employer_name
ORDER BY count(res.response_id) DESC;
-- total row cnt = 11

-- Запрос 3: единственная вакансия «ГринЭнерго» — что с ней не так
SELECT v.vacancy_id, v.vacancy_name, v.professional_role, v.experience,
       v.employment, v.salary_from, v.salary_to, v.published_at, v.closed_at,
       ar.area_name
FROM vacancies v
JOIN employers em ON em.employer_id = v.employer_id
JOIN areas ar ON ar.area_id = v.area_id
WHERE em.employer_name = 'ГринЭнерго';
-- 1043 | Стажёр: разработчик | Разработчик | Нет опыта | Стажировка |
-- salary_from NULL | salary_to NULL | 2026-04-06 | 2026-05-04 | Казань

-- Запрос 4: вакансии того же направления и число откликов на каждую
SELECT v.vacancy_id, v.vacancy_name, v.salary_from, v.published_at, v.closed_at,
       count(r.response_id) AS responses_cnt
FROM vacancies v
LEFT JOIN responses r ON r.vacancy_id = v.vacancy_id
WHERE v.professional_role = (
    SELECT v2.professional_role
    FROM vacancies v2
    JOIN employers em ON em.employer_id = v2.employer_id
    WHERE em.employer_name = 'ГринЭнерго')
GROUP BY v.vacancy_id, v.vacancy_name, v.salary_from, v.published_at, v.closed_at
ORDER BY responses_cnt DESC;
-- 15 вакансий; без откликов 4: 1043, 1042, 1032, 1041
-- стажировки «Стажёр: разработчик»: 27, 9, 6, 0, 0 откликов

-- Вывод:
-- Вакансий на работодателя считаем через count(DISTINCT vacancy_id): после
-- JOIN с responses у вакансии столько строк, сколько у неё откликов, и
-- count(*) посчитал бы строки соединения, то есть отклики, а не вакансии.
-- Кроме того, у работодателя без откликов LEFT JOIN оставляет одну строку
-- с NULL, и count(*) выдал бы 1 вместо 0.
--
-- LEFT JOIN вернул 12 работодателей, INNER JOIN только 11: исчезла
-- компания «ГринЭнерго» (1 вакансия, 0 откликов). INNER JOIN такие
-- случаи скрывает, а HR они важны.
--
-- Запросы 3 и 4 показывают, что именно у неё не так. Единственная
-- вакансия (1043, стажёр-разработчик в Казани) уже закрыта: опубликована
-- 06.04.2026, закрыта 04.05.2026, то есть была открыта 28 дней, и
-- зарплата в ней не указана. Но зарплата сама по себе ноль не объясняет:
-- у вакансий этого направления без зарплаты есть отклики (14 и 6), а
-- стажировка 1042 с зарплатой 50 000 тоже осталась без откликов. Среди
-- пяти стажировок «Стажёр: разработчик» откликов 27, 9, 6, 0 и 0, то есть
-- интерес к ним сильно неравномерный.
-- Итог: можно утверждать, что вакансия была закрытой без единого отклика
-- при отсутствии зарплаты, но причину по данным установить нельзя.
--
-- Правило: если вопрос про «у кого мало или нет» и нулевое значение
-- метрики важно, беру LEFT JOIN от основной сущности (работодателя).
-- INNER JOIN беру, когда нужны только те, у кого связанные записи есть,
-- и работодатели без них не интересны.


-- ============================================================
-- БЛОК Д. Функции и финальный кейс
-- ============================================================

-- ЗАДАНИЕ Д1
-- Запрос: помесячная динамика откликов и конверсия
-- (месяц как дата, условный агрегат, nullif в знаменателе)
SELECT date_trunc('month', created_at)::date AS month,
  count(*) AS responses_cnt,
  count(*) FILTER (WHERE status = 'invited') AS invited_cnt,
  round(100.0 * count(*) FILTER (WHERE status = 'invited')
    / nullif(count(*), 0), 1) AS conversion_pct
FROM responses
GROUP BY 1 ORDER BY 1;

-- Проверка: до какой даты есть данные в responses
SELECT max(created_at) FROM responses;
-- 2026-08-15 08:00:00


-- Вывод:
-- Максимальная конверсия в июне: 19,5% (23 приглашения на 118 откликов).
-- Это один из самых больших месяцев, так что число не случайное,
-- но отрыв от февраля (18,2%) и января (16,7%) всего 1–3 п.п., и по
-- такой разнице нельзя говорить, что в июне «легче всего» получить
-- приглашение. Для планирования набора можно опираться лишь на то, что
-- конверсия колеблется в диапазоне ~13–20%.
--
-- Последний месяц (август) в таблице неполный: по запросу max(created_at)
-- данные в responses заканчиваются 15.08.2026 (08:00), это всего 41 отклик
-- и 3 приглашения.
-- Минимум 7,3% получен на крошечной выборке и неполном месяце,
-- поэтому август лучше исключить из выводов.


-- ЗАДАНИЕ Д2
-- Запрос: таблица по направлениям (вакансии, отклики, приглашения,
-- откликов на вакансию, конверсия)
SELECT
  vac.professional_role,
  count(DISTINCT vac.vacancy_id) vacancy_cnt,
  count(res.response_id) responses_cnt,
  count(CASE WHEN res.status = 'invited' THEN 1 END) invited_cnt,
  round(count(res.response_id)::NUMERIC
    / NULLIF(count(DISTINCT vac.vacancy_id), 0), 1) responses_per_vacancy,
  round(100.0 * count(CASE WHEN res.status = 'invited' THEN 1 END)
    / NULLIF(count(res.response_id), 0), 1) conversion_pct
FROM vacancies vac
LEFT JOIN responses res ON res.vacancy_id = vac.vacancy_id
GROUP BY vac.professional_role
ORDER BY vacancy_cnt DESC;

-- Письменные ответы:
-- 1. Совпадает ли направление с наибольшим числом вакансий с направлением
--    с наибольшей конверсией?
--    Нет, не совпадает. У направления Аналитик данных наибольшее количество вакансий (16).
--    У направления Тестировщик наивысшая конверсия (35,9%), но мало вакансий (7) и откликов (39)
--
-- 2. Какое направление выбрать и почему (опираясь на два столбца):
--    Я бы выбрал Разработчика. Откликов на вакансию (responses_per_vacancy)
--    у разработчиков 9,3 против 19,6 у аналитиков данных, то есть конкуренция
--    за одно место вдвое ниже, а конверсия отклика в приглашение
--    (conversion_pct) выше: 17,3% против 12,1%. Данных по направлению
--    достаточно (15 вакансий, 139 откликов), в отличие от Тестировщика
--    с 35,9%, где всего 39 откликов.
--
-- 3. Оговорка к выводу:
--    Выборка небольшая в абсолютных числах: 24 приглашения у разработчиков и 38 у аналитиков,
--    поэтому разница в конверсии (17,3% против 12,1%) может быть случайной.
--    Кроме того, конверсия считается от всех откликов, включая неразобранные (new, viewed):
--    у аналитиков их 49%, у разработчиков 33%, поэтому конверсия аналитиков занижена сильнее.
--    Если считать только решённые отклики (invited / (invited + rejected)), разница
--    сокращается до 25,8% против 23,8%.


-- ============================================================
-- БЛОК Е. Со звёздочкой
-- ============================================================

-- ЗАДАНИЕ Е1
-- Исходный запрос (выполнить и посмотреть результат):
SELECT v.professional_role,
count(*) AS vacancies,
sum(v.salary_from) AS total_salary,
count(r.response_id) / count(*) AS responses_per_vacancy
FROM vacancies v
JOIN responses r ON v.vacancy_id = r.vacancy_id
WHERE v.closed_at = NULL
GROUP BY 1;
--
-- Результат исходного запроса: 0 строк (из-за v.closed_at = NULL).
-- Если заменить на IS NULL, остальные ошибки становятся видны:
-- «vacancies» = 236 у аналитиков данных при 11 реальных вакансиях,
-- total_salary = 13 870 000 вместо 815 000, а responses_per_vacancy = 1
-- у всех направлений.
--
-- Ошибки:
-- 1. v.closed_at = NULL -> v.closed_at IS NULL: сравнение с NULL всегда
--    UNKNOWN, запрос возвращает 0 строк.
-- 2. count(*) после JOIN считает отклики, а не вакансии (236 вместо 11)
--    -> count(DISTINCT v.vacancy_id).
-- 3. sum(v.salary_from) после JOIN завышена: зарплата повторяется по числу
--    откликов (13 870 000 вместо 815 000) -> сначала агрегировать отклики
--    в подзапросе, затем соединять.
-- 4. count(r.response_id) / count(*): после JOIN оба считают одно и то же,
--    метрика равна 1; к тому же это целочисленное деление, дробная часть
--    теряется -> sum(rc.cnt)::NUMERIC / count(DISTINCT v.vacancy_id) и round.
-- 5. JOIN -> LEFT JOIN: иначе 6 открытых вакансий без откликов исчезают.

--
-- Исправленный запрос:
SELECT
  v.professional_role,
  count(DISTINCT v.vacancy_id) AS vacancies,
  round(avg(v.salary_from), 0) AS avg_salary_from,
  round(sum(rc.cnt)::NUMERIC / count(DISTINCT v.vacancy_id), 1) AS responses_per_vacancy
FROM vacancies v
LEFT JOIN (SELECT vacancy_id, count(*) as cnt FROM responses GROUP BY vacancy_id) rc
  ON v.vacancy_id = rc.vacancy_id
WHERE v.closed_at IS NULL
GROUP BY 1;
-- * Замечание к зарплате: в исходном запросе стояла sum(salary_from), но
--   сумма нижних границ по направлению смысла не имеет. Она растёт вместе
--   с числом вакансий и сравнивает размеры направлений, а не уровень
--   оплаты: у аналитиков данных сумма (815 000) больше, чем у разработчиков
--   (665 000), только потому что вакансий 11 против 8. Поэтому в
--   исправленном запросе выведена средняя нижняя граница: 74 091 у аналитиков против 95 000 у разработчиков.


-- Какие два правила из лекции защитили бы от этих ошибок при написании запроса:
-- 1. Пустоту проверяют только через IS NULL: сравнение с NULL никогда не истинно.
--    Если бы я написал closed_at IS NULL сразу, запрос не вернул бы ноль строк.
-- 2. При JOIN думай, что станет с одной строкой: LEFT JOIN, когда нельзя потерять строки основной таблицы,
--    а сущности считай через count(DISTINCT id).
--    Это защитило бы от count(*), который считает отклики вместо вакансий, и от потери вакансий без откликов.
