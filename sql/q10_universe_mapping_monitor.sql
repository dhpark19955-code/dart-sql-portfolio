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
