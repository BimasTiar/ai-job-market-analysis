-- =====================================================================
-- Global AI Job Market Analysis (2020-2026) — SQL version
-- Author : BimasTiar Putra Milovsky
-- Engine : Google BigQuery (Standard SQL)
--
-- SETUP (one time)
--   1. Open console.cloud.google.com/bigquery (BigQuery Sandbox is free,
--      no credit card needed).
--   2. Create a dataset named: ai_job_market
--   3. Upload 3 CSV files as tables (Create table > Upload > CSV):
--        ai_jobs.csv            -> table: ai_jobs
--        skills_demand.csv      -> table: skills_demand
--        job_title_mapping.csv  -> table: job_title_mapping
--      IMPORTANT: Advanced options > Field delimiter > Custom > ";"
--      Schema: tick "Auto detect". Header rows to skip: 1
--      (auto-detect cannot read headers of all-text files; see Q0)
--   4. Replace `ascendant-yeti-491713-d1` below with your own project ID.
--
-- SANITY CHECK: results should match the Python notebook
--   (50,000 jobs, 224,605 skill rows, top skills AWS / GCP / TensorFlow,
--    avg salary range $57,608 - $167,468).
-- =====================================================================


-- ---------------------------------------------------------------------
-- Q0. Data preparation: fix column names
--     skills_demand and job_title_mapping contain only text columns, so
--     BigQuery schema auto-detect could not read the header row and named
--     the columns string_field_0, string_field_1, ... These statements
--     rename them to the original headers.
-- ---------------------------------------------------------------------
CREATE OR REPLACE TABLE `ascendant-yeti-491713-d1.ai_job_market.skills_demand` AS
SELECT
  string_field_0 AS job_id,
  string_field_1 AS skill,
  string_field_2 AS skill_category,
  string_field_3 AS skill_level
FROM `ascendant-yeti-491713-d1.ai_job_market.skills_demand`;

CREATE OR REPLACE TABLE `ascendant-yeti-491713-d1.ai_job_market.job_title_mapping` AS
SELECT
  string_field_0 AS job_title,
  string_field_1 AS standardized_title,
  string_field_2 AS role_category
FROM `ascendant-yeti-491713-d1.ai_job_market.job_title_mapping`;


-- ---------------------------------------------------------------------
-- Q1. Data quality check: row count, duplicates, and nulls
-- ---------------------------------------------------------------------
SELECT
  COUNT(*)                                   AS total_rows,
  COUNT(DISTINCT job_id)                     AS unique_jobs,
  COUNT(*) - COUNT(DISTINCT job_id)          AS duplicate_job_ids,
  COUNTIF(salary_min_usd IS NULL
          OR salary_max_usd IS NULL)         AS missing_salary,
  MIN(posted_year)                           AS first_year,
  MAX(posted_year)                           AS last_year
FROM `ascendant-yeti-491713-d1.ai_job_market.ai_jobs`;


-- ---------------------------------------------------------------------
-- Q2. Average salary by experience level
--     (CTE to derive salary_avg_usd, same logic as the notebook)
-- ---------------------------------------------------------------------
WITH jobs AS (
  SELECT
    *,
    ROUND((salary_min_usd + salary_max_usd) / 2) AS salary_avg_usd
  FROM `ascendant-yeti-491713-d1.ai_job_market.ai_jobs`
)
SELECT
  experience_level,
  COUNT(*)                         AS job_count,
  ROUND(AVG(salary_avg_usd))       AS avg_salary_usd,
  APPROX_QUANTILES(salary_avg_usd, 2)[OFFSET(1)] AS median_salary_usd,
  MIN(salary_avg_usd)              AS min_salary_usd,
  MAX(salary_avg_usd)              AS max_salary_usd
FROM jobs
GROUP BY experience_level
ORDER BY avg_salary_usd DESC;


-- ---------------------------------------------------------------------
-- Q3. Top 10 most in-demand skills and their share of all requirements
--     (window function for percentage of total)
-- ---------------------------------------------------------------------
SELECT
  skill,
  skill_category,
  COUNT(*)                                              AS demand_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)      AS share_pct
FROM `ascendant-yeti-491713-d1.ai_job_market.skills_demand`
GROUP BY skill, skill_category
ORDER BY demand_count DESC
LIMIT 10;


-- ---------------------------------------------------------------------
-- Q4. Salary by role category x experience level
--     (JOIN jobs with the job title mapping table)
-- ---------------------------------------------------------------------
WITH jobs AS (
  SELECT
    j.*,
    m.role_category,
    ROUND((j.salary_min_usd + j.salary_max_usd) / 2) AS salary_avg_usd
  FROM `ascendant-yeti-491713-d1.ai_job_market.ai_jobs` AS j
  LEFT JOIN `ascendant-yeti-491713-d1.ai_job_market.job_title_mapping` AS m
    ON j.job_title = m.job_title
)
SELECT
  role_category,
  experience_level,
  COUNT(*)                     AS job_count,
  ROUND(AVG(salary_avg_usd))   AS avg_salary_usd
FROM jobs
GROUP BY role_category, experience_level
ORDER BY role_category, avg_salary_usd;


-- ---------------------------------------------------------------------
-- Q5. Remote / Hybrid / Onsite salary premium vs Onsite (H2 test)
-- ---------------------------------------------------------------------
WITH by_type AS (
  SELECT
    remote_type,
    COUNT(*)                                                  AS job_count,
    ROUND(AVG((salary_min_usd + salary_max_usd) / 2))         AS avg_salary_usd
  FROM `ascendant-yeti-491713-d1.ai_job_market.ai_jobs`
  GROUP BY remote_type
),
onsite AS (
  SELECT avg_salary_usd AS onsite_salary
  FROM by_type
  WHERE remote_type = 'Onsite'
)
SELECT
  b.remote_type,
  b.job_count,
  b.avg_salary_usd,
  b.avg_salary_usd - o.onsite_salary                          AS premium_vs_onsite_usd,
  ROUND(100 * (b.avg_salary_usd - o.onsite_salary)
        / o.onsite_salary, 2)                                 AS premium_vs_onsite_pct
FROM by_type AS b
CROSS JOIN onsite AS o
ORDER BY b.avg_salary_usd DESC;


-- ---------------------------------------------------------------------
-- Q6. Year-over-year salary trend (LAG window function)
-- ---------------------------------------------------------------------
WITH yearly AS (
  SELECT
    posted_year,
    ROUND(AVG((salary_min_usd + salary_max_usd) / 2), 2) AS avg_salary_usd
  FROM `ascendant-yeti-491713-d1.ai_job_market.ai_jobs`
  GROUP BY posted_year
)
SELECT
  posted_year,
  avg_salary_usd,
  LAG(avg_salary_usd) OVER (ORDER BY posted_year)            AS prev_year_salary,
  ROUND(100 * (avg_salary_usd
        - LAG(avg_salary_usd) OVER (ORDER BY posted_year))
        / LAG(avg_salary_usd) OVER (ORDER BY posted_year), 2) AS yoy_growth_pct
FROM yearly
ORDER BY posted_year;


-- ---------------------------------------------------------------------
-- Q7. Join integrity check: skills_demand -> ai_jobs
--     Planned analysis "top skills per experience level" returned only
--     ~300 matches per skill, far below the ~6,800 expected from row counts.
--     This check measures how many skill job_ids actually exist in ai_jobs.
--
--     RESULT (run 2026-10-20):
--       skill_job_ids   = 50,000
--       matched_exact   =  2,050  (4.1%)
--       matched_cleaned =  2,050  (TRIM/UPPER does not help)
--     CONCLUSION: the two tables are not reliably linked (synthetic data
--     generated independently). Skill analysis is therefore done on
--     skills_demand alone (Q3), not joined to job attributes.
-- ---------------------------------------------------------------------
SELECT
  (SELECT COUNT(DISTINCT job_id)
     FROM `ascendant-yeti-491713-d1.ai_job_market.skills_demand`)         AS skill_job_ids,
  (SELECT COUNT(DISTINCT s.job_id)
     FROM `ascendant-yeti-491713-d1.ai_job_market.skills_demand` s
     JOIN `ascendant-yeti-491713-d1.ai_job_market.ai_jobs` j
       ON s.job_id = j.job_id)                                            AS matched_exact,
  (SELECT COUNT(DISTINCT s.job_id)
     FROM `ascendant-yeti-491713-d1.ai_job_market.skills_demand` s
     JOIN `ascendant-yeti-491713-d1.ai_job_market.ai_jobs` j
       ON UPPER(TRIM(s.job_id)) = UPPER(TRIM(j.job_id)))                  AS matched_cleaned;
