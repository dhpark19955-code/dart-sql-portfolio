# q11_layered_vs_phase1_crosscheck

Q11. 새 계층 파이프라인(fin_annual_wide)이 1단계 테이블(financials_annual)과 같은 숫자를 내는가
기법: 두 파이프라인의 교집합(13사 x 겹치는 연도)을 JOIN 해 계정별 차이를 UNPIVOT(UNION ALL)으로 한 표에
읽는 법: diff_mn = 0 이면 같은 원천·같은 규칙. 0 이 아니면 (a) 1단계가 보충 CSV 로 채운 값(카카오 FY2022 매출 등)
(b) 2단계 유니버스에 그 회사가 없음(NULL) (c) 정정보고서 채택 차이 - 어느 쪽인지 note 로 표시
주의: financials_annual 은 FY2020~2025, fin_annual_wide 는 사업보고서 2021~2025 기준 FY2019~2025 이므로 겹치는 연도만

## Result (146 rows)

| corp_name   |   fiscal_year | account      |   phase1_mn | phase2_mn   | diff_mn   | note                                                |
|:------------|--------------:|:-------------|------------:|:------------|:----------|:----------------------------------------------------|
| SOOP        |          2020 | net_income   |      36,260 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2020 | op_income    |      50,413 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2020 | revenue      |     195,028 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2020 | total_assets |     292,037 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2021 | net_income   |      70,868 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2021 | op_income    |      88,822 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2021 | revenue      |     260,479 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2021 | total_assets |     408,149 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2022 | net_income   |      59,513 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2022 | op_income    |      82,418 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2022 | revenue      |     289,087 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2022 | total_assets |     465,125 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2023 | net_income   |      74,623 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2023 | op_income    |      90,309 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2023 | revenue      |     344,016 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2023 | total_assets |     578,068 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2024 | net_income   |     102,423 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2024 | op_income    |     113,506 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2024 | revenue      |     413,178 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2024 | total_assets |     715,724 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2025 | net_income   |     103,744 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2025 | op_income    |     124,840 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2025 | revenue      |     466,570 |             |           | not in KOSPI top200 universe                        |
| SOOP        |          2025 | total_assets |     884,795 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2020 | net_income   |      23,751 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2020 | op_income    |      28,545 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2020 | revenue      |     169,044 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2020 | total_assets |     260,025 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2021 | net_income   |      24,998 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2021 | op_income    |      33,630 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2021 | revenue      |     199,463 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2021 | total_assets |     302,957 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2022 | net_income   |      41,594 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2022 | op_income    |      41,205 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2022 | revenue      |     239,153 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2022 | total_assets |     368,323 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2023 | net_income   |      34,640 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2023 | op_income    |      42,602 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2023 | revenue      |     261,590 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2023 | total_assets |     462,666 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2024 | net_income   |      28,592 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2024 | op_income    |      35,109 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2024 | revenue      |     282,417 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2024 | total_assets |     634,500 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2025 | net_income   |      31,119 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2025 | op_income    |      40,485 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2025 | revenue      |     335,681 |             |           | not in KOSPI top200 universe                        |
| 가비아         |          2025 | total_assets |     627,658 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2020 | net_income   |      57,901 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2020 | op_income    |      76,728 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2020 | revenue      |     306,455 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2020 | total_assets |     804,070 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2021 | net_income   |      54,413 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2021 | op_income    |      71,173 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2021 | revenue      |     318,746 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2021 | total_assets |     900,314 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2022 | net_income   |      24,813 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2022 | op_income    |      50,097 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2022 | revenue      |     305,254 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2022 | total_assets |     888,860 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2023 | net_income   |      38,515 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2023 | op_income    |      72,364 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2023 | revenue      |     354,630 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2023 | total_assets |     936,627 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2024 | net_income   |      78,026 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2024 | op_income    |      88,064 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2024 | revenue      |     402,332 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2024 | total_assets |   1,037,613 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2025 | net_income   |      92,289 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2025 | op_income    |     127,727 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2025 | revenue      |     446,299 |             |           | not in KOSPI top200 universe                        |
| 더존비즈온       |          2025 | total_assets |   1,129,961 |             |           | not in KOSPI top200 universe                        |
| 카카오         |          2020 | revenue      |   4,071,392 |             |           | phase2 NULL (account not mapped or year not loaded) |
| 카카오게임즈      |          2020 | net_income   |      67,510 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2020 | op_income    |      66,520 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2020 | revenue      |     495,521 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2020 | total_assets |   1,309,911 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2021 | net_income   |     520,154 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2021 | op_income    |     111,917 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2021 | revenue      |   1,012,481 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2021 | total_assets |   4,305,011 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2022 | net_income   |    -196,113 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2022 | op_income    |     148,633 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2022 | revenue      |     801,290 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2022 | total_assets |   3,873,941 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2023 | net_income   |    -322,405 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2023 | op_income    |      75,389 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2023 | revenue      |     725,820 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2023 | total_assets |   3,471,016 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2024 | net_income   |    -128,088 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2024 | op_income    |      19,148 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2024 | revenue      |     627,227 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2024 | total_assets |   3,173,239 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2025 | net_income   |    -143,084 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2025 | op_income    |     -39,590 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2025 | revenue      |     465,018 |             |           | not in KOSPI top200 universe                        |
| 카카오게임즈      |          2025 | total_assets |   2,676,774 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2020 | net_income   |      15,669 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2020 | op_income    |      17,782 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2020 | revenue      |      70,440 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2020 | total_assets |     142,751 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2021 | net_income   |      16,402 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2021 | op_income    |      19,734 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2021 | revenue      |      84,460 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2021 | total_assets |     167,210 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2022 | net_income   |      27,337 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2022 | op_income    |      25,865 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2022 | revenue      |     110,928 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2022 | total_assets |     197,438 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2023 | net_income   |      26,942 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2023 | op_income    |      26,565 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2023 | revenue      |     122,686 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2023 | total_assets |     254,807 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2024 | net_income   |      18,338 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2024 | op_income    |      23,732 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2024 | revenue      |     138,902 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2024 | total_assets |     336,792 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2025 | net_income   |      19,578 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2025 | op_income    |      23,883 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2025 | revenue      |     159,244 |             |           | not in KOSPI top200 universe                        |
| 케이아이엔엑스     |          2025 | total_assets |     337,890 |             |           | not in KOSPI top200 universe                        |
| 크래프톤        |          2020 | revenue      |   1,670,427 |             |           | phase2 NULL (account not mapped or year not loaded) |
| 헥토이노베이션     |          2020 | net_income   |      29,325 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2020 | op_income    |      28,200 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2020 | revenue      |     170,932 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2020 | total_assets |     361,844 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2021 | net_income   |      32,465 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2021 | op_income    |      37,477 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2021 | revenue      |     221,041 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2021 | total_assets |     454,054 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2022 | net_income   |      32,177 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2022 | op_income    |      35,644 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2022 | revenue      |     262,967 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2022 | total_assets |     530,547 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2023 | net_income   |      31,912 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2023 | op_income    |      38,027 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2023 | revenue      |     288,489 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2023 | total_assets |     580,594 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2024 | net_income   |      34,774 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2024 | op_income    |      48,856 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2024 | revenue      |     319,471 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2024 | total_assets |     692,154 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2025 | net_income   |      36,792 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2025 | op_income    |      50,180 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2025 | revenue      |     375,822 |             |           | not in KOSPI top200 universe                        |
| 헥토이노베이션     |          2025 | total_assets |     799,310 |             |           | not in KOSPI top200 universe                        |

## SQL

```sql
-- Q11. 새 계층 파이프라인(fin_annual_wide)이 1단계 테이블(financials_annual)과 같은 숫자를 내는가
-- 기법: 두 파이프라인의 교집합(13사 x 겹치는 연도)을 JOIN 해 계정별 차이를 UNPIVOT(UNION ALL)으로 한 표에
-- 읽는 법: diff_mn = 0 이면 같은 원천·같은 규칙. 0 이 아니면 (a) 1단계가 보충 CSV 로 채운 값(카카오 FY2022 매출 등)
--          (b) 2단계 유니버스에 그 회사가 없음(NULL) (c) 정정보고서 채택 차이 - 어느 쪽인지 note 로 표시
-- 주의: financials_annual 은 FY2020~2025, fin_annual_wide 는 사업보고서 2021~2025 기준 FY2019~2025 이므로 겹치는 연도만

WITH both_ AS (
    SELECT c.corp_name, a.fiscal_year,
           a.revenue AS rev_p1,   w.revenue AS rev_p2,
           a.op_income AS op_p1,  w.op_income AS op_p2,
           a.net_income AS ni_p1, w.net_income AS ni_p2,
           a.total_assets AS ta_p1, w.total_assets AS ta_p2,
           CASE WHEN w.corp_code IS NULL THEN 1 ELSE 0 END AS not_in_universe
    FROM financials_annual a
    JOIN companies c ON c.corp_code = a.corp_code
    LEFT JOIN v_fin_annual w ON w.corp_code = a.corp_code AND w.fiscal_year = a.fiscal_year
    WHERE a.fs_div = 'CFS'
),
diffs AS (
    SELECT corp_name, fiscal_year, 'revenue'      AS account, rev_p1 AS phase1_mn, rev_p2 AS phase2_mn, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'op_income',  op_p1, op_p2, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'net_income', ni_p1, ni_p2, not_in_universe FROM both_
    UNION ALL
    SELECT corp_name, fiscal_year, 'total_assets', ta_p1, ta_p2, not_in_universe FROM both_
)
SELECT corp_name, fiscal_year, account, phase1_mn, phase2_mn,
       phase2_mn - phase1_mn AS diff_mn,
       CASE WHEN not_in_universe = 1 THEN 'not in KOSPI top200 universe'
            WHEN phase2_mn IS NULL THEN 'phase2 NULL (account not mapped or year not loaded)'
            WHEN phase1_mn = phase2_mn THEN 'same'
            ELSE 'differs - check supplement / restatement' END AS note
FROM diffs
WHERE NOT (phase1_mn = phase2_mn) OR (phase1_mn IS NULL) <> (phase2_mn IS NULL)   -- 같은 행은 생략 (NULL 안전, SQLite·DuckDB 공통)
ORDER BY corp_name, fiscal_year, account;
```
