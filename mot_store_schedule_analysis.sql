-- ============================================================
-- Анализ mot_store_schedule: сравнение plan_value/fact_value
-- с plan_time/fact_time
-- 
-- Задача: посчитать часы по клиенту и месяцу двумя способами
--   Вариант 1: Сумма числовых значений plan_value / fact_value
--   Вариант 2: Парсинг интервалов plan_time / fact_time ("HH:MM-HH:MM")
--
-- Разница = обеденный перерыв (обычно 1 час)
-- ============================================================

-- ============================================================
-- 1. Структура таблицы
-- ============================================================
SELECT 
    c.ORDINAL_POSITION,
    c.COLUMN_NAME,
    c.DATA_TYPE,
    c.CHARACTER_MAXIMUM_LENGTH,
    c.IS_NULLABLE,
    c.COLUMN_DEFAULT
FROM INFORMATION_SCHEMA.COLUMNS c
WHERE c.TABLE_CATALOG = 'mfportal'
  AND c.TABLE_SCHEMA = 'dbo'
  AND c.TABLE_NAME = 'mot_store_schedule'
ORDER BY c.ORDINAL_POSITION;

-- ============================================================
-- 2. Распределение plan_value по типам (числа vs коды)
-- ============================================================
SELECT 
    CASE 
        WHEN plan_value IS NULL THEN 'NULL'
        WHEN TRY_CAST(plan_value AS decimal) IS NOT NULL THEN 'NUMERIC'
        ELSE 'CODE'
    END AS plan_type,
    COUNT(*) AS cnt
FROM mfportal.dbo.mot_store_schedule
GROUP BY 
    CASE 
        WHEN plan_value IS NULL THEN 'NULL'
        WHEN TRY_CAST(plan_value AS decimal) IS NOT NULL THEN 'NUMERIC'
        ELSE 'CODE'
    END
ORDER BY cnt DESC;

-- ============================================================
-- 3. Распределение fact_value по типам
-- ============================================================
SELECT 
    CASE 
        WHEN fact_value IS NULL THEN 'NULL'
        WHEN TRY_CAST(fact_value AS decimal) IS NOT NULL THEN 'NUMERIC'
        ELSE 'CODE'
    END AS fact_type,
    COUNT(*) AS cnt
FROM mfportal.dbo.mot_store_schedule
GROUP BY 
    CASE 
        WHEN fact_value IS NULL THEN 'NULL'
        WHEN TRY_CAST(fact_value AS decimal) IS NOT NULL THEN 'NUMERIC'
        ELSE 'CODE'
    END
ORDER BY cnt DESC;

-- ============================================================
-- 4. Уникальные буквенные коды в plan_value / fact_value
-- ============================================================
SELECT DISTINCT plan_value AS code
FROM mfportal.dbo.mot_store_schedule
WHERE TRY_CAST(plan_value AS decimal) IS NULL
  AND plan_value IS NOT NULL
ORDER BY code;

SELECT DISTINCT fact_value AS code
FROM mfportal.dbo.mot_store_schedule
WHERE TRY_CAST(fact_value AS decimal) IS NULL
  AND fact_value IS NOT NULL
ORDER BY code;

-- ============================================================
-- 5. ОСНОВНОЙ ЗАПРОС: сравнение двух подходов
--    Агрегация по (year_num, month_num, klient_id)
-- ============================================================
WITH parsed AS (
    SELECT 
        year_num, 
        month_num, 
        klient_id,

        -- Вариант 1: числовое значение (NULL для буквенных кодов)
        TRY_CAST(plan_value AS decimal(10,4)) AS plan_val_num,
        TRY_CAST(fact_value AS decimal(10,4)) AS fact_val_num,

        -- Вариант 2: часы из временного интервала
        -- Формат: "HH:MM-HH:MM" → DATEDIFF в минутах / 60
        CASE 
            WHEN plan_time IS NOT NULL AND CHARINDEX('-', plan_time) > 0 THEN
                DATEDIFF(MINUTE, 
                    TRY_CAST(LEFT(plan_time, 5) AS time),
                    TRY_CAST(SUBSTRING(plan_time, CHARINDEX('-', plan_time) + 1, 5) AS time)
                ) / 60.0
            ELSE NULL 
        END AS plan_time_hours,

        CASE 
            WHEN fact_time IS NOT NULL AND CHARINDEX('-', fact_time) > 0 THEN
                DATEDIFF(MINUTE, 
                    TRY_CAST(LEFT(fact_time, 5) AS time),
                    TRY_CAST(SUBSTRING(fact_time, CHARINDEX('-', fact_time) + 1, 5) AS time)
                ) / 60.0
            ELSE NULL 
        END AS fact_time_hours

    FROM mfportal.dbo.mot_store_schedule
)
SELECT 
    year_num,
    month_num,
    klient_id,
    COUNT(*) AS row_count,

    -- plan: числа vs интервалы
    ROUND(SUM(plan_val_num), 4)    AS plan_sum_numeric,
    ROUND(SUM(plan_time_hours), 4) AS plan_sum_time,
    ROUND(SUM(plan_time_hours) - SUM(plan_val_num), 4) AS plan_delta,

    -- fact: числа vs интервалы  
    ROUND(SUM(fact_val_num), 4)    AS fact_sum_numeric,
    ROUND(SUM(fact_time_hours), 4) AS fact_sum_time,
    ROUND(SUM(fact_time_hours) - SUM(fact_val_num), 4) AS fact_delta

FROM parsed
GROUP BY year_num, month_num, klient_id
ORDER BY year_num, month_num, klient_id;

-- ============================================================
-- 6. Итоговые суммы по всей таблице
-- ============================================================
WITH parsed AS (
    SELECT 
        TRY_CAST(plan_value AS decimal(10,4)) AS plan_val_num,
        TRY_CAST(fact_value AS decimal(10,4)) AS fact_val_num,
        CASE 
            WHEN plan_time IS NOT NULL AND CHARINDEX('-', plan_time) > 0 THEN
                DATEDIFF(MINUTE, 
                    TRY_CAST(LEFT(plan_time, 5) AS time),
                    TRY_CAST(SUBSTRING(plan_time, CHARINDEX('-', plan_time) + 1, 5) AS time)
                ) / 60.0
            ELSE NULL 
        END AS plan_time_hours,
        CASE 
            WHEN fact_time IS NOT NULL AND CHARINDEX('-', fact_time) > 0 THEN
                DATEDIFF(MINUTE, 
                    TRY_CAST(LEFT(fact_time, 5) AS time),
                    TRY_CAST(SUBSTRING(fact_time, CHARINDEX('-', fact_time) + 1, 5) AS time)
                ) / 60.0
            ELSE NULL 
        END AS fact_time_hours
    FROM mfportal.dbo.mot_store_schedule
)
SELECT 
    ROUND(SUM(plan_val_num), 4)    AS plan_sum_numeric,
    ROUND(SUM(plan_time_hours), 4) AS plan_sum_time,
    ROUND(SUM(plan_time_hours) - SUM(plan_val_num), 4) AS plan_delta,
    ROUND(SUM(fact_val_num), 4)    AS fact_sum_numeric,
    ROUND(SUM(fact_time_hours), 4) AS fact_sum_time,
    ROUND(SUM(fact_time_hours) - SUM(fact_val_num), 4) AS fact_delta
FROM parsed;

-- ============================================================
-- 7. Распределение дельты (plan_time - plan_value)
--    Показывает, что основная дельта = 1 час (обед)
-- ============================================================
SELECT 
    delta_hours,
    COUNT(*) AS cnt
FROM (
    SELECT 
        ROUND(
            DATEDIFF(MINUTE, 
                TRY_CAST(LEFT(plan_time, 5) AS time),
                TRY_CAST(SUBSTRING(plan_time, CHARINDEX('-', plan_time) + 1, 5) AS time)
            ) / 60.0 
            - TRY_CAST(plan_value AS decimal(10,4)),
            2
        ) AS delta_hours
    FROM mfportal.dbo.mot_store_schedule
    WHERE plan_time IS NOT NULL 
      AND TRY_CAST(plan_value AS decimal) IS NOT NULL
) d
GROUP BY delta_hours
ORDER BY cnt DESC;
