-- ============================================================
-- Анализ mot_store_schedule + план/факт время для Table_Fin_PL
-- ============================================================

-- Связь: mot_store_schedule.klient_id = 001 CodeCFO.CodeFOX

-- ============================================================
-- 1. Структура таблицы mot_store_schedule
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
-- 5. Агрегация часов из mot_store_schedule по магазину+месяцу
--    (используется как CTE для JOIN в основной запрос)
-- ============================================================
WITH store_hours AS (
    SELECT 
        klient_id,
        year_num,
        month_num,

        -- plan: сумма чисел и сумма часов из интервалов
        ROUND(SUM(TRY_CAST(plan_value AS decimal(10,4))), 4)  AS plan_hours_numeric,
        ROUND(SUM(
            CASE 
                WHEN plan_time IS NOT NULL AND CHARINDEX('-', plan_time) > 0 THEN
                    DATEDIFF(MINUTE, 
                        TRY_CAST(LEFT(plan_time, 5) AS time),
                        TRY_CAST(SUBSTRING(plan_time, CHARINDEX('-', plan_time) + 1, 5) AS time)
                    ) / 60.0
                ELSE NULL 
            END
        ), 4) AS plan_hours_shift,

        -- fact: сумма чисел и сумма часов из интервалов
        ROUND(SUM(TRY_CAST(fact_value AS decimal(10,4))), 4)  AS fact_hours_numeric,
        ROUND(SUM(
            CASE 
                WHEN fact_time IS NOT NULL AND CHARINDEX('-', fact_time) > 0 THEN
                    DATEDIFF(MINUTE, 
                        TRY_CAST(LEFT(fact_time, 5) AS time),
                        TRY_CAST(SUBSTRING(fact_time, CHARINDEX('-', fact_time) + 1, 5) AS time)
                    ) / 60.0
                ELSE NULL 
            END
        ), 4) AS fact_hours_shift,

        COUNT(*) AS employee_days

    FROM mfportal.dbo.mot_store_schedule
    GROUP BY klient_id, year_num, month_num
)
SELECT * FROM store_hours
ORDER BY klient_id, year_num, month_num;

-- ============================================================
-- 6. ОСНОВНОЙ ЗАПРОС: Table_Fin_PL с плановым и фактическим временем
--    Добавлены колонки plan_hours_numeric, plan_hours_shift,
--    fact_hours_numeric, fact_hours_shift, employee_days
--    Связь: mot_store_schedule.klient_id = 001 CodeCFO.CodeFOX
--    (через cf: cf.CodeFOX = sh.klient_id)
-- ============================================================
WITH store_hours AS (
    SELECT 
        klient_id,
        year_num,
        month_num,
        ROUND(SUM(TRY_CAST(plan_value AS decimal(10,4))), 4)  AS plan_hours_numeric,
        ROUND(SUM(
            CASE 
                WHEN plan_time IS NOT NULL AND CHARINDEX('-', plan_time) > 0 THEN
                    DATEDIFF(MINUTE, 
                        TRY_CAST(LEFT(plan_time, 5) AS time),
                        TRY_CAST(SUBSTRING(plan_time, CHARINDEX('-', plan_time) + 1, 5) AS time)
                    ) / 60.0
                ELSE NULL 
            END
        ), 4) AS plan_hours_shift,
        ROUND(SUM(TRY_CAST(fact_value AS decimal(10,4))), 4)  AS fact_hours_numeric,
        ROUND(SUM(
            CASE 
                WHEN fact_time IS NOT NULL AND CHARINDEX('-', fact_time) > 0 THEN
                    DATEDIFF(MINUTE, 
                        TRY_CAST(LEFT(fact_time, 5) AS time),
                        TRY_CAST(SUBSTRING(fact_time, CHARINDEX('-', fact_time) + 1, 5) AS time)
                    ) / 60.0
                ELSE NULL 
            END
        ), 4) AS fact_hours_shift,
        COUNT(*) AS employee_days
    FROM mfportal.dbo.mot_store_schedule
    GROUP BY klient_id, year_num, month_num
)
SELECT 
    [Dr_Cr]
    ,t.[CodePL]
    ,t.[Country]
    ,[Month]
    ,[ВГО]
    ,SUM([AmountBYN]) AS AmountBYN
    ,SUM([Amount]) AS Amount
    ,SUM([AmountUSD]) AS AmountUSD
    ,SUM([AmountRUB]) AS AmountRUB
    ,[Scenario]
    ,t.[CodeCFO]
    ,t.[CFO]
    ,t.[GroupCFO1]
    ,t.[GroupCFO2]
    ,t.[GroupCFO3]
    ,[Метод.нюансы]
    ,[Для отчета]
    ,[GroupPL_new]
    ,[CF_item]
    ,[LFL_LISA]
    ,SUM([discount_amount_vat_BYN]) AS discount_amount_vat_BYN
    ,SUM([markdown_amount_vat_BYN]) AS markdown_amount_vat_BYN
    ,pl.GroupPL
    ,pl.Expense
    ,cf.Ploschad
    ,[RegManager]
    ,[DateOpen]
    ,[LfLStatus]
    ,[Компания]

    -- ==========================================
    -- Добавленные колонки планового/факт времени
    -- ==========================================
    ,COALESCE(sh.plan_hours_numeric, 0) AS plan_hours_numeric  -- чистые рабочие часы (без обеда)
    ,COALESCE(sh.plan_hours_shift, 0)   AS plan_hours_shift    -- время присутствия на смене (с обедом)
    ,COALESCE(sh.fact_hours_numeric, 0) AS fact_hours_numeric  -- чистые рабочие часы (без обеда)
    ,COALESCE(sh.fact_hours_shift, 0)   AS fact_hours_shift    -- время присутствия на смене (с обедом)
    ,COALESCE(sh.employee_days, 0)      AS employee_days       -- количество человеко-дней

FROM [FinDWH].[dbo].[Table_Fin_PL] t
LEFT JOIN [dbo].[002 CodePL] pl ON t.CodePL = pl.CodePL
LEFT JOIN [dbo].[001 CodeCFO] cf ON t.CodeCFO = cf.CodeCFO

-- LEFT JOIN агрегированных часов из mot_store_schedule
-- Связь: mot_store_schedule.klient_id = 001 CodeCFO.CodeFOX
LEFT JOIN store_hours sh 
    ON cf.CodeFOX = sh.klient_id
    AND sh.year_num = YEAR(t.Month)
    AND sh.month_num = MONTH(t.Month)

GROUP BY 
    [Dr_Cr], t.[CodePL], t.[Country], [Month], [ВГО],
    [Scenario], t.[CodeCFO], t.[CFO], t.[GroupCFO1], t.[GroupCFO2],
    t.[GroupCFO3], [Метод.нюансы], [Для отчета],
    pl.[GroupPL], [GroupPL_new], pl.[Expense], [CF_item], [LFL_LISA],
    cf.Ploschad, [RegManager], [DateOpen], [LfLStatus], [Компания],
    sh.plan_hours_numeric, sh.plan_hours_shift, 
    sh.fact_hours_numeric, sh.fact_hours_shift, sh.employee_days;
