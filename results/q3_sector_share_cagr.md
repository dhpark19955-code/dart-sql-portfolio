# q3_sector_share_cagr

Q3. 섹터 합산 대비 각 회사의 비중은 얼마고, 3년간 누가 점유율을 늘렸나?
기법: SUM() OVER (PARTITION BY) 로 섹터 합산 대비 비중, 자기 조인 없이 FIRST/LAST 연도 비교,
POWER/ln을 이용한 CAGR (SQLite 3.35+ math 함수)

## Result (13 rows)

| sector     | corp_name   |   rev_first_bn |   rev_last_bn |   rev_cagr_pct |   rev_share_first_pct |   rev_share_last_pct |   share_change_pp |   op_share_last_pct |
|:-----------|:------------|---------------:|--------------:|---------------:|----------------------:|---------------------:|------------------:|--------------------:|
| IT인프라/SaaS | 삼성에스디에스     |        11017.4 |       13929.9 |            4.8 |                  93.9 |                 91.4 |              -2.5 |                79.8 |
| IT인프라/SaaS | 더존비즈온       |          306.5 |         446.3 |            7.8 |                   2.6 |                  2.9 |               0.3 |                10.6 |
| IT인프라/SaaS | 헥토이노베이션     |          170.9 |         375.8 |           17.1 |                   1.5 |                  2.5 |               1   |                 4.2 |
| IT인프라/SaaS | 가비아         |          169   |         335.7 |           14.7 |                   1.4 |                  2.2 |               0.8 |                 3.4 |
| IT인프라/SaaS | 케이아이엔엑스     |           70.4 |         159.2 |           17.7 |                   0.6 |                  1   |               0.4 |                 2   |
| 게임         | 크래프톤        |         1670.4 |        3326.6 |           14.8 |                  23.6 |                 40.9 |              17.3 |                74.1 |
| 게임         | 넷마블         |         2484.8 |        2835.1 |            2.7 |                  35.2 |                 34.9 |              -0.3 |                24.8 |
| 게임         | NC          |         2416.2 |        1506.9 |           -9   |                  34.2 |                 18.5 |             -15.7 |                 1.1 |
| 게임         | 카카오게임즈      |          495.5 |         465   |           -1.3 |                   7   |                  5.7 |              -1.3 |                -2.8 |
| 인터넷플랫폼     | NAVER       |         5304.1 |       12035   |           17.8 |                  47.3 |                 52.1 |               4.8 |                69.1 |
| 인터넷플랫폼     | 카카오         |         4071.4 |        8099.1 |           14.7 |                  36.3 |                 35   |              -1.3 |                22.9 |
| 인터넷플랫폼     | NHN         |         1641.2 |        2516.2 |            8.9 |                  14.6 |                 10.9 |              -3.8 |                 4.1 |
| 인터넷플랫폼     | SOOP        |          195   |         466.6 |           19.1 |                   1.7 |                  2   |               0.3 |                 3.9 |

## SQL

```sql
-- Q3. 섹터 합산 대비 각 회사의 비중은 얼마고, 3년간 누가 점유율을 늘렸나?
-- 기법: SUM() OVER (PARTITION BY) 로 섹터 합산 대비 비중, 자기 조인 없이 FIRST/LAST 연도 비교,
--       POWER/ln을 이용한 CAGR (SQLite 3.35+ math 함수)

WITH yr AS (
    SELECT MIN(fiscal_year) AS first_year, MAX(fiscal_year) AS last_year
    FROM financials_annual
),
share AS (
    SELECT
        c.sector,
        c.corp_name,
        f.fiscal_year,
        f.revenue,
        f.op_income,
        100.0 * f.revenue   / SUM(f.revenue)   OVER (PARTITION BY c.sector, f.fiscal_year) AS rev_share_pct,
        -- 영업이익은 적자가 섞이면 합산 비중이 왜곡되므로 흑자 기업만 분모에 넣는다
        100.0 * f.op_income / SUM(CASE WHEN f.op_income > 0 THEN f.op_income END)
                              OVER (PARTITION BY c.sector, f.fiscal_year)                 AS op_share_pct
    FROM financials_annual f
    JOIN companies c ON c.corp_code = f.corp_code
    WHERE f.fs_div = 'CFS'
),
first_last AS (
    SELECT
        s.sector, s.corp_name,
        MAX(CASE WHEN s.fiscal_year = y.first_year THEN s.revenue END)        AS rev_first,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.revenue END)        AS rev_last,
        MAX(CASE WHEN s.fiscal_year = y.first_year THEN s.rev_share_pct END)  AS share_first,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.rev_share_pct END)  AS share_last,
        MAX(CASE WHEN s.fiscal_year = y.last_year  THEN s.op_share_pct END)   AS op_share_last,
        y.last_year - y.first_year                                            AS n_years
    FROM share s CROSS JOIN yr y
    GROUP BY s.sector, s.corp_name, y.last_year, y.first_year
)
SELECT
    sector,
    corp_name,
    ROUND(rev_first / 1000.0, 1)                                    AS rev_first_bn,
    ROUND(rev_last  / 1000.0, 1)                                    AS rev_last_bn,
    ROUND(100.0 * (POWER(rev_last * 1.0 / rev_first, 1.0 / n_years) - 1), 1) AS rev_cagr_pct,
    ROUND(share_first, 1)                                           AS rev_share_first_pct,
    ROUND(share_last, 1)                                            AS rev_share_last_pct,
    ROUND(share_last - share_first, 1)                              AS share_change_pp,
    ROUND(op_share_last, 1)                                         AS op_share_last_pct
FROM first_last
ORDER BY sector, rev_share_last_pct DESC;
```
