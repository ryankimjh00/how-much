# Android OCR 비교 모듈

Paddle SDK는 Android 기본 앱에서도 사용한다. 시험 사진·Tesseract·비교 채널은 `--dart-define=OCR_COMPARE=true` 빌드에서만 포함한다. 비교 패키지는 `com.todayone.todo.ocrcompare2`이며 기본 앱의 구매 기록과 분리된다. `OCR_ENGINE=mlkit`, `paddle`, `tesseract` 중 하나를 빌드마다 선택한다. 실패한 엔진을 다른 엔진으로 대체하거나 후보를 섞지 않는다.

현재 일반 Android 빌드의 기본 엔진은 Paddle이고 iOS는 ML Kit를 유지한다. `OCR_ENGINE=mlkit`를 명시하면 이전 인식 경로를 사용한다. Flutter 패키지 추가·업그레이드는 하지 않았다. 비교 전용 네이티브 의존성은 ONNX Runtime Android 1.21.1, OpenCV 4.12.0, Tesseract4Android 4.9.0, Kotlin coroutines 1.9.0이다.

## 모델과 라이선스

`paddle/src/main/`은 [공식 PaddleOCR Android SDK](https://github.com/PaddlePaddle/PaddleOCR/tree/dab3fe35379033fdcb2d0e9572fac0b36c9a9ebf/deploy/ppocr-android/ppocr-sdk)의 해당 커밋 소스다. Apache 2.0 라이선스와 원래 주석을 유지한다. Flutter 연결 코드는 `bridge/`에 따로 둔다.

기존 Ubuntu 시험의 `PP-OCRv5_mobile_det`와 `korean_PP-OCRv5_mobile_rec` 가중치를 paddle2onnx 2.1.0으로 ONNX opset 17로 변환했다. 공식 Android SDK를 통해 ONNX Runtime에서 실행하며 Paddle Lite 실행 결과는 아니다. `paddle2onnx --model_dir <모델폴더> --model_filename inference.json --params_filename inference.pdiparams --save_file <출력>/inference.onnx --opset_version 17 --optimize_tool None`으로 각각 준비한다.

Android 검출의 최대 변은 **1600px**, 검출 최소 변 64px, 임계값 0.3/0.6, unclip 1.5, CPU 4스레드다. 입력 파일을 바꾸지 않고 모델 내부에서 크기를 조절하며 원본 좌표로 결과를 돌려준다. SDK 기본값 4000px는 12MP 사진에서 Java 메모리 부족 및 약 1.9GB 프로세스 메모리 사용 후 종료됐다. 메모리 한도 확대는 최종 비교 설정에 포함하지 않았다.

SDK 예제의 QuickBird OpenCV 4.5.3은 x86_64에서 `__lttf2` 로딩 오류가 있어 [공식 OpenCV 4.12.0](https://opencv.org/opencv4android-usage-models/)으로 연결했다. 기존 앱의 Dart 사진 보정에는 OpenCV를 추가하지 않았다.

Tesseract는 [Tesseract4Android 4.9.0](https://github.com/adaptech-cz/Tesseract4Android/tree/4.9.0)의 공식 AAR를 사용한다. 코어 5.5.1, `kor+eng`, OEM LSTM이다. 언어 파일은 이전 Ubuntu 시험과 동일한 해시지만 Ubuntu 코어 4.1.1과 버전이 다르다. PSM 3·7·10은 각각 별도로 시험한다.

## 시험 준비

모델·AAR·사진 바이너리는 `.gitignore`로 제외했다. 모델 해시와 실제 실행 결과는 `docs/ocr-comparison/20261012-android/`에 보관한다. 사진 입력 생성은 이전 `20261011/prepare_inputs.py`와 `prepare_padding_inputs.py`를 사용한다.

```sh
python3 app/android/ocr_compare/prepare_assets.py \
  --onnx-models /tmp/android-ocr-compare/models \
  --korean-config /tmp/receipt-paddle-cache/official_models/korean_PP-OCRv5_mobile_rec/inference.yml \
  --tessdata /usr/share/tesseract-ocr/4.00/tessdata \
  --tesseract-aar /tmp/android-ocr-compare/libs/tesseract4android-4.9.0.aar
python3 docs/ocr-comparison/20261012-android/run_android.py --engine paddle
```

동일 방식으로 다른 엔진을 별도로 실행한다. `--suite padding`은 공통 여백 입력, `--psm 7`·`--psm 10`은 Tesseract 추가 설정이다. 스크립트는 설치 전 패키지를 확인하고 `--no-uninstall`로 기존 기록 삭제를 방지한다. 이 코드는 Android 시험용이며 iOS 대체 엔진 연결은 구현하지 않았다.

## 후속 기본 전환과 API24 호환성

사용자 요청으로 Paddle SDK를 기본 Android 앱에서 재사용한다. 모델은 `../ocr_models/`에 동일 해시로 배치했다. 일반 APK에는 시험 사진·Tesseract를 포함하지 않는다. 공식 예제의 minSdk26 선언은 ORT1.21.1의 minSdk24 및 OpenCV4.12.0의 minSdk21, API24 소스 검사·Android 린트·실제 실행을 확인하고24로 조정했다. 앱의 기존 Android7.0 지원을 유지하며 비교 APK도24로 빌드할 수 있다. 검증은 `docs/ocr-debug/paddle-switch-20261012/README.md`를 참조한다. 기존20261012-android 시험 자료의 minSdk26은 전환 전 실행 조건이다.
