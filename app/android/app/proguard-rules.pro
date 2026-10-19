# [OCR 추가] ML Kit 플러그인은 선택 언어 모듈도 참조하지만 앱은 한국어와 기본 모델만 포함한다.
# [OCR 추가] 미포함 모듈의 옵션 클래스만 경고에서 제외한다. 한국어와 기본 모델의 오류는 숨기지 않는다.
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions$Builder # [OCR 추가]
-dontwarn com.google.mlkit.vision.text.chinese.ChineseTextRecognizerOptions # [OCR 추가]
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions$Builder # [OCR 추가]
-dontwarn com.google.mlkit.vision.text.devanagari.DevanagariTextRecognizerOptions # [OCR 추가]
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions$Builder # [OCR 추가]
-dontwarn com.google.mlkit.vision.text.japanese.JapaneseTextRecognizerOptions # [OCR 추가]
