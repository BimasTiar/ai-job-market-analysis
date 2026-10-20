# Global AI Job Market Analysis (2020–2026)

End-to-end analysis of 50,000 AI job postings to understand what drives compensation and which skills employers ask for. Final project for the RevoU Full Stack Data Analytics program (FSDA, Feb 2026 cohort).

**Interactive dashboard:** [Tableau Public](https://public.tableau.com/views/DEEPP_Milo_fixed/Dashboard)

## Business questions

1. What does the AI job market look like across experience levels, work arrangements and roles?
2. Which skills are most in demand?
3. How have salaries moved from 2020 to 2026?
4. Three hypotheses on pay drivers:
   - **H1:** Senior salaries grow faster than Entry and Mid.
   - **H2:** Remote roles pay a premium over Hybrid and Onsite.
   - **H3:** Engineering roles (ML Engineer, MLOps) pay more than Analytics roles at every level.

## Data

Four related CSV files (semicolon-delimited):

| Table | Rows | Description |
|---|---|---|
| `ai_jobs` | 50,000 | Job postings: title, country, remote type, experience level, salary range, year |
| `skills_demand` | 224,605 | Skills requested per posting, with category and level |
| `job_title_mapping` | 6 | Maps job titles to role category (Analytics / Engineering) |
| `country_ai_trends` | 42 | Country-level yearly AI job statistics |

> **Note:** the dataset is synthetic, provided for the course. Distributions are unusually uniform, so findings describe this dataset, not the real market.

## Approach

| Step | Tool | Output |
|---|---|---|
| Data cleaning, EDA, hypothesis testing, K-Means segmentation | Python (pandas, scikit-learn) in Google Colab | `notebook/` |
| Validation and re-analysis in SQL | Google BigQuery | `sql/ai_job_market_analysis.sql` |
| Dashboard | Tableau Public | link above |

The SQL layer reproduces the notebook's core results independently. Every SQL result matched the Python output (row counts, salary averages, skill shares, year-over-year growth).

SQL techniques used: CTEs, `GROUP BY` aggregation, `LEFT JOIN`, `CROSS JOIN`, window functions (`SUM() OVER()`, `LAG()`), `APPROX_QUANTILES` for medians, and DDL (`CREATE OR REPLACE TABLE`) for data preparation.

## Key findings

| Finding | Evidence |
|---|---|
| **Experience level is the main salary driver.** Salary bands do not overlap between levels. | Entry avg $67,474 (max $77,383) · Mid avg $107,507 (range $97,572–$117,417) · Senior avg $157,490 (min $147,556) |
| **No single skill dominates.** Top 10 skills sit within 0.19 percentage points of each other; Cloud and ML skills together dominate demand. | AWS 9.19%, TensorFlow 9.15%, GCP 9.15% … R 9.00% |
| **Salaries are flat over time.** | YoY change stays between −0.94% and +0.58% (2020–2026) |
| **H1 not supported.** Senior pay did not grow faster than Entry or Mid. | 2020→2026 growth: Entry +0.14%, Mid −0.12%, Senior −0.09% |
| **H2 not supported.** Hybrid, not Remote, has the (negligible) premium. | Premium vs Onsite: Hybrid +$662 (+0.60%), Remote +$404 (+0.37%) |
| **H3 not supported.** Engineering and Analytics pay are virtually identical at each level. | Max gap ≈ $105 at any level |
| **Market segments (K-Means, K=3).** | Senior "Elites" (≈ $157k avg), Entry engineers (≈ $87k), Mid remote analysts (≈ $88k) |

## Data quality notes

- **Schema auto-detect issue.** BigQuery could not read the header row of the all-text files (`skills_demand`, `job_title_mapping`) and named the columns `string_field_0…`. Fixed with `CREATE OR REPLACE TABLE` (see Q0 in the SQL file).
- **Unlinked tables.** A planned "top skills per experience level" join returned far fewer rows than expected. An integrity check (Q7) showed only **2,050 of 50,000 (4.1%)** `job_id` values in `skills_demand` exist in `ai_jobs`, and trimming/case-normalising did not help. Skill analysis is therefore done on `skills_demand` alone, not joined to job attributes.

## Repository structure

```
├── notebook/
│   └── [FEB26]FSDA_BimasTiar_Putra_Milovsky_DEEPP.ipynb
├── sql/
│   └── ai_job_market_analysis.sql
├── screenshots/
│   └── Q1 … Q7 BigQuery results
└── README.md
```

## Author

**BimasTiar Putra Milovsky** · Information Systems, BINUS University
[LinkedIn](https://www.linkedin.com/in/bimastiar-putra-milovsky-565a8728a)
