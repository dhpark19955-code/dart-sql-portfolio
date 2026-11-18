-- Q10. 유니버스를 200사로 넓혔을 때 계정 매핑과 커버리지는 어디서 새는가 (2단계 품질 모니터)
-- 기법: 뷰(v_qc_unmapped_accounts, v_qc_company_coverage) 위에 UNION ALL 로 점검 묶기, 조건부 집계, HAVING
-- 읽는 법: 'A_unmapped_account' 행 = dim_account_map 에 추가할 후보 (회사 수가 많을수록 우선)
--          'B_no_revenue' 행 = 매출액 계정이 없는 회사 (금융업·지주사는 영업수익·순영업수익 → 보충 또는 성격 플래그)
--          'C_identity_fail' 행 = 자산 ≠ 부채 + 자본
--          '0_summary' 행 = 전체 규모
-- 주의: 주요계정 API 는 계정명만 주고 account_id 가 없어 매핑은 계정명 기준. 전체 재무제표 API 행은 account_id 우선
--       전체 재무제표 API 의 미매핑(유형자산·임차보증금 등 100여 계정)은 표준 계정 20여 개만 매핑하는 정책상 당연한 것 - REVIEW 로만 표시
--       'E_full_fs_fallback' = 주요계정 API 가 안 주는 회사를 전체 재무제표(별도)로 채운 경우

SELECT '0_summary' AS check_name,
       'universe' AS subject,
       'companies=' || CAST((SELECT COUNT(*) FROM dim_company) AS VARCHAR) ||
       ', company_years=' || CAST((SELECT COUNT(*) FROM v_fin_annual) AS VARCHAR) ||
       ', fact_rows=' || CAST((SELECT COUNT(*) FROM fs_fact) AS VARCHAR) ||
       ', unmapped_rows=' || CAST((SELECT COUNT(*) FROM fs_fact WHERE std_account IS NULL) AS VARCHAR) ||
       ' (key_accounts=' || CAST((SELECT COUNT(*) FROM fs_fact WHERE std_account IS NULL AND source = 'key_accounts') AS VARCHAR) ||
       ', full_fs=' || CAST((SELECT COUNT(*) FROM fs_fact WHERE std_account IS NULL AND source = 'full_fs') AS VARCHAR) || ')' ||
       ', unmapped_pct=' || CAST((SELECT ROUND(100.0 * SUM(CASE WHEN std_account IS NULL THEN 1 ELSE 0 END) / COUNT(*), 1) FROM fs_fact) AS VARCHAR) ||
       ', ofs_only_years=' || CAST((SELECT COUNT(*) FROM v_fin_annual WHERE fs_div = 'OFS') AS VARCHAR) AS detail,
       'INFO' AS result,
       NULL   AS n

UNION ALL

SELECT 'A_unmapped_account',
       sj_div || ' / ' || account_nm || ' [' || source || ']',
       'companies=' || CAST(n_companies AS VARCHAR) || ', rows=' || CAST(n_rows AS VARCHAR) || ', years=' || years,
       CASE WHEN n_companies >= 10 THEN 'ADD_TO_MAP' ELSE 'REVIEW' END,
       n_companies
FROM v_qc_unmapped_accounts

UNION ALL

SELECT 'B_no_revenue',
       corp_name,
       'years_without_revenue=' || CAST(years_no_revenue AS VARCHAR) || '/' || CAST(n_years AS VARCHAR) ||
       CASE WHEN is_financial = 1 THEN ' (financial)' ELSE '' END,
       CASE WHEN is_financial = 1 THEN 'EXPECTED' ELSE 'SUPPLEMENT' END,
       years_no_revenue
FROM v_qc_company_coverage
WHERE years_no_revenue > 0

UNION ALL

SELECT 'C_identity_fail',
       corp_name,
       'years=' || CAST(years_identity_fail AS VARCHAR),
       'FAIL',
       years_identity_fail
FROM v_qc_company_coverage
WHERE years_identity_fail > 0

UNION ALL

SELECT 'D_missing_years',
       corp_name,
       'years_loaded=' || CAST(n_years AS VARCHAR) || ' (expected 5)' ||
       CASE WHEN years_ofs_only > 0 THEN ', ofs_only=' || CAST(years_ofs_only AS VARCHAR) ELSE '' END,
       'WARN',
       n_years
FROM v_qc_company_coverage
WHERE n_years < 5

UNION ALL

SELECT 'E_full_fs_fallback',
       corp_name,
       'years_via_full_fs=' || CAST(n_years AS VARCHAR) || ', ofs_only=' || CAST(years_ofs_only AS VARCHAR),
       'INFO',
       n_years
FROM v_qc_company_coverage
WHERE years_ofs_only > 0

ORDER BY check_name, n DESC, subject;
