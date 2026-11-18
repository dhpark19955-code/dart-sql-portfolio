# q6_data_quality

Q6. 분석 전에 데이터가 믿을 만한지 확인한다
점검 1) 회계 항등식: 자산총계 = 부채총계 + 자본총계 (백만원 반올림 오차 ±2 허용)
점검 2) 재무제표는 있는데 주가가 없는 회사 (상장폐지·티커 오류 탐지)
점검 3) 종목별 거래일 수 - 다른 종목과 크게 다르면 수집 누락 의심
기법: UNION ALL로 점검 결과를 한 표로, LEFT JOIN + IS NULL 로 결측 탐지, ABS/HAVING

## Result (13 rows)

| check_name       | subject   | detail                            | result   | diff_mn   |
|:-----------------|:----------|:----------------------------------|:---------|:----------|
| 2_missing_prices | 더존비즈온     | delisted 2026-07-15               | WARN     |           |
| 3_trading_days   | NAVER     | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | NC        | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | NHN       | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | SOOP      | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 가비아       | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 넷마블       | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 삼성에스디에스   | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 카카오       | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 카카오게임즈    | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 케이아이엔엑스   | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 크래프톤      | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |
| 3_trading_days   | 헥토이노베이션   | days=730, 2023-01-02 ~ 2025-12-30 | OK       |           |

## SQL

```sql
-- Q6. 분석 전에 데이터가 믿을 만한지 확인한다
-- 점검 1) 회계 항등식: 자산총계 = 부채총계 + 자본총계 (백만원 반올림 오차 ±2 허용)
-- 점검 2) 재무제표는 있는데 주가가 없는 회사 (상장폐지·티커 오류 탐지)
-- 점검 3) 종목별 거래일 수 - 다른 종목과 크게 다르면 수집 누락 의심
-- 기법: UNION ALL로 점검 결과를 한 표로, LEFT JOIN + IS NULL 로 결측 탐지, ABS/HAVING

SELECT '1_accounting_identity' AS check_name,
       c.corp_name              AS subject,
       CAST(f.fiscal_year AS TEXT) AS detail,
       CASE WHEN ABS(f.total_assets - (f.total_liab + f.total_equity)) <= 2 THEN 'OK' ELSE 'FAIL' END AS result,
       f.total_assets - (f.total_liab + f.total_equity) AS diff_mn
FROM financials_annual f
JOIN companies c ON c.corp_code = f.corp_code
WHERE ABS(f.total_assets - (f.total_liab + f.total_equity)) > 2   -- 통과한 행은 생략

UNION ALL

SELECT '2_missing_prices',
       c.corp_name,
       COALESCE('delisted ' || c.delisted_date, 'ticker check needed'),
       'WARN',
       NULL
FROM companies c
LEFT JOIN prices_daily p ON p.stock_code = c.stock_code
WHERE p.stock_code IS NULL

UNION ALL

SELECT '3_trading_days',
       c.corp_name,
       'days=' || COUNT(*) || ', ' || MIN(p.trade_date) || ' ~ ' || MAX(p.trade_date),
       CASE WHEN COUNT(*) < (SELECT MAX(cnt) FROM (SELECT COUNT(*) AS cnt FROM prices_daily GROUP BY stock_code)) * 0.95
            THEN 'WARN' ELSE 'OK' END,
       NULL
FROM prices_daily p
JOIN companies c ON c.stock_code = p.stock_code
GROUP BY c.corp_name

ORDER BY check_name, subject;
```
