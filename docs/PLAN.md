# 기획 - SQL 데이터 분석 포트폴리오 (DART x KRX)

작성일: 2026-11-18

## 1. 목적

공고 요건 "SQL로 여러 테이블을 결합해 필요한 데이터를 직접 추출·가공할 수 있는 분"에 대한 증빙.
연습문제 풀이(8 Week SQL Challenge류)가 아니라, 심사역 업무에서 실제로 던지는 질문을 공개 데이터로 재현한다.

평가자가 확인할 수 있어야 하는 것:
1. ERD와 테이블 설계를 스스로 했다 (staging / 분석용 분리)
2. 원천 데이터 정제를 SQL로 했다 (문자열 금액 → 숫자, wide ↔ long 변환, 중복 제거, 단위 통일)
3. 3개 이상 테이블 JOIN + 윈도우 함수 + CTE 를 질문 해결에 썼다
4. 각 쿼리가 어떤 비즈니스 질문에 답하는지, 결과를 어떻게 읽는지 적혀 있다
5. 데이터 한계(결측·근사치)를 숨기지 않았다

## 2. 범위 결정

| 항목 | 결정 | 이유 |
|---|---|---|
| 데이터 | 공개 데이터만 (DART, KRX) | 포트폴리오 익명화 방침과 충돌 없음 |
| 유니버스 | 3개 섹터 13개사 | 섹터 내 순위·비중 계산이 의미 있으려면 섹터당 4사 이상 필요 |
| 기간 | FY2023~2025 (사업보고서 1건에 3개년) | 1차 스냅샷. OpenDART 키로 fy2022 추가 시 6개년 |
| 엔진 | SQLite | 파일 하나로 클론 즉시 실행 가능. 윈도우 함수·math 지원 |
| 단위 | 백만원, 표시는 십억원 | 원 단위 13자리 숫자는 읽기 어려움 |
| 음수 표기 | -(하이픈) | △ 표기 사용 안 함 |

제외한 것: 분기 데이터(당기/누적 혼재로 정제 복잡도만 올라감), 비상장사, 사내 데이터 일체.

## 3. 테이블 설계

```
stg_companies            raw CSV 그대로
stg_dart_key_accounts    API 응답 그대로 (금액 문자열, 3개년 wide)
stg_prices_daily         yfinance 그대로
stg_shares_outstanding   KRX 목록 그대로
        │  02_load_clean.sql
        ▼
companies (13)  1─<  financials_annual (회사x연도 1행, 백만원)
                1─<  prices_daily (회사x거래일)
                1─1  shares_outstanding
```

설계 포인트
- `financials_annual` PK = (corp_code, fiscal_year, fs_div): 연결/별도 둘 다 넣을 수 있게 fs_div를 키에 포함
- `source_rcept_no` 컬럼으로 모든 숫자의 출처 접수번호 추적 가능
- `companies.delisted_date`: 상장폐지 종목을 지우지 않고 표시만 해서 LEFT JOIN 결측 사례로 활용

## 4. 분석 질문 (완료)

| # | 질문 | 핵심 기법 |
|---|---|---|
| q1 | 섹터 내 영업이익률 순위, YoY 성장 | JOIN, LAG, RANK PARTITION |
| q2 | 연말 시가총액·PER·PBR | ROW_NUMBER(연말 거래일), 3테이블 JOIN, LEFT JOIN |
| q3 | 섹터 합산 대비 비중 변화, CAGR | SUM OVER PARTITION, POWER |
| q4 | 흑자전환/적자전환 + 재무건전성 | LAG + CASE 라벨, 복합 조건 |
| q5 | 주가 수익률 vs 이익 변화 괴리 | FIRST/LAST_VALUE, WINDOW 절 |
| q6 | 데이터 품질 점검 | UNION ALL, LEFT JOIN IS NULL |
| q7 | 주요사항보고서 건수 vs 주가 변동폭 | CROSS JOIN 뼈대 + LEFT JOIN, CASE 조건부 집계 |
| q8 | 분기 데이터 품질 점검 | SUM OVER 누적 ↔ LAG 차분 왕복, UNION ALL |
| q9 | 2025년 분기 추세 | LAG(…,4) 전년 동기, LAG(…,1) QoQ |
| q10 | 200사 매핑·커버리지 모니터 | 품질점검 뷰 + UNION ALL |
| q11 | 1단계 vs 2단계 교차검증 | JOIN + UNPIVOT, IS NOT |
| q12 | 업종별 수익성·성장 | 3테이블 JOIN, 윈도우 중앙값, POWER |
| q13 | 성장·수익성·건전성 스크리닝 | 조건부 집계, 복합 플래그, RANK PARTITION |
| q14 | 공시 이벤트 x 재무 | 유형 플래그, 세로 펼친 창 함수 중앙값, UNION ALL |
| q15 | 공시 → 이듬해 실적 | LEAD, 뼈대 LEFT JOIN, 그룹 중앙값 |

## 5. 단계별 계획

### Phase 1 - 완료 (이 채팅에서)
- [x] 유니버스·섹터 분류 확정, DART corp_code 매핑
- [x] FY2025 사업보고서 주요계정 스냅샷 (13사 x 8계정 x 3개년)
- [x] 주가(yfinance)·주식수(KRX) 수집 스크립트 및 데이터
- [x] 스키마·정제 SQL·빌드 스크립트
- [x] 분석 쿼리 6개 + 결과 md 자동 생성
- [x] README 초안

### Phase 2 - Claude Code (CLAUDE.md 참조)
- [x] FY2020~2022 추가 → 6개년, q3 CAGR 기간 확장 (MCP 경유, 3사 매출 보충)
- [x] DART 공시목록(list.json)으로 `filings` 테이블 추가 (q7) → "주요사항보고서 건수 vs 주가 변동" 같은 4번째 JOIN 축
- [x] 더존비즈온 주식수 보완: 사업보고서 자본금 / 액면가 500원 = 31,477,993주 (추정, 출처 명시) → q2 NULL 해소 여부 결정
- [ ] PostgreSQL 호환성 검증 (SQLite 전용 문법 없는지) - 선택
- [x] README 결과 요약을 results/ 재생성 후 최신 수치로 갱신
- [ ] GitHub push (별도 레포 또는 claude-code-data-portfolio 하위 폴더)

### Phase 3 - 선택
- [x] 분기 데이터로 확장 (2026-11-18): 당기·전기 열 UNPIVOT, 최신 보고서 우선, 4분기 도출, 누적↔3개월 왕복 검증. 상세는 LARGE_SCALE_PLAN.md 6절 1단계
- [x] 2단계 (2026-11-18): KOSPI 시총 상위 200사 x 사업보고서 2021~2025 를 raw/staging/core/mart 4계층 + dim 4개로 적재, 미매핑 모니터(q10)·교차검증(q11)·업종 프로필(q12)·스크리닝(q13)
- [x] 3단계 (2026-11-18): 전체 재무제표 API 대체 경로(account_id 매핑), 증분 적재(--incremental), DuckDB 대조(ENGINE_PARITY.md)
- [x] 4단계 (2026-11-18): 200사 주요사항보고서 778건 유형 분류, 공시 x 재무(q14), 공시 → 이듬해 실적(q15)
- [ ] 간단한 HTML 대시보드(results 표 렌더링)를 GitHub Pages에
- [ ] 공시 본문 파싱(합병 비율·조달 금액), 200사 주가 수집

## 6. 알려진 한계 (README에도 명시)
- 주식수가 현재 기준이라 과거 시가총액은 근사치
- 더존비즈온은 2026-07 상장폐지로 yfinance 이력 없음
- 섹터 분류는 본인 기준 (삼성SDS를 IT인프라/SaaS에 넣은 것은 논쟁 여지 있음)
- 13개 표본으로 통계적 결론은 내지 않음
