# q4_turnaround_health

Q4. 흑자전환 / 적자전환 기업을 찾고, 재무건전성(부채비율·유동비율)과 함께 본다
기법: LAG로 전년 영업이익과 비교, CASE로 상태 라벨링, 다중 조건 필터
활용: 스크리닝 1차 필터 - "턴어라운드인데 재무구조도 괜찮은 곳"을 먼저 추린다

## Result (26 rows)

| sector     | corp_name   |   fiscal_year |   prev_op_bn |   op_income_bn | op_status   |   net_income_bn |   debt_ratio_pct |   current_ratio_pct | healthy_flag   |
|:-----------|:------------|--------------:|-------------:|---------------:|:------------|----------------:|-----------------:|--------------------:|:---------------|
| 게임         | NC          |          2025 |       -109.2 |           16.1 | 흑자전환        |           347.4 |             28.6 |               353.5 | Y              |
| 인터넷플랫폼     | NHN         |          2025 |        -32.6 |          132.4 | 흑자전환        |            51.9 |            117.5 |               142.6 |                |
| 게임         | 넷마블         |          2024 |        -68.5 |          215.6 | 흑자전환        |             3.2 |             49.4 |                82.7 |                |
| 게임         | 카카오게임즈      |          2025 |         19.1 |          -39.6 | 적자전환        |          -143.1 |            123.4 |               183   |                |
| 게임         | NC          |          2024 |        137.3 |         -109.2 | 적자전환        |            94.1 |             29.1 |               555.1 | Y              |
| 인터넷플랫폼     | NHN         |          2024 |         55.6 |          -32.6 | 적자전환        |          -192.6 |             80.9 |               161.5 | Y              |
| 인터넷플랫폼     | NAVER       |          2025 |       1979.3 |         2208.1 | 흑자확대        |          1818.7 |             41.9 |               136.3 |                |
| 인터넷플랫폼     | SOOP        |          2025 |        113.5 |          124.8 | 흑자확대        |           103.7 |             75.8 |               200.7 | Y              |
| IT인프라/SaaS | 가비아         |          2025 |         35.1 |           40.5 | 흑자확대        |            31.1 |             68   |               131.8 |                |
| 게임         | 넷마블         |          2025 |        215.6 |          352.5 | 흑자확대        |           230.8 |             47.4 |                66.1 |                |
| IT인프라/SaaS | 더존비즈온       |          2025 |         88.1 |          127.7 | 흑자확대        |            92.3 |             78.9 |                54.9 |                |
| IT인프라/SaaS | 삼성에스디에스     |          2025 |        911.1 |          957.1 | 흑자확대        |           782.7 |             31.1 |               403.4 | Y              |
| 인터넷플랫폼     | 카카오         |          2025 |        495.3 |          732   | 흑자확대        |           518   |             82.5 |               140.9 |                |
| IT인프라/SaaS | 케이아이엔엑스     |          2025 |         23.7 |           23.9 | 흑자확대        |            19.6 |             36.2 |               298.5 | Y              |
| IT인프라/SaaS | 헥토이노베이션     |          2025 |         48.9 |           50.2 | 흑자확대        |            36.8 |            122.3 |               147.2 |                |
| 인터넷플랫폼     | NAVER       |          2024 |       1488.8 |         1979.3 | 흑자확대        |          1932   |             41.4 |               153.9 | Y              |
| 인터넷플랫폼     | SOOP        |          2024 |         90.3 |          113.5 | 흑자확대        |           102.4 |             87.2 |               189.4 | Y              |
| IT인프라/SaaS | 더존비즈온       |          2024 |         72.4 |           88.1 | 흑자확대        |            78   |             87   |               105.7 |                |
| IT인프라/SaaS | 삼성에스디에스     |          2024 |        808.2 |          911.1 | 흑자확대        |           789.5 |             36.4 |               360.8 | Y              |
| 인터넷플랫폼     | 카카오         |          2024 |        483   |          495.3 | 흑자확대        |          -161.9 |             84.8 |               125.5 |                |
| 게임         | 크래프톤        |          2024 |        768   |         1182.5 | 흑자확대        |          1302.6 |             16   |               637.6 | Y              |
| IT인프라/SaaS | 헥토이노베이션     |          2024 |         38   |           48.9 | 흑자확대        |            34.8 |            109.9 |               157.2 |                |
| 게임         | 크래프톤        |          2025 |       1182.5 |         1054.4 | 흑자축소        |           733.7 |             31.3 |               307.4 | Y              |
| IT인프라/SaaS | 가비아         |          2024 |         42.6 |           35.1 | 흑자축소        |            28.6 |             83   |               132.2 |                |
| 게임         | 카카오게임즈      |          2024 |         75.4 |           19.1 | 흑자축소        |          -128.1 |            114.6 |                89.1 |                |
| IT인프라/SaaS | 케이아이엔엑스     |          2024 |         26.6 |           23.7 | 흑자축소        |            18.3 |             46.5 |               173.3 | Y              |

## SQL

```sql
-- Q4. 흑자전환 / 적자전환 기업을 찾고, 재무건전성(부채비율·유동비율)과 함께 본다
-- 기법: LAG로 전년 영업이익과 비교, CASE로 상태 라벨링, 다중 조건 필터
-- 활용: 스크리닝 1차 필터 - "턴어라운드인데 재무구조도 괜찮은 곳"을 먼저 추린다

WITH seq AS (
    SELECT
        c.sector, c.corp_name, f.fiscal_year,
        f.op_income, f.net_income,
        LAG(f.op_income)  OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_op,
        LAG(f.net_income) OVER (PARTITION BY f.corp_code ORDER BY f.fiscal_year) AS prev_ni,
        f.total_liab, f.total_equity, f.current_assets, f.current_liab
    FROM financials_annual f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
),
labeled AS (
    SELECT *,
        CASE
            WHEN prev_op IS NULL                  THEN 'n/a'
            WHEN prev_op <= 0 AND op_income > 0   THEN '흑자전환'
            WHEN prev_op > 0  AND op_income <= 0  THEN '적자전환'
            WHEN prev_op <= 0 AND op_income <= 0  THEN '적자지속'
            WHEN op_income >= prev_op             THEN '흑자확대'
            ELSE                                       '흑자축소'
        END AS op_status,
        ROUND(100.0 * total_liab / NULLIF(total_equity, 0), 1)       AS debt_ratio_pct,
        ROUND(100.0 * current_assets / NULLIF(current_liab, 0), 1)   AS current_ratio_pct
    FROM seq
)
SELECT
    sector, corp_name, fiscal_year,
    ROUND(prev_op   / 1000.0, 1) AS prev_op_bn,
    ROUND(op_income / 1000.0, 1) AS op_income_bn,
    op_status,
    ROUND(net_income / 1000.0, 1) AS net_income_bn,
    debt_ratio_pct,
    current_ratio_pct,
    -- 간단한 건전성 플래그: 부채비율 100% 이하 & 유동비율 150% 이상
    CASE WHEN debt_ratio_pct <= 100 AND current_ratio_pct >= 150 THEN 'Y' ELSE '' END AS healthy_flag
FROM labeled
WHERE fiscal_year >= 2024
ORDER BY
    CASE op_status WHEN '흑자전환' THEN 1 WHEN '적자전환' THEN 2 WHEN '적자지속' THEN 3
                   WHEN '흑자확대' THEN 4 ELSE 5 END,
    fiscal_year DESC, corp_name;
```
