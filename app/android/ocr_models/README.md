# 기본 Android Paddle 모델

`models/det/inference.onnx`, `models/rec/inference.onnx`, `models/rec/inference.yml`은 독립 비교에서 검증한 PP-OCRv5_mobile_det / korean_PP-OCRv5_mobile_rec 가중치의 동일 ONNX 변환 파일이다. PaddleOCR 공식 한국어 모델과 문자 사전을 사용한다. `manifest.json`에 해시·크기·변환 버전을 보관한다.

일반 Android 앱은 이 디렉터리만 assets에 추가한다. 비교 사진·Tesseract 언어 파일은 포함하지 않는다. SDK 소스·Apache2.0 라이선스와 네이티브 의존성은 `../ocr_compare/paddle/`을 재사용한다. 모델 출처와 변환 조건은 `../ocr_compare/README.md` 및 `docs/ocr-comparison/20261012-android/environment.json`을 따른다.
