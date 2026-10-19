# 온디바이스 AI 기술 조사

사용자가 지정한 조사 범위로 다시 작성한 현재 보고서다. 이전 조사·구현·검증 보고서를 대체하며 최종 기술 선택은 하지 않는다. 기술 비교는 지금 수행하는 범위다.

- Android·iOS·크로스플랫폼 AI 개발 도구
- 한국어 글자 검출·인식 모델과 OCR 언어 데이터
- AI 개발 도구 기본 API와 영수증 요구사항 구현 예시

[PDF](얼마였지_온디바이스AI_기술조사보고서_20261011.pdf)는 A4 20쪽이며 공식 출처 24개에 연결된다. 본문의 API·좌표 예시는 조사용이며, 실제 Android 구현·실행 결과는 별도의 비교 절에서 제시한다. 이전 Ubuntu 실험 자료는 유지했다.

`build_report.py`는 PDF·HTML을 만들고 `verify_report.py`는 범위, 페이지 수, 한글 텍스트와 출처 링크를 검사한다. 생성 도구는 `/tmp/howmuch-ai-report-env`의 별도 환경을 사용하며 앱 패키지에는 추가하지 않는다. 검수 결과는 `verification.json`에 보관한다.

Windows 저장 위치: `C:\Users\AA\Downloads\airesearch\얼마였지_온디바이스AI_기술조사보고서_20261011.pdf`.

Paddle Lite·PaddleOCR의 구분, Android Java API, iOS·크로스플랫폼 연결과 한국어 모델 배포 조건을 v1.1에서 보강했다.

v1.2에서는 실제 사진의 ML Kit·PaddleOCR·Tesseract 독립 비교를 포함했다. 기존 실행 원문의 입력 해시를 확인하고 값·좌표·공통 여백 성적을 재집계했다. ML Kit는 Android 에뮬레이터, PaddleOCR·Tesseract는 Ubuntu CPU에서 실행한 결과이므로 실기기 속도 순위로 해석하지 않는다.

v1.3에서는 영수증 앱 범위에 맞춰 일반 물체 검출 모델과 관련 출처를 제거했다. OCR의 글자 영역 검출과 모델 비교 결과는 유지했다.

v1.4에서는 상위 분류를 AI 개발 도구로 바꾸고 ML Kit는 모바일 ML SDK, PaddleOCR은 OCR 툴킷, PaddlePaddle은 딥러닝 프레임워크, Paddle Lite는 경량 추론 엔진으로 구분했다. 플랫폼 표에도 각 도구의 유형을 명시했다.

v1.5에서는 요구사항 분석서 v1.0의 F-13~F-18 및 OCR 관련 N-03·N-07·N-09만 다룬다. 손글씨·인쇄 메모, 영수증 매장·날짜·상품·수량·금액, 결과 검토·수정에 연결했다. 분류·언어 모델과 목록 연결·구매 확정·저장·동기화·가격 비교는 제외한다. 손글씨·매장·날짜 인식 성적은 아직 측정하지 않았으며 영수증 숫자 성적으로 대신하지 않는다.

v1.6에서는 세 엔진을 같은 Android 에뮬레이터에서 각각 새로 실행한 8회·1,059건의 원문·좌표·성적을 추가했다. Paddle은 ONNX Runtime Android로 배포하고 검출 최대 변 1600px를 사용한다. 기본 4000px 메모리 실패와 OpenCV 로딩 오류도 기록한다. Tesseract는 Android 코어 5.5.1이며 PSM 3·7·10을 구분한다. 사전 Ubuntu 시험과 동일한 실행 구성으로 표현하지 않는다. [실행 자료](../../ocr-comparison/20261012-android/README.md)를 보관하며 최종 기술 선택·실기기/iOS 성능은 결론 내리지 않는다.
