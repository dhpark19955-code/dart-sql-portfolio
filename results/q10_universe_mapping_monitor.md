# q10_universe_mapping_monitor

Q10. 유니버스를 200사로 넓혔을 때 계정 매핑과 커버리지는 어디서 새는가 (2단계 품질 모니터)
기법: 뷰(v_qc_unmapped_accounts, v_qc_company_coverage) 위에 UNION ALL 로 점검 묶기, 조건부 집계, HAVING
읽는 법: 'A_unmapped_account' 행 = dim_account_map 에 추가할 후보 (회사 수가 많을수록 우선)
'B_no_revenue' 행 = 매출액 계정이 없는 회사 (금융업·지주사는 영업수익·순영업수익 → 보충 또는 성격 플래그)
'C_identity_fail' 행 = 자산 ≠ 부채 + 자본
'0_summary' 행 = 전체 규모
주의: 주요계정 API 는 계정명만 주고 account_id 가 없어 매핑은 계정명 기준. 전체 재무제표 API 행은 account_id 우선
전체 재무제표 API 의 미매핑(유형자산·임차보증금 등 100여 계정)은 표준 계정 20여 개만 매핑하는 정책상 당연한 것 - REVIEW 로만 표시
'E_full_fs_fallback' = 주요계정 API 가 안 주는 회사를 전체 재무제표(별도)로 채운 경우

## Result (255 rows)

| check_name         | subject                                          | detail                                                                                                                                  | result     |   n |
|:-------------------|:-------------------------------------------------|:----------------------------------------------------------------------------------------------------------------------------------------|:-----------|----:|
| 0_summary          | universe                                         | companies=200, company_years=1286, fact_rows=18981, unmapped_rows=761 (key_accounts=0, full_fs=761), unmapped_pct=4.0, ofs_only_years=9 | INFO       |     |
| A_unmapped_account | BS / 기타부채 [full_fs]                              | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | BS / 기타자산 [full_fs]                              | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | BS / 무형자산 [full_fs]                              | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | BS / 유형자산 [full_fs]                              | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | CF / 무형자산의 취득 [full_fs]                          | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | CF / 유형자산의 취득 [full_fs]                          | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | CF / 이자의 수취 [full_fs]                            | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | CF / 임차보증금의 감소 [full_fs]                         | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | CF / 임차보증금의 증가 [full_fs]                         | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | SCE / 기초자본 [full_fs]                             | companies=3, rows=9, years=2023~2025                                                                                                    | REVIEW     |   3 |
| A_unmapped_account | BS / 기타금융부채 [full_fs]                            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 기타금융자산 [full_fs]                            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 기타포괄손익누계액 [full_fs]                         | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 당기법인세자산 [full_fs]                           | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 상각후원가측정대출채권 [full_fs]                       | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 상각후원가측정유가증권 [full_fs]                       | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 자본과부채총계 [full_fs]                           | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 자본조정 [full_fs]                              | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 충당부채 [full_fs]                              | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / 현금및현금성자산 [full_fs]                          | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 기타포괄손익-공정가치측정금융자산의 처분 [full_fs]             | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 기타포괄손익-공정가치측정금융자산의 취득 [full_fs]             | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 리스부채의 상환 [full_fs]                          | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 무형자산의 처분 [full_fs]                          | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 법인세 납부 [full_fs]                            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 상각후원가측정유가증권의 취득 [full_fs]                   | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 영업에서 창출된 현금흐름 [full_fs]                     | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 유형자산의 처분 [full_fs]                          | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 이자의 지급 [full_fs]                            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 재무활동으로 인한 현금흐름 [full_fs]                    | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CF / 투자활동으로 인한 현금흐름 [full_fs]                    | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CIS / 기타포괄손익 [full_fs]                           | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | CIS / 법인세비용 [full_fs]                            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | SCE / 기타포괄손익-공정가치측정금융자산평가손익 [full_fs]            | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | SCE / 유상증자 [full_fs]                             | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | SCE / 자본총계 [full_fs]                             | companies=2, rows=6, years=2023~2025                                                                                                    | REVIEW     |   2 |
| A_unmapped_account | BS / (대손준비금 미적립액) [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / (대손준비금 적립액) [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / (대손준비금 전입예정액) [full_fs]                     | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / (대손준비금 환입(전입) 필요액) [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 관계기업등에대한투자자산 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 관계기업투자주식 [full_fs]                          | companies=1, rows=2, years=2024~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 기타자본항목 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 기타포괄손익누적액 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 당기법인세부채 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 대손준비금 적립액 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 대손준비금 전입(환입) 예정액 [full_fs]                  | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 대손준비금 전입(환입) 필요액 [full_fs]                  | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 리스부채 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 매입채무 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 매출채권 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 사용권자산 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 순확정급여부채 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 순확정급여자산 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 신종자본증권 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 이연법인세부채 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 이연법인세자산 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 자본과 부채 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 자본잉여금 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 재고자산 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 주식발행초과금 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 차입금 [full_fs]                               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 현금및예치금 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 확정급여부채 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | BS / 확정급여자산 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / IX. 당기순이익 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / RSU 상환 [full_fs]                            | companies=1, rows=2, years=2024~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 감가상각비 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 관계기업투자자산관련손익 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 관계기업투자자산의 취득 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 관계기업투자주식 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 국고보조금의 수취 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 금융자산신용손실충당금전입액 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기말 현금및현금성자산 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기말현금및현금성자산 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기초 현금및현금성자산 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기초의 현금및현금성자산 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기초현금및현금성자산 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타금융자산의 증가 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타금융자산의 처분 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타부채 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타손익 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타자산 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 기타포괄손익-공정가치측정금융자산관련손익 [full_fs]             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 단기차입금의 상환 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 단기차입금의 차입 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기손익-공정가치측정금융상품 [full_fs]                   | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기손익-공정가치측정금융상품관련손익 [full_fs]               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기손익-공정가치측정금융자산의 처분 [full_fs]               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기손익-공정가치측정금융자산의 취득 [full_fs]               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기손익공정가치측정금융자산의 취득 [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기순이익 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 당기순이익조정을 위한 가감 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 대여금의 감소 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 대여금의 증가 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 리스부채의 감소 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 무형자산관련손익 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 무형자산상각비 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 배당금 수입 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 배당금의 지급 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 법인세비용 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 법인세의 납부 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 비유동성차입금의 차입 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 상각후원가측정대출채권 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 상각후원가측정유가증권의 상환 [full_fs]                   | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 상각후원가측정유가증권의 처분 [full_fs]                   | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 선급금의 증가 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 순확정급여자산 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 신종자본증권 배당금의 지급 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 신종자본증권의 발행 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 신주발행 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 영업으로부터창출된현금흐름 [full_fs]                     | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 영업활동 현금흐름 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 영업활동으로 인한 자산 부채의 변동 [full_fs]               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 영업활동으로 인한 자산부채의 변동 [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 예수부채 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 예치금 [full_fs]                               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 외화환산손익 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 유동성장기차입금의 상환 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 유상증자 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 유형자산관련손익 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 이자비용 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 이자수익 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 이자지급 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 자기주식의 취득 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 자본 발행의 거래원가 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 재무활동 현금흐름 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 전환가능상품의 발행으로 인한 현금 유입 [full_fs]             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 주식발행비용 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 주식보상비용 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 차입부채의 순증감 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 충당부채 [full_fs]                              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 충당부채전(환)입액 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 파생상품자산의 처분 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금및현금성자산 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금및현금성자산 증가 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금및현금성자산 환율변동효과 [full_fs]                   | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금및현금성자산의 증가 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금및현금성자산의순증가(감소) [full_fs]                  | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 현금의 유출입이 없는 비용(수익)등의 가감 [full_fs]           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CF / 확정급여형퇴직급여 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 1. 기본주당이익 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 1. 기타포괄손익-공정가치측정금융자산평가손익 [full_fs]         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 1. 순확정급여자산의 재측정요소 [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 1. 이자비용 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 2. 관계기업 기타포괄손익에 대한 지분 [full_fs]            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 2. 수수료비용 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 2. 수수료수익 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 2. 희석주당이익 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 3. 당기손익-공정가치측정금융상품관련손실 [full_fs]           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 3. 당기손익-공정가치측정금융상품관련이익 [full_fs]           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 4. 기타포괄손익-공정가치측정금융자산관련손실 [full_fs]         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 4. 기타포괄손익-공정가치측정금융자산관련이익 [full_fs]         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 5. 기타의영업수익 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 5. 판매비와관리비 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 6. 기타의영업비용 [full_fs]                       | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / II. 영업비용 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / V. 영업외수익 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / VI. 영업외비용 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / VIII. 법인세비용 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / X. 기타포괄손익 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / Ⅲ. 금융자산신용손실충당금전입액 [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 금융수익 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 금융원가 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기본주당순이익 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기본주당이익 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기타비용 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기타수익 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기타영업손익 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 기타포괄손익-공정가치측정지분상품평가손익 [full_fs]            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 당기손익-공정가치측정금융자산관련이익 [full_fs]              | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 당기손익으로 재분류 되지않는 세후기타포괄손익 [full_fs]         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 당기손익으로 재분류되는 세후기타포괄손익 [full_fs]            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 대손준비금 반영 후 조정이익 [full_fs]                  | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 대손준비금 반영후 조정이익 [full_fs]                   | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 세후기타포괄손익, 기타포괄손익-공정가치로 측정되는 금융자산 [full_fs] | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 수수료비용 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 수수료수익 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 순확정급여부채의재측정요소 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 신용손실에 대한 손상차손 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 영업외손익 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 일반관리비 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 지분법기타포괄손익변동 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 지분법손익 [full_fs]                            | companies=1, rows=2, years=2024~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 확정급여제도의 재측정요소 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | CIS / 희석주당순이익 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 1. 순확정급여자산의 재측정요소 [full_fs]                | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / IX. 당기순이익 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 결손보전 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 관계기업 기타포괄손익에 대한 지분 [full_fs]               | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 기타의자본조정 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 기타자본조정 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 기타포괄손익 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 당기순이익 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 당기순이익(손실) [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 당기총포괄손익 [full_fs]                          | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 상환전환우선주의 발행 [full_fs]                      | companies=1, rows=1, years=2025~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 소유주와의 거래 총액 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 순확정급여부채의재측정요소 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 신종자본증권 발행 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 신종자본증권 배당 [full_fs]                        | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 연차배당 [full_fs]                             | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 자기주식의 취득 [full_fs]                         | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 자본 총계 [full_fs]                            | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 자본잉여금의 이익잉여금 전환 [full_fs]                  | companies=1, rows=1, years=2024~2024                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 자본조정 잉여금 처분 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 주식기준보상 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 주식보상비용 [full_fs]                           | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 지분법기타포괄손익변동 [full_fs]                      | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| A_unmapped_account | SCE / 확정급여제도의 재측정요소 [full_fs]                    | companies=1, rows=3, years=2023~2025                                                                                                    | REVIEW     |   1 |
| B_no_revenue       | BNK금융지주                                          | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | DB손해보험                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | JB금융지주                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | KB금융                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | NH투자증권                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | iM금융지주                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 기업은행                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 미래에셋생명                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 삼성생명                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 삼성증권                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 삼성화재                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 신한지주                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 우리금융지주                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 코리안리                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 하나금융지주                                           | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 한화생명                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 현대해상                                             | years_without_revenue=5/5 (financial)                                                                                                   | EXPECTED   |   5 |
| B_no_revenue       | 삼성카드                                             | years_without_revenue=3/5 (financial)                                                                                                   | EXPECTED   |   3 |
| B_no_revenue       | 서울보증보험                                           | years_without_revenue=3/3 (financial)                                                                                                   | EXPECTED   |   3 |
| B_no_revenue       | 케이뱅크                                             | years_without_revenue=3/3 (financial)                                                                                                   | EXPECTED   |   3 |
| B_no_revenue       | 한국금융지주                                           | years_without_revenue=3/5 (financial)                                                                                                   | EXPECTED   |   3 |
| B_no_revenue       | 한화비전                                             | years_without_revenue=2/4                                                                                                               | SUPPLEMENT |   2 |
| B_no_revenue       | 달바글로벌                                            | years_without_revenue=1/4                                                                                                               | SUPPLEMENT |   1 |
| B_no_revenue       | 한전기술                                             | years_without_revenue=1/5                                                                                                               | SUPPLEMENT |   1 |
| C_identity_fail    | SK텔레콤                                            | years=1                                                                                                                                 | FAIL       |   1 |
| D_missing_years    | HD현대마린솔루션                                        | years_loaded=4 (expected 5)                                                                                                             | WARN       |   4 |
| D_missing_years    | 달바글로벌                                            | years_loaded=4 (expected 5)                                                                                                             | WARN       |   4 |
| D_missing_years    | 두산퓨얼셀                                            | years_loaded=4 (expected 5)                                                                                                             | WARN       |   4 |
| D_missing_years    | 신영증권                                             | years_loaded=4 (expected 5)                                                                                                             | WARN       |   4 |
| D_missing_years    | 한화비전                                             | years_loaded=4 (expected 5)                                                                                                             | WARN       |   4 |
| D_missing_years    | 대한조선                                             | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | 산일전기                                             | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | 서울보증보험                                           | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | 시프트업                                             | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | 에코프로머티                                           | years_loaded=3 (expected 5), ofs_only=3                                                                                                 | WARN       |   3 |
| D_missing_years    | 이수스페셜티케미컬                                        | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | 카카오뱅크                                            | years_loaded=3 (expected 5), ofs_only=3                                                                                                 | WARN       |   3 |
| D_missing_years    | 케이뱅크                                             | years_loaded=3 (expected 5), ofs_only=3                                                                                                 | WARN       |   3 |
| D_missing_years    | 케이씨텍                                             | years_loaded=3 (expected 5)                                                                                                             | WARN       |   3 |
| D_missing_years    | KB발해인프라                                          | years_loaded=0 (expected 5)                                                                                                             | WARN       |   0 |
| D_missing_years    | 맥쿼리인프라                                           | years_loaded=0 (expected 5)                                                                                                             | WARN       |   0 |
| E_full_fs_fallback | 에코프로머티                                           | years_via_full_fs=3, ofs_only=3                                                                                                         | INFO       |   3 |
| E_full_fs_fallback | 카카오뱅크                                            | years_via_full_fs=3, ofs_only=3                                                                                                         | INFO       |   3 |
| E_full_fs_fallback | 케이뱅크                                             | years_via_full_fs=3, ofs_only=3                                                                                                         | INFO       |   3 |

## SQL

```sql
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
```
