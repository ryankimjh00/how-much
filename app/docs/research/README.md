# 얼마였지 백엔드 서비스 조사

## AWS Amplify 집중 조사

[AWS Amplify 집중 조사 PDF](얼마였지_AWS_Amplify_집중조사보고서_v1.0.pdf) · [HTML 원본](얼마였지_AWS_Amplify_집중조사보고서_v1.0.html)

현재 보고서는 AWS Amplify만 조사한 A4 세로 14쪽 문서다. Gen 1·Gen 2 차이, 인증과 권한, 오프라인 동기화·충돌, 구매 트랜잭션, 가격 조회·공유, Flutter 연동, 비용과 검증 조건을 다룬다. 공식 출처 26개를 연결했으며 기술 채택 결론은 유보한다.

본문은 [build_amplify_report.py](build_amplify_report.py)에 있으며 기존 백엔드 보고서의 스타일을 재사용한다.

```bash
/tmp/howmuch-research-venv/bin/python docs/research/build_amplify_report.py
```

한글 추출·글꼴 포함·전체 페이지 배치·출처 번호·링크·범위를 확인했다. 검수 기록은 [verification-amplify-v1.0.json](verification-amplify-v1.0.json)에 있다. 예제는 실행하거나 AWS에 배포하지 않았으며 앱 코드와 플랫폼 설정을 변경하지 않았다.

## 이전 백엔드 비교 조사

[백엔드 조사 PDF](얼마였지_백엔드서비스_조사보고서_v1.0.pdf) · [HTML 원본](얼마였지_백엔드서비스_조사보고서_v1.0.html)

이전 비교 보고서는 백엔드만 조사한 A4 세로 13쪽 문서다. Firebase·Supabase·AWS Amplify의 특장점·제약과 목록 동기화, 구매 확정, 가격 조회·공유의 구현 방법을 비교한다. OCR 기술과 프레임워크 비교는 포함하지 않는다. 공식 출처 23개를 연결했으며 기술 채택 결론은 유보한다.

본문과 스타일은 [build_backend_report.py](build_backend_report.py)에 있다. 재생성은 다음 명령으로 실행한다. 도구·글꼴 조건은 아래 기록과 같다.

```bash
/tmp/howmuch-research-venv/bin/python docs/research/build_backend_report.py
```

한글 추출·글꼴 포함·전체 페이지 배치·출처 번호·범위를 확인했다. 검수 기록은 [verification-backend-v1.0.json](verification-backend-v1.0.json)에 있다. 예제는 설명용이며 실행·배포한 결과가 아니다. 앱 코드와 플랫폼 설정을 변경하지 않았다.

## 이전 범위 확장 문서

아래 문서는 요청 범위를 벗어난 이전 산출물이며 현재 백엔드 조사 보고서로 대체한다.

[PDF 보고서](얼마였지_모바일AI_SW기술_조사보고서_v1.0.pdf) · [HTML 원본](얼마였지_모바일AI_SW기술_조사보고서_v1.0.html)

2026년 10월 9일 작성한 순수 조사 자료다. 제안서·요구사항 분석서·UI 설계서와 기존 크로스플랫폼 조사를 기준으로 Flutter·React Native, ML Kit·Tesseract, 로컬 저장, Firebase·Supabase·AWS Amplify를 비교한다. 백엔드는 목록 동기화·구매 확정·가격 조회의 구현 방법과 추가 개발 조건을 다룬다. 채택 기술과 성능 우열은 확정하지 않는다.

공식 출처 40개를 본문 인용 번호와 연결했다. 예제는 설명용 코드이며 서비스에 배포하거나 실행 검증한 결과가 아니다. 앱 코드와 플랫폼 설정을 변경하지 않았으며 앱 테스트도 재실행하지 않았다.

PDF는 A4 세로 18쪽이다. 한글 텍스트 추출, 글꼴 포함, 전체 페이지 배치, 출처 번호와 링크를 확인했다. 문서 검수 기록은 [verification-v1.0.json](verification-v1.0.json)에 있다.

본문과 스타일은 [build_research_report.py](build_research_report.py)를 수정해 재생성한다. Python 가상환경에 WeasyPrint 70.0이 필요하며, 글꼴은 앱의 NotoSansKR과 시스템 Noto Sans Mono CJK KR을 사용한다.

```bash
/tmp/howmuch-research-venv/bin/python docs/research/build_research_report.py
```
