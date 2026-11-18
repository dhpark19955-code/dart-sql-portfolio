# q12_universe_sector_profile

Q12. 유니버스 200사를 업종(KSIC 중분류)으로 묶으면 수익성과 성장은 어디에 몰려 있나
기법: dim_company x dim_industry x fin_annual_wide 3테이블 JOIN, 업종별 중앙값(ROW_NUMBER + COUNT OVER 로 계산, SQLite 에 MEDIAN 없음),
POWER 로 4년 CAGR(FY2021 -> FY2025), 회사 수 3개 이상 업종만 (HAVING)
주의: 금융업(is_financial = 1)은 매출액 개념이 달라 매출 CAGR·영업이익률에서 제외하고 회사 수만 센다
업종은 DART 기업개황 업종코드(KSIC) 앞 2자리 기준 - 지주회사는 '전문서비스(71)' 로 묶여 실제 사업과 다를 수 있다

## Result (19 rows)

| sector_major   | sector_mid    |   n_cos |   n_financial |   rev25_sum_bn |   opm25_weighted_pct |   opm25_median_pct |   rev_cagr_21_25_pct | top_opm_company   |
|:---------------|:--------------|--------:|--------------:|---------------:|---------------------:|-------------------:|---------------------:|:------------------|
| 제조업            | 전자부품·반도체·통신장비 |      14 |             0 |        609,952 |                 15.9 |                5   |                  6.6 | SK하이닉스            |
| 제조업            | 자동차           |       6 |             0 |        384,690 |                  6.5 |                5.8 |                 11.8 | 기아                |
| 제조업            | 화학            |      17 |             0 |        199,163 |                  3.3 |                5.5 |                  3.9 | 에이피알              |
| 제조업            | 1차금속          |       5 |             0 |        117,116 |                  3.1 |                2.7 |                  0.2 | 고려아연              |
| 도소매            | 도매            |       7 |             0 |        106,564 |                  5.8 |                8.1 |                  1.9 | 영원무역              |
| 도소매            | 소매            |       7 |             0 |         78,956 |                  2.9 |                2.8 |                  2.9 | 현대백화점             |
| 제조업            | 기타운송장비(조선·항공) |       7 |             0 |         78,481 |                 11.1 |               11.6 |                 26.3 | 대한조선              |
| 제조업            | 전기장비          |      14 |             0 |         69,905 |                  3.8 |                5.7 |                 10.1 | 산일전기              |
| 건설업            | 종합건설          |       5 |             0 |         63,117 |                  1.4 |                3.5 |                  7.8 | IPARK현대산업개발       |
| 정보통신           | 통신            |       3 |             0 |         60,795 |                  7.3 |                6.3 |                  2.3 | KT                |
| 제조업            | 식료품           |       6 |             0 |         44,432 |                  6.3 |                5   |                  4.8 | 삼양식품              |
| 정보통신           | 정보서비스(포털·플랫폼) |       3 |             0 |         37,629 |                 12   |                9   |                 18.9 | NAVER             |
| 제조업            | 기계장비          |       9 |             0 |         36,575 |                  5   |                7.8 |                 10.3 | 한미반도체             |
| 제조업            | 의약품           |       8 |             0 |         16,822 |                 22.2 |                8.7 |                 13.7 | 삼성바이오로직스          |
| 정보통신           | 출판(소프트웨어 포함)  |       7 |             0 |         15,451 |                 14.4 |               12.4 |                  7.6 | 시프트업              |
| 전문과학기술         | 건축기술엔지니어링     |       4 |             0 |         12,605 |                  9.8 |                7.8 |                  4.9 | HD현대마린솔루션         |
| 금융보험           | 금융보험관련서비스(증권) |       6 |             6 |                |                      |                    |                      |                   |
| 금융보험           | 금융업(은행·지주·여신) |      35 |            35 |                |                      |                    |                      |                   |
| 금융보험           | 보험            |       8 |             8 |                |                      |                    |                      |                   |

## SQL

```sql
-- Q12. 유니버스 200사를 업종(KSIC 중분류)으로 묶으면 수익성과 성장은 어디에 몰려 있나
-- 기법: dim_company x dim_industry x fin_annual_wide 3테이블 JOIN, 업종별 중앙값(ROW_NUMBER + COUNT OVER 로 계산, SQLite 에 MEDIAN 없음),
--       POWER 로 4년 CAGR(FY2021 -> FY2025), 회사 수 3개 이상 업종만 (HAVING)
-- 주의: 금융업(is_financial = 1)은 매출액 개념이 달라 매출 CAGR·영업이익률에서 제외하고 회사 수만 센다
--       업종은 DART 기업개황 업종코드(KSIC) 앞 2자리 기준 - 지주회사는 '전문서비스(71)' 로 묶여 실제 사업과 다를 수 있다

WITH base AS (
    SELECT d.corp_code, d.corp_name, i.sector_major, i.sector_mid, i.is_financial,
           w25.revenue AS rev25, w25.op_income AS op25,
           w21.revenue AS rev21,
           100.0 * w25.op_income / NULLIF(w25.revenue, 0) AS opm25
    FROM dim_company d
    JOIN dim_industry i ON i.ksic2 = SUBSTR(d.induty_code, 1, 2)
    LEFT JOIN fin_annual_wide w25 ON w25.corp_code = d.corp_code AND w25.fiscal_year = 2025 AND w25.fs_div = 'CFS'
    LEFT JOIN fin_annual_wide w21 ON w21.corp_code = d.corp_code AND w21.fiscal_year = 2021 AND w21.fs_div = 'CFS'
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY sector_mid ORDER BY opm25) AS rn,
           COUNT(opm25)  OVER (PARTITION BY sector_mid)               AS cnt
    FROM base
    WHERE is_financial = 0 AND opm25 IS NOT NULL
),
median AS (
    -- 중앙값: 정렬 순번이 가운데 1~2개인 행의 평균
    SELECT sector_mid, AVG(opm25) AS opm25_median
    FROM ranked
    WHERE rn IN ((cnt + 1) / 2, (cnt + 2) / 2)
    GROUP BY sector_mid
),
sector AS (
    SELECT b.sector_major, b.sector_mid,
           COUNT(*)                                                            AS n_cos,
           SUM(b.is_financial)                                                 AS n_financial,
           ROUND(SUM(CASE WHEN b.is_financial = 0 THEN b.rev25 END) / 1000.0, 0) AS rev25_sum_bn,
           ROUND(100.0 * SUM(CASE WHEN b.is_financial = 0 THEN b.op25 END)
                       / NULLIF(SUM(CASE WHEN b.is_financial = 0 THEN b.rev25 END), 0), 1) AS opm25_weighted_pct,
           ROUND(m.opm25_median, 1)                                            AS opm25_median_pct,
           ROUND(100.0 * (POWER(SUM(CASE WHEN b.is_financial = 0 AND b.rev21 > 0 THEN b.rev25 END) * 1.0
                               / NULLIF(SUM(CASE WHEN b.is_financial = 0 AND b.rev21 > 0 THEN b.rev21 END), 0), 0.25) - 1), 1)
                                                                               AS rev_cagr_21_25_pct,
           (SELECT corp_name FROM ranked r WHERE r.sector_mid = b.sector_mid ORDER BY opm25 DESC LIMIT 1) AS top_opm_company
    FROM base b
    LEFT JOIN median m ON m.sector_mid = b.sector_mid
    GROUP BY b.sector_major, b.sector_mid
    HAVING COUNT(*) >= 3
)
SELECT *
FROM sector
ORDER BY rev25_sum_bn DESC;
```
