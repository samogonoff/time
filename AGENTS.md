# AGENTS.md — time

## What this repo is

SQL analysis scripts for store work schedules (`mot_store_schedule`) against a
MSSQL database — plan/fact hours joined into `Table_Fin_PL` for financial
planning.  The only real source file is `mot_store_schedule_analysis.sql`.
`main.py` is a PyCharm boilerplate stub — ignore it.

## Database

| Key      | Value               |
|----------|---------------------|
| Engine   | Microsoft SQL Server |
| Catalog  | `mfportal`           |
| Schema   | `dbo`                |

Connection credentials live in `.env` (MSSQL\_SERVER, MSSQL\_DATABASE,
MSSQL\_USER, MSSQL\_PASSWORD, MSSQL\_PORT).  Load before running any queries:

```sh
export $(grep '^MSSQL_' .env | xargs)
```

## SQL dialect — T-SQL specifics used

- `TRY_CAST(... AS decimal(10,4))` — safe cast, returns NULL on failure
- `TRY_CAST(... AS time)` — string `HH:MM` → `time`
- `CHARINDEX('-', col)` — locate delimiter in interval strings like `"09:00-18:00"`
- `DATEDIFF(MINUTE, t1, t2)` — interval duration
- `INFORMATION_SCHEMA.COLUMNS` — schema introspection
- Time parsing pattern: `LEFT(col,5)` / `SUBSTRING(col, CHARINDEX('-',col)+1, 5)`

## Key join relationship (historically tripped up agents)

```
mot_store_schedule.klient_id = 001 CodeCFO.CodeFOX
                              ^ NOT CodeCFO
```

The join goes through `002 CodePL` → `001 CodeCFO` → `mot_store_schedule`:

```
Table_Fin_PL.CodeCFO → 001 CodeCFO.CodeCFO
                    ↘ 001 CodeCFO.CodeFOX → mot_store_schedule.klient_id
```

LEFT JOIN on `(year_num, month_num)` derived from `Table_Fin_PL.Month`.

## Script structure

`mot_store_schedule_analysis.sql` contains 6 sections (1–5 are exploration, 6
is the production query):

1.  Schema introspection via `INFORMATION_SCHEMA.COLUMNS`
2.  `plan_value` type distribution (NULL / NUMERIC / CODE)
3.  `fact_value` type distribution
4.  Unique non-numeric codes in both value columns
5.  CTE `store_hours` — plan/fact hours aggregated by store/month
6.  Main SELECT joining `Table_Fin_PL` → `store_hours` via `CodeFOX = klient_id`

## Commands

```sh
# Connect and run a query (after loading .env)
python3 -c "import pymssql; c=pymssql.connect(...)"  # not set up yet
```

There is no test suite, no build system, no CI.  The project is a collection of
ad-hoc SQL queries run manually from a SQL client (SSMS / Azure Data Studio).
