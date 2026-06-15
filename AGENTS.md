# AGENTS.md — time

## What this repo is

Single T-SQL analysis script (`mot_store_schedule_analysis.sql`) that joins store work schedules (`mot_store_schedule`) with financial planning data (`Table_Fin_PL`) to compute plan/fact employee hours.

All SQL comments are in Russian. `main.py` is PyCharm boilerplate — ignore it.

## Database

MSSQL, cross-database queries:

| Database  | Schema | Key tables                          |
|-----------|--------|-------------------------------------|
| `mfportal` | `dbo` | `mot_store_schedule`               |
| `FinDWH`   | `dbo` | `Table_Fin_PL`, `002 CodePL`, `001 CodeCFO` |

Credentials in `.env` (`MSSQL_*` vars) — gitignored, must be present.

## Critical join rule

The central gotcha: `mot_store_schedule.klient_id` joins to `001 CodeCFO.CodeFOX`, **NOT** `CodeCFO`.

```
Table_Fin_PL.CodeCFO → 001 CodeCFO.CodeCFO
                    ↘ 001 CodeCFO.CodeFOX → mot_store_schedule.klient_id
```

Joined on `(year_num, month_num)` derived from `Table_Fin_PL.Month`.

## T-SQL specifics used

- `TRY_CAST(... AS decimal(10,4))` / `TRY_CAST(... AS time)` — safe type coercion
- `CHARINDEX('-', col)` + `LEFT`/`SUBSTRING` — parse `"HH:MM-HH:MM"` intervals
- `DATEDIFF(MINUTE, t1, t2)` — shift duration in minutes, divided by 60
- `INFORMATION_SCHEMA.COLUMNS` — schema introspection

## Script structure (6 sections)

1. Schema introspection — `INFORMATION_SCHEMA.COLUMNS` on `mot_store_schedule`
2-4. Value type distribution & unique non-numeric codes in `plan_value`/`fact_value`
5. CTE `store_hours` — aggregate plan/fact hours by store+month
6. Main SELECT — `Table_Fin_PL` ← `store_hours` via `CodeFOX = klient_id`

Sections 1–5 are exploration aids; section 6 is the production query.

## How to use

No test suite, build system, or CI. Run queries manually from SSMS / Azure Data Studio against the MSSQL server. There is no local driver or runner set up in this repo.
