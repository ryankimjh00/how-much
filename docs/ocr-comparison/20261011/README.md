# 독립 OCR 모델 비교 — 2026-10-11

앱의 ML Kit를 교체하지 않고 동일한 실제 사진을 ML Kit, PaddleOCR, Tesseract에 각각 입력했다. 다른 모델의 결과로 빈 후보를 보완하거나 결과를 합치지 않았다. 기준 커밋은 `037fe0a`, 시험 브랜치는 `test/receipt-ocr-models`다.

이번 조건에서 **PaddleOCR는 잘라낸 수량 한 글자에 강했고, 전체 사진의 수량 위치 검출은 ML Kit가 더 좋았다.** 전체 엔진 교체가 모든 문제를 해결한다고 볼 수 없다. Tesseract의 이번 기본 설정은 두 모델보다 불리했다.

## 원본 사진의 주요 결과

교보 첫째 장 8개, 둘째 장 11개, 삼선 2개를 각각 수동 정답으로 지정했다. 다음 표는 21개 상품의 수량·금액이다. 숫자는 정답 영역 안에서 올바른 값 하나를 반환해야 성공이다. 다른 열·다른 행의 숫자는 가져오지 않는다.

| 입력 방식 | ML Kit | PaddleOCR | Tesseract 기본 PSM 3 |
|---|---:|---:|---:|
| 수량만 자른 영역 | 1/21 | **21/21** | 0/21 |
| 금액만 자른 영역 | 20/21 | **21/21** | 5/21 |
| 전체 사진에서 수량 위치와 값 | **15/21** | 7/21 | 2/21 |
| 전체 사진에서 금액 위치와 값 | 19/21 | **21/21** | 2/21 |
| 금액 행을 자른 영역에서 수량 위치와 값 | **16/21** | 4/21 | 2/21 |
| 금액 행을 자른 영역에서 금액 위치와 값 | 19/21 | **21/21** | 4/21 |

부분 사진을 읽는 능력과 전체 사진에서 해당 글자를 검출하는 능력이 다르다. PaddleOCR도 전체 사진에서 놓치는 `1`이 있었고, 같은 숫자를 단독 영역으로 주면 읽었다. 표의 위치 성적은 각 엔진이 반환한 박스 중심이 사람이 정한 해당 영역 안에 들어오는지 검사한 결과다. 검토 화면의 최종 상품 자동 연결 정확도를 시험한 것은 아니다.

### 실제 실패 사례

- 삼선 제로펩시의 수량 단독 영역: ML Kit는 빈 결과, PaddleOCR는 `1`을 반환했다. Paddle 점수는 약 0.991이다. Tesseract PSM 3은 빈 결과, PSM 7은 `|`, 숫자 제한 PSM 10은 빈 결과였다.
- 같은 제로펩시의 금액 행: ML Kit는 `2.000 / 0 / 2,000`, PaddleOCR는 `2,000 / -·-.·. / 2,000 / 0`을 반환했다. **두 모델 모두 이 행에서는 수량 1을 놓쳤다.** 각 엔진의 원문 순서를 그대로 기록했으며 표의 위치 검증은 별도로 수행했다.
- 이전에 저장한 확대·보정된 제로펩시 행도 두 모델 모두 수량 1을 놓쳤다. 원본 단독 수량 성공을 보정 행 성공으로 해석하지 않는다.
- 교보 둘째 장 두 번째 상품의 단독 수량: ML Kit는 빈 결과, PaddleOCR는 `1`을 반환했다.
- 프리즘 이름 단독 영역: ML Kit `리즘 220 라인 밴드 노트/크림`, PaddleOCR `크:리즘 220 라인 밴드 노트/크림`. **모델을 바꿔도 상품명이 완전히 복구되지는 않았다.**
- 교보 첫째 장 세 번째 금액 영역의 ML Kit 원문은 `1.300\n1`이었다. 올바른 금액 외에 추가 숫자까지 반환했으므로 엄격한 단독 값 기준에서는 실패다.

## 상품명

공백·기호·대소문자를 제외하고 글자와 숫자를 비교했다. 의미를 유추하거나 오인식 글자를 교정하지 않았다. 정답은 사진을 직접 보고 작성했다. 상품명 21개의 정답 글자 수는 이 기준으로 320자다.

| 엔진 | 이름 전체 일치 | 글자 편집 오류율 |
|---|---:|---:|
| ML Kit | 5/21 | **30/320 = 9.4%** |
| PaddleOCR | **9/21** | 33/320 = 10.3% |
| Tesseract PSM 3 | 0/21 | 142/320 = 44.4% |
| Tesseract PSM 7, 별도 설정 | 1/21 | 161/320 = 50.3% |

PaddleOCR의 완전 일치 항목은 많지만, 전체 글자 오류는 ML Kit가 조금 적었다. 상품명에 대해서 한 모델의 우세를 단정하지 않는다. 이 표는 수동으로 정한 이름 영역 시험이며, 이름 조각 병합과 상품 후보 선택 로직을 거치지 않았다.

## 추가 사진과 설정

원본, 수동 원근보정 사진, 선명하게 재작성된 사진은 별도 집계했다. 다음은 **수량만 자른 영역**의 결과다.

| 입력 | ML Kit | PaddleOCR | Tesseract PSM 3 | PSM 7 | PSM 10 + 숫자 제한 |
|---|---:|---:|---:|---:|---:|
| 교보 첫째 장 원본 | 0/8 | 8/8 | 0/8 | 0/8 | 1/8 |
| 교보 둘째 장 원본 | 1/11 | 11/11 | 0/11 | 0/11 | 2/11 |
| 교보 둘째 장 수동 원근보정 | 1/11 | 10/11 | 0/11 | 2/11 | 2/11 |
| 삼선 원본 | 0/2 | 2/2 | 0/2 | 0/2 | 0/2 |
| 트레이더스 저해상도 원본 | 입력 크기 오류 15/15 | 0/15 | 0/15 | 5/15 | 5/15 |
| 트레이더스 선명한 재작성본 | 6/15 | 5/15 | 0/15 | 15/15 | 15/15 |
| 이전 제로펩시 보정 행의 단독 수량 | 0/1 | 0/1 | 0/1 | 0/1 | 0/1 |

트레이더스 원본은 334×598px이고, 수량·금액·행 크롭 45건의 높이가 32px 미만이다. ML Kit는 실제로 `InputImage width and height should be at least 32!` 예외를 반환했다. 빈 OCR 결과와 구분하여 기록했으며 **이 예외를 모델의 글자 인식 성능 차이로 비교하지 않는다.** 같은 작은 사진 전체를 입력하면 ML Kit도 수량 8/15개를 위치와 함께 반환했다. 이 시험에는 공통 확대·패딩을 넣지 않았다.

트레이더스 재작성본은 원본에 화질 개선을 적용한 동일 사진이 아니다. 글자를 다시 작성한 별도 파일이며 원본 성적으로 합쳐 결론을 내리지 않는다. 재작성본의 수량을 전체 사진에서 읽으면 ML Kit 15/15, PaddleOCR 12/15였다.

단독 크롭 전체 집계에는 서로 다른 사진과 위 입력 오류도 들어 있다. ML Kit 수량 8/63·금액 46/63, PaddleOCR 수량 36/63·금액 58/63, Tesseract PSM 3 수량 0/63·금액 20/63이다. 판단에는 앞의 원본별 표를 우선 사용한다.

백지 1건도 별도로 시험했다. ML Kit, PaddleOCR, Tesseract PSM 3/7 모두 빈 결과였다. 백지 시험은 실제 영수증 정확도에 포함하지 않았다. 할인 음수·용량·날짜·서버 저장 정확도는 이 모델 비교 범위에서 측정하지 않았다.

## 조건과 재현 자료

- **ML Kit:** 앱의 기존 `google_mlkit_text_recognition 0.16.0`, Android 한국어 모델 `16.0.1`. Ubuntu Android 에뮬레이터에서 실제 네이티브 `TextRecognizer`를 직접 호출했다. 앱 문자열 파서·열 재인식·재시도·자동 연결은 호출하지 않았다.
- **PaddleOCR:** `paddleocr 3.4.0`, `paddlepaddle 3.2.2`, `PP-OCRv5_mobile_det` + `korean_PP-OCRv5_mobile_rec`. Ubuntu CPU 4스레드, MKLDNN 해제. 방향 분류·문서 펼침·텍스트 방향 보정은 해제했다. 실제 결과의 검출 설정은 `limit_side_len=64`, `limit_type=min`, `max_side_limit=4000`, `thresh=0.3`, `box_thresh=0.6`, `unclip_ratio=1.5`다.
- **Tesseract:** 설치된 `4.1.1`, `kor+eng`, OEM 1. PSM 3 자동 분할을 기본으로 사용했다. PSM 7 한 줄과 PSM 10 한 글자 + 숫자 제한은 별도 실행했으며 결과를 합치지 않았다. 다른 버전이나 학습 파일의 성적까지 일반화하지 않는다.
- 원본 JPEG는 EXIF 방향을 적용하고 RGB PNG로 저장했다. 공통 대비·확대·기울기 보정은 적용하지 않았다. 기존 보정 사진은 따로 입력했다. 모델 내부의 기본 리사이즈·검출 방식은 모델마다 다르다.
- 전체 사진 7건, 수량 63건, 금액 63건, 상품명 21건, 숫자 행 62건, 백지 1건으로 총 217건이다. 모델 호출 전 파일 SHA-256을 검증했다.
- 사람 지정 영역을 먼저 시각 확인했다. 교보 둘째 장 금액의 가로 범위와 이름 영역의 높이가 잘못 지정된 것을 바로잡아 세 모델 모두 해당 22건을 재시험했다. 잘못 지정한 이전 결과는 최종 파일에서 대체했다. 정답의 상품 코드도 실제 사진 기준으로 `1173`, `1202` 등 수정했다.
- `manifest.json`: 영역·정답·입력 SHA-256. `sources/`: 실제 원본 세 장과 트레이더스 두 파일. 교보 기존 보정 사진과 제로펩시 보정 행은 기존 `docs/ocr-debug/` 자료를 참조한다.
- `prepare_inputs.py`: 동일 PNG와 영역 생성. `run_host_models.py`: Paddle/Tesseract 실행. `mlkit_comparison.dart`: 별도 Android 패키지에서 사용한 실제 네이티브 시험 코드. 시험 시 같은 파일을 asset으로 제공한다.
- `results/*.jsonl`: 원문·좌표·모델 점수·처리 시간·예외. `field-results.csv`와 `summary.json`: 단독 영역 채점. `localization.csv`와 `localization-summary.json`: 전체/행의 위치 채점. `environment.json`과 `host-packages.txt`: 버전·모델 해시·별도 Python 환경.

예시:

```bash
# Pillow가 있는 Python에서 입력을 만든다.
python prepare_inputs.py
# 준비한 각 모델 환경에서 각각 실행한다.
python run_host_models.py paddle /tmp/receipt-ocr-comparison/manifest.json /tmp/paddle.jsonl
python run_host_models.py tesseract-auto /tmp/receipt-ocr-comparison/manifest.json /tmp/tesseract.jsonl
# results/에 같은 입력의 엔진별 파일을 둔 뒤 집계한다.
python summarize.py
python localization.py
```

ML Kit 시험 패키지는 `com.todayone.todo.ocrcompare`다. 운영 패키지 `com.todayone.todo`와 분리하고 Flutter 시험의 `--no-uninstall`을 사용했다. 끝난 뒤 임시 pubspec asset·Android applicationId를 원래 바이트로 복원하고 시험 파일을 앱에서 제거했다. Python 패키지와 모델은 `/tmp`의 별도 환경에 설치했다. 앱 패키지 추가·`pub get`·lock 변경은 없었다. 원본 참고 프로젝트를 수정하지 않았다.

## 검증과 한계

ML Kit 실제 네이티브 시험은 217건 완료, 수정 영역 재시험은 22건 완료했다. Paddle/Tesseract 실행 오류는 없었다. ML Kit의 위 작은 크롭 45건 예외는 원문과 함께 보관했다. 시험 코드의 통과는 정확도 100%를 뜻하지 않는다.

기존 앱 회귀 테스트 275개 통과·기존 1개 건너뜀. 정적 검사는 기존 `screens.dart:806` 경고 1개다. 임시 Dart 시험 코드는 포맷했다. 기존 앱 및 로컬 기록을 유지했고, 실험 후 운영 앱을 다시 열었다. 생산 앱 코드는 변경하지 않았다. 실험 브랜치의 커밋·푸시·배포 APK 생성·실기기 설치는 하지 않았다.

Paddle/Tesseract는 Ubuntu 호스트 CPU, ML Kit는 Android 에뮬레이터에서 실행했다. 원문 파일에 기록한 시간은 각 호출 시간이며 로딩·파일 저장은 제외했다. 모델 준비·내부 파이프라인·장치·다른 프로세스 부하가 다르므로 **세 숫자를 온디바이스 속도 순위로 비교할 수 없다.** Paddle/Tesseract의 Android APK 크기, 메모리, 실기기 속도와 정확도는 아직 측정하지 않았다. 한 사진의 보정본과 원본은 독립적인 새 영수증 표본이 아니다.

현재 결과로는 전체 ML Kit 교체보다 **PaddleOCR의 지정 수량 영역을 독립적인 Android 시험 앱에서 검증하는 것**이 근거 있는 다음 시험이다. 앱에 혼합 적용하는 변경은 이번에 하지 않았다.

## 공식 자료

- [PaddleOCR 텍스트 인식 모델](https://paddlepaddle.github.io/PaddleOCR/main/en/version3.x/module_usage/text_recognition.html)
- [PaddleOCR 온디바이스 배포](https://paddlepaddle.github.io/PaddleOCR/main/en/version3.x/deployment/on_device_deployment.html)
- [Tesseract 분할 모드와 품질 설정](https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html)
- [Tesseract TSV 좌표와 점수](https://tesseract-ocr.github.io/tessdoc/Command-Line-Usage.html)
- [ML Kit Android 텍스트 인식](https://developers.google.com/ml-kit/vision/text-recognition/v2/android)


## 추가 검증 — 공통 흰 여백 45건

PDF 작성 요청에 따라 트레이더스 원본의 수량·금액·행 크롭을 각 변 최소32px로 흰 여백만 붙여 세 모델에 동일 입력했다. 확대·대비 보정은 하지 않았다. 모든 모델의45건에서 실행 오류0건이었다. ML Kit 수량2/15·금액12/15, PaddleOCR 수량7/15·금액12/15, Tesseract 기본 PSM3 수량0/15·금액2/15였다. PaddleOCR의 나머지 수량8건은 빈 결과가 아닌 오인식이었다. 작은 입력의 예외와 실제 판독 실패를 구분한다. 이전의 무패딩 시험과 합쳐 집계하지 않는다.

입력 해시·정답·여백은 `padding-manifest.json`, 원문은 `padding-results/*.jsonl`, 집계는 `padding-summary.json`에 있다. `prepare_padding_inputs.py`와 `summarize_padding.py`로 재현한다. ML Kit는 별도 패키지에서45건을 실제 실행했고 임시 앱 설정을 원래 바이트로 복원한 뒤 시험 패키지만 제거했다. 기존 앱·기록·사용자 파일은 유지했다.

[온디바이스 AI 조사·구현·검증 PDF](../../research/on-device-ai-20261011/얼마였지_온디바이스AI_조사구현검증보고서_20261011.pdf)에 온디바이스 AI 기술·OCR 구현·실제 시험 결과만 정리했다.
