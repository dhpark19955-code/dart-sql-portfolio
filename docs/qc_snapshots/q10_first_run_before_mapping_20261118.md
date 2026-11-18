# q10_universe_mapping_monitor

Q10. 유니버스를 200사로 넓혔을 때 계정 매핑과 커버리지는 어디서 새는가 (2단계 품질 모니터)
기법: 뷰(v_qc_unmapped_accounts, v_qc_company_coverage) 위에 UNION ALL 로 점검 묶기, 조건부 집계, HAVING
읽는 법: 'A_unmapped_account' 행 = dim_account_map 에 추가할 후보 (회사 수가 많을수록 우선)
'B_no_revenue' 행 = 매출액 계정이 없는 회사 (금융업·지주사는 영업수익·순영업수익 → 보충 또는 성격 플래그)
'C_identity_fail' 행 = 자산 ≠ 부채 + 자본
'0_summary' 행 = 전체 규모
주의: 주요계정 API 는 계정명만 주고 account_id 가 없어 매핑은 계정명 기준. 전체 재무제표 API 로 바꾸면 account_id 우선

## Result (71 rows)

| check_name         | subject                | detail                                                                                  | result     |   n |
|:-------------------|:-----------------------|:----------------------------------------------------------------------------------------|:-----------|----:|
| 0_summary          | universe               | companies=200, company_years=1277, fact_rows=18140, unmapped_rows=849, unmapped_pct=4.7 | INFO       |     |
| A_unmapped_account | BS / 당기손익-공정가치측정금융자산   | companies=25, rows=114, years=2021~2025                                                 | ADD_TO_MAP |  25 |
| A_unmapped_account | BS / 기타포괄손익-공정가치측정금융자산 | companies=24, rows=110, years=2021~2025                                                 | ADD_TO_MAP |  24 |
| A_unmapped_account | BS / 차입부채              | companies=20, rows=81, years=2021~2025                                                  | ADD_TO_MAP |  20 |
| A_unmapped_account | BS / 상각후원가측정금융자산       | companies=17, rows=76, years=2021~2025                                                  | ADD_TO_MAP |  17 |
| A_unmapped_account | BS / 파생상품자산            | companies=17, rows=77, years=2021~2025                                                  | ADD_TO_MAP |  17 |
| A_unmapped_account | BS / 예수부채              | companies=16, rows=75, years=2021~2025                                                  | ADD_TO_MAP |  16 |
| A_unmapped_account | BS / 파생상품부채            | companies=15, rows=69, years=2021~2025                                                  | ADD_TO_MAP |  15 |
| A_unmapped_account | BS / 보험계약부채            | companies=14, rows=66, years=2021~2025                                                  | ADD_TO_MAP |  14 |
| A_unmapped_account | IS / 순수수료손익            | companies=12, rows=56, years=2021~2025                                                  | ADD_TO_MAP |  12 |
| A_unmapped_account | IS / 순이자손익             | companies=12, rows=56, years=2021~2025                                                  | ADD_TO_MAP |  12 |
| A_unmapped_account | BS / 보험계약자산            | companies=9, rows=41, years=2021~2025                                                   | REVIEW     |   9 |
| A_unmapped_account | IS / 금융상품관련순손익         | companies=3, rows=10, years=2022~2025                                                   | REVIEW     |   3 |
| A_unmapped_account | IS / 파생상품관련손익          | companies=3, rows=15, years=2021~2025                                                   | REVIEW     |   3 |
| A_unmapped_account | BS / 금융부채              | companies=1, rows=3, years=2021~2023                                                    | REVIEW     |   1 |
| B_no_revenue       | BNK금융지주                | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | DB손해보험                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | JB금융지주                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | KB금융                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | NH투자증권                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | iM금융지주                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 기업은행                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 미래에셋생명                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 삼성생명                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 삼성증권                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 삼성화재해상보험               | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 신한지주                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 우리금융지주                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 코리안리                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 하나금융지주                 | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 한화생명                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 현대해상                   | years_without_revenue=5/5                                                               | SUPPLEMENT |   5 |
| B_no_revenue       | 서울보증보험                 | years_without_revenue=3/3                                                               | SUPPLEMENT |   3 |
| B_no_revenue       | DL이앤씨                  | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | F&F                    | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 더블유게임즈                 | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 롯데렌탈                   | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 카카오                    | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 카카오페이                  | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 크래프톤                   | years_without_revenue=2/7                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 한화비전                   | years_without_revenue=2/4                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | KB발해인프라                | years_without_revenue=1/0                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | LG에너지솔루션               | years_without_revenue=1/7                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 달바글로벌                  | years_without_revenue=1/4                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 대덕전자                   | years_without_revenue=1/7                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 맥쿼리인프라                 | years_without_revenue=1/0                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 삼성카드                   | years_without_revenue=1/5                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 에코프로머티                 | years_without_revenue=1/0                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 카카오뱅크                  | years_without_revenue=1/0                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 케이뱅크                   | years_without_revenue=1/0                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 한국금융지주                 | years_without_revenue=1/5                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 한전기술                   | years_without_revenue=1/7                                                               | SUPPLEMENT |   1 |
| C_identity_fail    | SK텔레콤                  | years=1                                                                                 | FAIL       |   1 |
| C_identity_fail    | 금호석유화학                 | years=1                                                                                 | FAIL       |   1 |
| C_identity_fail    | 한화                     | years=1                                                                                 | FAIL       |   1 |
| D_missing_years    | HD현대마린솔루션              | years_loaded=4 (expected 5)                                                             | WARN       |   4 |
| D_missing_years    | 달바글로벌                  | years_loaded=4 (expected 5)                                                             | WARN       |   4 |
| D_missing_years    | 두산퓨얼셀                  | years_loaded=4 (expected 5)                                                             | WARN       |   4 |
| D_missing_years    | 신영증권                   | years_loaded=4 (expected 5)                                                             | WARN       |   4 |
| D_missing_years    | 한화비전                   | years_loaded=4 (expected 5)                                                             | WARN       |   4 |
| D_missing_years    | 대한조선                   | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | 산일전기                   | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | 서울보증보험                 | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | 시프트업                   | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | 이수스페셜티케미컬              | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | 케이씨텍                   | years_loaded=3 (expected 5)                                                             | WARN       |   3 |
| D_missing_years    | KB발해인프라                | years_loaded=0 (expected 5)                                                             | WARN       |   0 |
| D_missing_years    | 맥쿼리인프라                 | years_loaded=0 (expected 5)                                                             | WARN       |   0 |
| D_missing_years    | 에코프로머티                 | years_loaded=0 (expected 5)                                                             | WARN       |   0 |
| D_missing_years    | 카카오뱅크                  | years_loaded=0 (expected 5)                                                             | WARN       |   0 |
| D_missing_years    | 케이뱅크                   | years_loaded=0 (expected 5)                                                             | WARN       |   0 |

## SQL

```sql
-- Q10. 유니버스를 200사로 넓혔을 때 계정 매핑과 커버리지는 어디서 새는가 (2단계 품질 모니터)
-- 기법: 뷰(v_qc_unmapped_accounts, v_qc_company_coverage) 위에 UNION ALL 로 점검 묶기, 조건부 집계, HAVING
-- 읽는 법: 'A_unmapped_account' 행 = dim_account_map 에 추가할 후보 (회사 수가 많을수록 우선)
--          'B_no_revenue' 행 = 매출액 계정이 없는 회사 (금융업·지주사는 영업수익·순영업수익 → 보충 또는 성격 플래그)
--          'C_identity_fail' 행 = 자산 ≠ 부채 + 자본
--          '0_summary' 행 = 전체 규모
-- 주의: 주요계정 API 는 계정명만 주고 account_id 가 없어 매핑은 계정명 기준. 전체 재무제표 API 로 바꾸면 account_id 우선

SELECT '0_summary' AS check_name,
       'universe' AS subject,
       'companies=' || (SELECT COUNT(*) FROM dim_company) ||
       ', company_years=' || (SELECT COUNT(*) FROM fin_annual_wide WHERE fs_div = 'CFS') ||
       ', fact_rows=' || (SELECT COUNT(*) FROM fs_fact) ||
       ', unmapped_rows=' || (SELECT COUNT(*) FROM fs_fact WHERE std_account IS NULL) ||
       ', unmapped_pct=' || (SELECT ROUND(100.0 * SUM(std_account IS NULL) / COUNT(*), 1) FROM fs_fact) AS detail,
       'INFO' AS result,
       NULL   AS n

UNION ALL

SELECT 'A_unmapped_account',
       sj_div || ' / ' || account_nm,
       'companies=' || n_companies || ', rows=' || n_rows || ', years=' || years,
       CASE WHEN n_companies >= 10 THEN 'ADD_TO_MAP' ELSE 'REVIEW' END,
       n_companies
FROM v_qc_unmapped_accounts

UNION ALL

SELECT 'B_no_revenue',
       corp_name,
       'years_without_revenue=' || years_no_revenue || '/' || n_years ||
       CASE WHEN is_financial = 1 THEN ' (financial)' ELSE '' END,
       CASE WHEN is_financial = 1 THEN 'EXPECTED' ELSE 'SUPPLEMENT' END,
       years_no_revenue
FROM v_qc_company_coverage
WHERE years_no_revenue > 0

UNION ALL

SELECT 'C_identity_fail',
       corp_name,
       'years=' || years_identity_fail,
       'FAIL',
       years_identity_fail
FROM v_qc_company_coverage
WHERE years_identity_fail > 0

UNION ALL

SELECT 'D_missing_years',
       corp_name,
       'years_loaded=' || n_years || ' (expected 5)',
       'WARN',
       n_years
FROM v_qc_company_coverage
WHERE n_years < 5

ORDER BY check_name, n DESC, subject;
```
