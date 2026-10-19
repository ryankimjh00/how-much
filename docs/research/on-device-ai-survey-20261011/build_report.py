"""[OCR 추가] 플랫폼별 AI 기술과 요구사항 구현 예시를 조사용 PDF로 작성한다."""
from html import escape
import json
from pathlib import Path
from weasyprint import HTML

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[2]
NAME = '얼마였지_온디바이스AI_기술조사보고서_20261011'
SOURCES = [
('ML Kit Android 텍스트 인식', 'https://developers.google.com/ml-kit/vision/text-recognition/v2/android'),
('ML Kit iOS 텍스트 인식', 'https://developers.google.com/ml-kit/vision/text-recognition/v2/ios'),
('Google LiteRT 개요', 'https://developers.google.com/edge/litert/overview'),
('Apple Vision 텍스트 인식', 'https://developer.apple.com/documentation/vision/recognizing-text-in-images'),
('Core ML Tools 기본 사용', 'https://apple.github.io/coremltools/docs-guides/source/introductory-quickstart.html'),
('ONNX Runtime 모바일 배포', 'https://onnxruntime.ai/docs/tutorials/mobile/'),
('ExecuTorch Android 사용', 'https://docs.pytorch.org/executorch/stable/using-executorch-android.html'),
('ExecuTorch iOS 사용', 'https://docs.pytorch.org/executorch/stable/using-executorch-ios.html'),
('Flutter ML Kit 플러그인', 'https://pub.dev/packages/google_mlkit_text_recognition'),
('Flutter TensorFlow Lite 바인딩', 'https://pub.dev/packages/tflite_flutter'),
('ONNX Runtime React Native', 'https://onnxruntime.ai/docs/get-started/with-javascript/react-native.html'),
('PaddleOCR 글자 검출 모델', 'https://www.paddleocr.ai/main/en/version3.x/module_usage/text_detection.html'),
('PaddleOCR 글자 인식 모델', 'https://www.paddleocr.ai/main/en/version3.x/module_usage/text_recognition.html'),
('PaddleOCR Android 배포', 'https://www.paddleocr.ai/main/en/version3.x/inference_deployment/cross_platform/android_deployment.html'),
('PaddleOCR iOS 배포', 'https://www.paddleocr.ai/main/en/version3.x/inference_deployment/cross_platform/ios_deployment.html'),
('Tesseract 언어 데이터', 'https://tesseract-ocr.github.io/tessdoc/Data-Files.html'),
('Tesseract 영역 분할과 품질 설정', 'https://tesseract-ocr.github.io/tessdoc/ImproveQuality.html'),
('ONNX Runtime Java API 기본 사용', 'https://onnxruntime.ai/docs/get-started/with-java.html'),
('Apple Vision 인식 요청 API', 'https://developer.apple.com/documentation/vision/vnrecognizetextrequest'),
('Paddle Lite Java API', 'https://www.paddlepaddle.org.cn/lite/develop/api_reference/java_api_doc.html'),
('PaddleOCR Paddle Lite 모바일 배포', 'https://github.com/PaddlePaddle/PaddleOCR/blob/main/deploy/lite/readme.md'),
('ML Kit Digital Ink 입력 형식', 'https://developers.google.com/ml-kit/vision/digital-ink-recognition'),
('Tesseract4Android 4.9.0 사용과 배포', 'https://github.com/adaptech-cz/Tesseract4Android/tree/4.9.0'),
('OpenCV 공식 Android 배포', 'https://opencv.org/opencv4android-usage-models/'),
]
pages = []


def cite(*numbers):
    """공식 출처 번호를 클릭 가능한 링크로 만든다."""
    return ' <span class="cite">' + ' '.join(f'<a href="{SOURCES[n-1][1]}">[{n}]</a>' for n in numbers) + '</span>'


def table(headers, rows):
    """내용이 긴 설명 열에 충분한 폭을 배정한다."""
    columns = '<colgroup><col style="width:29%"><col style="width:71%"></colgroup>' if len(headers) == 2 else ''
    return '<table>' + columns + '<thead><tr>' + ''.join(f'<th>{v}</th>' for v in headers) + '</tr></thead><tbody>' + ''.join('<tr>' + ''.join(f'<td>{v}</td>' for v in row) + '</tr>' for row in rows) + '</tbody></table>'


def page(title, body):
    """주제마다 페이지를 나누어 조사 내용을 찾기 쉽게 한다."""
    pages.append(f'<section><div class="eyebrow">얼마였지 / 온디바이스 OCR 기술 조사</div><h1>{title}</h1>{body}</section>')


def code(value):
    """예제의 비교 연산자와 태그를 인쇄 문서에서 그대로 보존한다."""
    return '<pre>' + escape(value.strip()) + '</pre>'


page('온디바이스 AI\n기술 조사 보고서', '''
<p class="subtitle">플랫폼별 AI 개발 도구 · 경량 모델 · 기본 사용 · 기능 구현 예시</p>
<div class="cover-brand">얼마였지</div>
''' + table(['조사 항목', '내용'], [
['플랫폼', 'Android · iOS · Flutter 및 React Native를 통한 크로스플랫폼 연결'],
['AI 개발 도구', 'ML Kit, LiteRT, Paddle Lite·PaddleOCR, Vision, Core ML, ONNX Runtime, ExecuTorch, Tesseract'],
['경량 모델', '한국어 글자 검출·인식 모델과 OCR 언어 데이터'],
['주요 요구사항', '메모·영수증 사진 OCR, 상품명·수량·매장·구매일·금액 추출, 결과 검토·수정'],
['작성일', '2026년 10월 12일 · OCR 기술 조사·모델 비교 v1.6'],
]) + '''
<h2>조사 목적</h2><p>온디바이스 AI를 모바일 앱에서 사용할 때 필요한 SDK·툴킷·프레임워크·추론 엔진과 모델을 조사하고,
앱 요구사항 분석서 v1.0의 F-13~F-18에 해당하는 OCR 기능을 어떤 조합과 API로 구현할 수 있는지 정리한다.</p>
<h2>문서 읽는 방법</h2><p>플랫폼 지원 → 모델 후보 → 기본 API → 요구사항 구현 순서로 구성했다.
본문의 번호는 공식 문서로 연결된다. 코드와 JSON은 사용 구조를 설명하는 조사용 예시이며,
실험 결과는 별도의 비교 절에서 실제 실행 환경과 함께 제시한다.</p>
<p class="small">AI 개발 도구 조사와 모델 비교는 현재 수행한다. 최종 기술 선정과 최종본 작성은 이후에 진행한다.</p>
''')

page('1. AI 개발 도구와 모델의 구분', '''
<p>AI 개발 도구는 SDK·툴킷·프레임워크·추론 엔진을 포함하는 통칭이다. 모델은 학습된 가중치와
입력·출력 규격이다. 모델 포함 SDK와 직접 모델을 준비하는 추론 런타임은 사용 방식이 다르다.</p>
''' + table(['종류', '기본 사용 방식'], [
['ML Kit — 모바일 ML SDK', '학습된 모델과 기능 API를 제공한다. 한국어 텍스트 인식 구성요소에 사진을 전달하면 글자·위치를 얻는다.' + cite(1,2)],
['PaddleOCR — OCR 툴킷', 'OCR 모델과 학습·추론·배포 도구를 제공한다. 선택한 모델을 Paddle Lite나 ONNX Runtime 등 지원 실행 경로에 연결한다.' + cite(12,13,21)],
['PaddlePaddle — 딥러닝 프레임워크', '모델을 정의·학습하고 추론하는 기반이다. 모바일 경량 실행을 맡는 Paddle Lite와 역할이 다르다.'],
['Paddle Lite — 경량 추론 엔진', '지원 모델을 .nb 형식으로 준비해 모바일에서 실행한다. 입력 생성과 출력 디코딩을 별도로 작성한다.' + cite(20,21)],
['Vision / Core ML — Apple 프레임워크', 'Vision은 텍스트 인식 등의 영상 분석 API, Core ML은 준비한 머신러닝 모델의 기기 실행 기능을 제공한다.' + cite(4,5)],
['범용 추론 런타임', 'LiteRT, ONNX Runtime, ExecuTorch는 지원 형식의 모델, 입력 텐서, 출력 해석을 준비해야 한다.' + cite(3,5,6,7)],
]) + '''
<h2>모델을 준비할 때 확인할 항목</h2>
<ul><li>언어와 학습 대상: 한국어 상품명, 숫자, 영수증 인쇄 글꼴을 처리할 수 있는가.</li>
<li>입력 규격: 이미지 크기, 채널 순서, 자료형, 정규화, 문자 사전이 무엇인가.</li>
<li>출력 규격: 문자열, 글자 위치, 클래스 점수 중 어떤 결과를 제공하는가.</li>
<li>기기 조건: 지원 연산, 가속기, 모델 파일 크기, 실행 중 메모리, 라이선스가 맞는가.</li></ul>
<p>파일 크기는 실행 메모리와 같지 않다. 가중치 외에도 중간 텐서와 입력·출력 버퍼가 필요하다.
양자화 모델도 런타임과 기기가 해당 연산을 지원해야 실행할 수 있다.</p>
''')

page('2. 플랫폼별 AI 개발 도구', table(['기술 / 유형', 'Android', 'iOS / 크로스플랫폼 연결'], [
['ML Kit\n모바일 ML SDK', '네이티브 텍스트 인식 SDK', 'iOS SDK 제공. Flutter 플러그인으로 두 플랫폼 연결.' + cite(1,2,9)],
['PaddleOCR\nOCR 툴킷', '모델·처리 흐름을 모바일 실행 경로에 연결', '한국어 모델과 문자 사전을 준비하고 장치별 런타임으로 배포.' + cite(12,13,14,15)],
['Paddle Lite\n경량 추론 엔진', 'Java / C++로 지원 모델 실행', 'iOS 추론 라이브러리. Flutter·React Native는 네이티브 연결.' + cite(20,21)],
['Vision / Core ML\nApple 프레임워크', 'Apple 프레임워크 직접 사용 불가', 'Vision OCR과 Core ML 모델 실행. Flutter·React Native는 iOS 네이티브 연결 필요.' + cite(4,5)],
['LiteRT\n추론 런타임', '모델 실행 및 기기별 가속', 'iOS 실행 경로 제공. Flutter는 tflite_flutter 바인딩 사용 가능.' + cite(3,10)],
['ONNX Runtime\n추론 런타임', 'Java / C / C++ 모바일 API', 'Objective-C / C / C++ API. 공식 React Native 패키지 제공.' + cite(6,11)],
['ExecuTorch\n추론 런타임', 'PyTorch 내보내기 모델 실행', 'iOS 연동 지원. 크로스플랫폼 UI에서 네이티브 모듈로 연결.' + cite(7,8)],
]) + '''
<h2>연결 범위의 차이</h2><p>같은 앱 코드를 공유하더라도 각 운영체제의 모델 배포·권한·가속 경로는 별도로 준비할 수 있다.
또한 Flutter 바인딩이 제공하는 API가 최신 네이티브 런타임 API와 일치한다고 가정하면 안 된다.</p>
<p>LiteRT의 새 CompiledModel 경로와 기존 Interpreter 경로는 구분해야 한다.
iOS 패키지와 Swift API의 제공 상태도 사용하려는 버전의 문서에서 확인한다.</p>
''')

page('3. Android 기본 사용', '''
<h2>ML Kit: 한국어 OCR 모델을 선택해 사진 전달</h2>
<p>한국어 인식 구성요소를 앱 의존성에 추가하고 인식기를 생성한다. 모델을 앱에 포함하는 방식과
필요할 때 내려받는 방식의 준비 시점이 다르므로, 첫 실행에서 모델이 준비됐는지 처리한다.</p>
''' + code('''// Kotlin: 한국어 모델 구성요소 의존성 준비 필요
val reader = TextRecognition.getClient(
    KoreanTextRecognizerOptions.Builder().build()
)
val input = InputImage.fromBitmap(receiptBitmap, 0)
reader.process(input)
    .addOnSuccessListener { result ->
        for (block in result.textBlocks) {
            for (line in block.lines) {
                saveCandidate(line.text, line.boundingBox)
            }
        }
    }
    .addOnFailureListener { error -> showReadFailure(error) }
// saveCandidate와 showReadFailure는 앱에서 구현하는 함수다.
// 화면 종료 시 진행 작업을 처리하고 reader.close()로 해제한다.''') + cite(1) + '''
<h2>LiteRT: 직접 준비한 OCR 모델 실행</h2>
<p>지원 .tflite OCR 모델을 준비하고 이미지 → 입력 텐서 → 추론 → 출력 디코딩 순서로 구성한다.
입력 모양·자료형·정규화와 문자 사전을 모델에 맞춘다. 런타임에 사진을 넣는 것만으로 글자 인식이
완성되지는 않는다. PP-OCR 모델을 별도 검증 없이 .tflite로 바로 실행할 수 있다고 가정하지 않는다.</p>''' + cite(3) + '''
<p class="small">예제는 핵심 API 흐름을 보여준다. 사진 방향, 모델 설치, import, 수명 관리와 UI 비동기 처리는 실제 앱에서 함께 구성한다.</p>''')

page('4. iOS 기본 사용', '''
<h2>Vision: 지원 언어 확인 후 글자·좌표 인식</h2>
<p>인식 수준과 API 리비전에 따라 지원 언어가 달라질 수 있다. 한국어 지원을 확인한 뒤 요청한다.</p>
''' + code('''import Vision

// 호출자가 이미지 방향을 맞춘 CGImage를 전달한다.
func readReceipt(_ image: CGImage) throws
    -> [VNRecognizedTextObservation] {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    let languages = try request.supportedRecognitionLanguages()
    guard languages.contains("ko-KR") else {
        throw NSError(domain: "ReceiptLanguage", code: 1)
    }
    request.recognitionLanguages = ["ko-KR", "en-US"]
        .filter { languages.contains($0) }
    try VNImageRequestHandler(cgImage: image).perform([request])
    return request.results ?? []
}
// observation.topCandidates(1).first?.string: 인식 문자열
// observation.boundingBox: 정규화된 영역 좌표''') + cite(4,19) + '''
<h2>Core ML: 직접 준비한 모델 실행</h2>
<p>학습된 모델을 coremltools로 지원 형식에 변환하고 앱에 포함한다. Xcode에서 생성한 모델 클래스로
입력값을 전달하거나 MLModel API를 사용한다. 이미지 입력, 정규화와 출력 이름은 모델 규격을 따른다.</p>
<p>한국어 OCR 모델을 연결하려면 지원 연산과 변환 성공 여부를 확인하고 글자 검출·인식 출력과
문자 사전을 해석하는 코드를 작성한다. Core ML 자체가 한국어 OCR 가중치를 제공하는 것은 아니다.</p>''' + cite(5))

page('5. 크로스플랫폼 앱 연결', '''
<h2>Flutter: ML Kit 플러그인 예시</h2>
<p>플러그인은 플랫폼 채널을 통해 Android·iOS 네이티브 SDK를 호출한다.
Google이 직접 유지하는 Flutter SDK가 아니므로 플러그인과 네이티브 설치 조건을 함께 확인한다.</p>
''' + code('''final recognizer = TextRecognizer(
  script: TextRecognitionScript.korean,
);
try {
  final input = InputImage.fromFilePath(photoPath);
  final result = await recognizer.processImage(input);
  for (final block in result.blocks) {
    for (final line in block.lines) {
      collect(line.text, line.boundingBox);
    }
  }
} finally {
  await recognizer.close();
}
// collect는 글자와 위치를 보관하도록 앱에서 구현한다.''') + cite(9) + '''
<h2>Flutter: 직접 모델을 실행하는 방법</h2>
<p>tflite_flutter는 Dart FFI로 TensorFlow Lite Interpreter를 연결한다.
Interpreter.fromAsset으로 모델을 읽고 getInputTensor·getOutputTensor로 규격을 확인한 뒤
run으로 추론한다. 입력 생성과 출력 디코딩은 앱에서 작성한다.</p>''' + cite(10) + '''
<h2>React Native 및 네이티브 모듈</h2>
<p>공식 onnxruntime-react-native 패키지에서는 InferenceSession.create로 모델 세션을 만들고
run에 입력 텐서를 전달한다. Flutter에서 Vision·Core ML·ExecuTorch·ONNX Runtime을 연결할 때도
네이티브 구현을 호출하는 경로를 구성할 수 있다.</p>''' + cite(6,7,8,11) + '''
<p class="small">UI를 공유하는 것과 모델 실행 API를 공유하는 것은 별도 사항이다. 이 절은 AI 연결 방법을 다룬다.</p>''')

page('6. 한국어 OCR 경량 모델', table(['후보', '모델과 실행 방식'], [
['ML Kit 한국어', '한국어 텍스트 인식 SDK 구성요소. 별도의 학습 가중치 교체보다 제공 API로 글자·위치를 얻는 방식이다. Android와 iOS에 각각 연결한다.' + cite(1,2)],
['PP-OCRv5 검출', 'PP-OCRv5_mobile_det: 공식 표 기준 4.7 MB. 글자가 있는 영역을 검출하며, 문자열 판독에는 인식 모델이 추가로 필요하다.' + cite(12)],
['PP-OCRv5 한국어 인식', 'korean_PP-OCRv5_mobile_rec: 공식 표 기준 14 MB. 한국어·영어·숫자 인식 모델. 검출된 글줄 이미지와 문자 사전으로 결과를 해석한다.' + cite(13)],
['PP-OCRv3 한국어 인식', 'korean_PP-OCRv3_mobile_rec: 공식 표 기준 9.6 MB. 한국어·숫자 인식 후보. v5와의 정확도·속도 우열은 별도 조건에서 비교해야 한다.' + cite(13)],
['Tesseract 언어 모델', 'kor·eng traineddata를 사용하는 OCR 엔진. tessdata_fast와 tessdata_best의 크기·속도·정확도 특성이 다르다. 별도의 엔진 모바일 연동이 필요하다.' + cite(16)],
]) + '''
<h2>PaddleOCR의 모바일 배포</h2>
<p>공식 Android·iOS 배포 예제를 참고해 모델 실행과 이미지 입출력 경로를 구성할 수 있다.
Paddle 원본 모델 파일을 ONNX Runtime에 그대로 전달할 수는 없다. 선택한 배포 방식에 맞는
변환 모델, 지원 연산, 전후처리와 문자 사전을 준비해야 한다.</p>''' + cite(14,15) + '''
<h2>영수증 모델을 비교할 때의 구분</h2>
<p>한국어 상품명은 인식 모델의 언어 지원이 중요하고, 작은 수량은 검출과 인식 모두 영향을 받는다.
전체 사진에서 숫자 위치를 찾는 성능과 지정한 영역에서 숫자를 읽는 성능을 구분해서 조사한다.</p>
<p class="small">위 용량은 문서에 표시된 모델 크기이며 변환·양자화 파일이나 앱 설치 크기와 일치한다고 가정하지 않는다.</p>''')

page('7. 메모 사진 OCR과 손글씨 요구', '''
<p>앱 요구사항 F-13~F-16은 촬영·앨범으로 가져온 종이 메모에서 상품명과 수량을 읽고,
사용자가 수정·선택한 결과만 목록에 넘기는 기능이다. 인쇄 메모와 손글씨 메모를 모두 포함한다.</p>
<h2>사진 입력에 맞는 OCR 경로</h2>
''' + table(['입력 / 후보', '구현 방법과 확인할 조건'], [
['인쇄 메모 사진', 'ML Kit 한국어 또는 Vision 텍스트 인식으로 글자·위치를 받는다. 대안은 PP-OCR 검출 + 한국어 인식 모델의 모바일 실행이다.' + cite(1,2,4,12,13)],
['한국어 손글씨 사진', '같은 사진 입력 경로에서 별도 표본으로 시험한다. 한국어 지원이나 인쇄 글자 성적만으로 손글씨 정확도를 보장하지 않는다. 이번 영수증 실험은 손글씨 성적을 측정하지 않았다.'],
['상품명·수량 후보', 'OCR 원문과 줄 위치를 유지하고 이름·숫자 후보를 만든다. 수량이 불명확하면 검토에서 확인받는다. 인식 오류를 임의로 실제 구매 항목으로 확정하지 않는다.'],
['실패·취소', '빈 결과는 재촬영·다른 사진·직접 입력으로 연결한다. 사진 가져오기 취소나 권한 거부 시 기존 목록을 바꾸지 않는다.'],
]) + '''
<h2>Digital Ink와 사진 OCR의 차이</h2>
<p>ML Kit Digital Ink Recognition은 화면에 그린 획의 좌표·시간 데이터를 입력으로 받는다.
이미 찍은 종이 메모 사진을 전달하는 API가 아니므로, 손글씨라는 이유로 사진 OCR 대신 연결하지 않는다.</p>''' + cite(22) + '''
<h2>별도로 확인할 시험</h2>
<p>요구사항 T-05에 따라 인쇄·손글씨·흐린 사진·빈 사진·권한 거부·취소를 나누어 시험한다.
이름과 수량을 수정하거나 제외했을 때 검토 결과에만 반영되는지 확인한다. 현재 비교 결과로
메모 OCR 요구사항까지 충족했다고 표시하지 않는다.</p>
<p class="small">요구사항 근거: 얼마였지 요구사항 분석서 v1.0 / HM-REQ-001 / F-13~F-16, T-05.</p>
''')

page('8. 직접 모델 실행: ONNX · ExecuTorch', '''
<h2>ONNX Runtime + 한국어 OCR 모델</h2>
<p>PP-OCR 검출·인식 모델을 지원 ONNX 형식으로 준비한다. 검출 결과의 글줄 영역을 각각 잘라
인식 모델에 전달하고, 문자 사전과 출력 규칙으로 문자열을 복원한다.</p>
''' + code('''// Java: 추론 호출의 기본 구조. 이미지 텐서는 별도로 준비한다.
OrtEnvironment runtime = OrtEnvironment.getEnvironment();
try (OrtSession.SessionOptions options = new OrtSession.SessionOptions();
     OrtSession session = runtime.createSession(modelPath, options);
     OnnxTensor input = OnnxTensor.createTensor(runtime, imageTensor)) {
    String inputName = session.getInputNames().iterator().next();
    try (OrtSession.Result result = session.run(java.util.Collections.singletonMap(inputName, input))) {
        Object rawOutput = result.get(0).getValue();
        decodeModelOutput(rawOutput);
    }
}
// 단일 입력 모델 예시다. 입력 이름·형상·자료형은 모델 규격 확인.
// decodeModelOutput은 검출 또는 인식 출력에 맞게 앱에서 구현한다.''') + cite(6,18) + '''
<h2>ExecuTorch + PyTorch 경량 모델</h2>
<p>PyTorch 모델을 내보내기 가능한 그래프로 만들고 대상 기기의 지원 연산에 맞춰 .pte로 준비한다.
Android에서는 Module로 파일을 읽고 Tensor·EValue를 전달한다. iOS에서도 별도 연동을 구성한다.</p>
''' + code('''// Android Java: 입력과 출력이 각각 텐서 하나인 모델 예시
Module module = Module.load(modelPath);
Tensor input = Tensor.fromBlob(pixelValues, inputShape);
EValue[] result = module.forward(EValue.from(input));
Tensor output = result[0].toTensor();
// pixelValues, inputShape와 출력 해석은 모델 규격에 맞춘다.''') + cite(7,8) + '''
<p class="small">인식 출력이 CTC 방식이면 중복 토큰과 blank를 제거해 문자 사전으로 해석한다. 모든 OCR 모델의 디코딩 방식이 동일한 것은 아니다.</p>''')

page('9. OCR 요구사항과 구현 방법', '''
<p>요구사항 분석서 v1.0 중 사진 입력·문자 인식·결과 검토 범위를 다룬다.
목록 연결·구매 확정·저장·동기화·가격 비교의 구현은 이 문서에서 다루지 않는다.</p>
''' + table(['요구사항', 'AI 개발 도구 + 모델 / OCR 화면 구현'], [
['F-13 / 메모 사진 입력', '카메라·앨범에서 사진을 얻어 기기 OCR에 전달한다. 권한 거부와 가져오기 취소는 앱의 입력 처리이며 기존 항목을 유지한다.'],
['F-14 / 메모 문자 인식', 'ML Kit 한국어, Vision OCR 또는 PP-OCR 검출 + 한국어 인식 모델을 실행한다. 사진 손글씨는 별도 검증하고 글자 미검출 시 직접 입력을 제공한다.'],
['F-15~16 / 메모 검토·선택', '글자·위치 후보를 보여 주고 이름·수량을 수정·제외하게 한다. 사용자가 선택한 확정 결과만 다음 처리에 전달하며 동일 이름을 임의 병합하지 않는다.'],
['F-17 / 영수증 인식', '전체 OCR의 글자·좌표에서 매장·구매일·상품명·수량·금액 후보를 만든다. 모델은 글자를 읽고, 날짜·숫자 판별과 위치 연결은 앱의 후처리로 구현한다.'],
['F-18 / 구매 정보 검토', '매장·구매일·상품·수량·금액을 확인·수정한다. 용량·단위·할인 조건은 직접 입력하거나 확인 불가로 표시한다. OCR에 없던 값을 임의 추정하지 않는다.'],
['선택 영역 재인식', '사진 상자와 후보 버튼에 같은 ID를 연결한다. 지정 영역을 같은 엔진으로 재인식하고 원본 좌표로 환산한다. 실패하면 이전 값을 새 결과처럼 적용하지 않는다.'],
['여러 장·자동 후보', '장별 ID와 첫 상품 위치를 유지한다. 상대 위치로 상품·수량·금액을 연결하며 불확실한 항목은 체크를 해제한 검토 후보로 남긴다.'],
]) + '''
<h2>OCR 검증 기준</h2>
<p>N-03은 자원 준비 후 1,200만 화소 이하 사진의 결과·실패 안내를 10초 이내 표시하는 제안 기준이다.
N-07은 원본 사진의 영구 저장·외부 전송을 막고 임시본을 정리하도록 요구한다.
N-09는 모든 추출 항목을 확정 전에 수정·제외할 수 있도록 요구한다. 실제 충족 여부는 따로 시험한다.</p>
<p class="small">현재 실험은 상품명·수량·금액 인식 성적이다. 매장·날짜·용량·할인 및 위 화면·보호·응답 기준의 통과를 의미하지 않는다.</p>
''')

page('10. 영수증 후보 데이터 예시', '''
<h2>문자열과 위치를 함께 유지</h2>
<p>아래는 “퍼실 / 수량 3 / 금액 80,940”을 읽었다고 가정한 데이터 예시다.
좌표는 설명용이며 실제 사진의 인식 결과가 아니다.</p>
''' + code('''{
  "photoId": "first-photo",
  "imageWidth": 1200,
  "imageHeight": 1800,
  "candidates": [
    {"id": "name-01", "text": "퍼실", "box": [100, 400, 180, 440]},
    {"id": "qty-01", "text": "3", "box": [650, 445, 670, 475]},
    {"id": "amount-01", "text": "80,940", "box": [850, 445, 980, 475]}
  ]
}
// box: [왼쪽, 위, 오른쪽, 아래]의 원본 사진 픽셀 좌표''') + '''
<h2>서로 다른 엔진의 좌표를 맞추는 방법</h2>
<p>Vision의 정규화 좌표는 아래쪽 원점이므로 사진 폭 W, 높이 H에 대해
left = x × W, top = (1 − y − h) × H, width = w × W, height = h × H로 바꾼다.
입력 방향과 표시 방향을 동일하게 처리한 사진을 기준으로 사용한다.</p>''' + cite(4) + '''
<p>부분 OCR에서는 잘라낸 영역의 왼쪽·위쪽 위치를 결과 좌표에 더한다.
크롭 이미지를 별도 크기로 입력했다면 그 배율을 먼저 되돌린다. 화면 확대·이동은 표시 변환이며
저장한 사진 좌표를 직접 바꾸지 않는다.</p>
<h2>숫자와 검토 상태</h2>
<p>“12,000”은 전체 토큰에서 12000으로 해석하고 음수 부호를 보존한다. 금액의 점·콤마 처리는
금액 입력 문맥에서 검증하며 “1L”·“850g”은 용량 후보로 유지한다. 동일한 “1”도 위치가 다르면
다른 ID를 부여한다. 값이 없으면 사용자 확인 전 임의로 수량 1을 확정하지 않는다.</p>
''')

page('11. Paddle Lite · PaddleOCR 기본 사용', '''
<h2>Paddle 생태계의 역할</h2>
<p>PaddlePaddle은 모델 학습·추론 프레임워크, PaddleOCR은 글자 검출·인식 모델과 처리 흐름을
제공하는 OCR 도구 모음이다. Paddle Lite는 모델을 모바일 기기에서 실행하는 경량 추론 엔진이다.</p>
<p>따라서 PaddleOCR 모델을 Paddle Lite로 실행하는 경로와, ONNX로 변환해 ONNX Runtime으로
실행하는 경로를 구분한다. 앞의 모델 표와 ONNX 예시는 후자의 후보도 설명한다.</p>''' + cite(12,13,21) + '''
<h2>Android: 모델 준비 → 입력 → 추론 → 출력</h2>
<p>Paddle Lite의 opt 도구로 지원 모델을 .nb 형식으로 준비하고 Android ABI에 맞는
Java 라이브러리와 JNI 라이브러리를 앱에 넣는다. 변환 도구와 추론 라이브러리 버전을 맞춘다.</p>
''' + code('''// Java: com.baidu.paddle.lite 패키지의 기본 API
MobileConfig options = new MobileConfig();
options.setModelFromFile(modelNbPath);
PaddlePredictor reader =
    PaddlePredictor.createPaddlePredictor(options);
Tensor imageInput = reader.getInput(0);
imageInput.resize(modelInputShape);
imageInput.setData(normalizedPixels);
if (!reader.run()) {
    throw new IllegalStateException("모델 추론 실패");
}
float[] rawResult = reader.getOutput(0).getFloatData();
// 입력 형상·정규화와 출력 디코딩은 선택한 모델 규격을 따른다.
// 검출 모델과 인식 모델은 각각의 predictor로 실행한다.''') + cite(20) + '''
<h2>영수증 구현: 검출과 한국어 인식을 연결</h2>
<p>검출 모델 → 글줄 위치 → 영역 이미지 → 한국어 인식 모델 → 문자 사전 디코딩 → 글자·좌표 후보
순서로 구성한다. 수량 한 글자 영역은 검출을 생략하고 지정 영역을 인식 모델에 전달할 수도 있다.</p>
<p>공식 Lite 예제는 기존 중국어·영어 OCR 모델을 중심으로 설명한다. 한국어 PP-OCRv5 모델을
같은 .nb 경로로 실행하려면 변환과 지원 연산을 별도 확인해야 한다. 한국어 모델과 사전을
중국어 예제 파일로 대체해서는 안 된다.</p>''' + cite(13,21) + '''
<h2>iOS와 크로스플랫폼 연결</h2>
<p>iOS는 C++ 추론 라이브러리를 앱에 연결하고 Swift에서 네이티브 래퍼를 호출한다.
Flutter는 플랫폼 채널 또는 FFI, React Native는 네이티브 모듈로 글자·좌표 결과를 전달할 수 있다.
이 코드도 조사용 API 예시이며 앱에 적용하거나 실행한 결과는 아니다.</p>
''')

# [OCR 추가] 저장된 원문을 재집계한 실제 성적을 읽고, 예제와 구분한다.
comparison_root = ROOT / 'docs/ocr-comparison/20261011'
field_summary = json.loads((comparison_root/'summary.json').read_text())
location_summary = json.loads((comparison_root/'localization-summary.json').read_text())
padding_summary = json.loads((comparison_root/'padding-summary.json').read_text())
originals = ['kyobo-first-original', 'kyobo-second-original', 'samseon-original']
engines = ['mlkit','paddle','tesseract-auto']


def measured_score(engine, kind, context=None):
    """원본 세 장의 값과 위치 성적을 서로 다른 조건으로 집계한다."""
    source = field_summary if context is None else location_summary
    selected = [v for v in source if v['engine']==engine and v['kind']==kind and v['photo'] in originals and (context is None or v['context']==context)]
    return f"{sum(v['correct'] for v in selected)}/{sum(v['total'] for v in selected)}"


page('12. 사전 독립 비교 — 실행 환경 차이', '''
<p>실제 영수증을 ML Kit·PaddleOCR·Tesseract에 각각 입력했다. 한 엔진의 결과로 다른 엔진의 빈 값을
보충하거나 결과를 합치지 않았다. 아래 수치는 저장된 실행 원문을 다시 집계한 결과다.</p>
''' + table(['엔진', '실제 시험 구성'], [
['ML Kit', 'Android 에뮬레이터에서 네이티브 한국어 OCR 실행. Flutter 플러그인 0.16.0, 한국어 구성요소 16.0.1. 앱의 자동 연결·열 탐색·재시도는 호출하지 않았다.'],
['PaddleOCR', 'Ubuntu 호스트 CPU에서 PaddleOCR 3.4.0 / PaddlePaddle 3.2.2 실행. PP-OCRv5_mobile_det + korean_PP-OCRv5_mobile_rec. CPU 4스레드, MKLDNN 해제. Paddle Lite·ONNX 모바일 실행 성적은 아니다.'],
['Tesseract', 'Ubuntu 호스트 CPU에서 4.1.1 / kor+eng / OEM 1 실행. 기본 PSM 3과 별도 PSM 7·PSM 10 설정을 구분했다.'],
]) + '''
<h2>동일 입력과 정답</h2>
<p>교보 첫째 장 8개, 둘째 장 11개, 삼선 2개 상품을 직접 확인해 정답으로 지정했다.
전체 사진, 수량·금액 단독 크롭, 숫자 행 크롭을 각 엔진에 동일 파일로 입력하고 SHA-256을 검사했다.
공통 대비·확대·기울기 처리는 추가하지 않았다.</p>
<h2>채점 기준</h2>
<p>단독 숫자는 천 단위 점·콤마를 정규화한 뒤 정답 하나와 일치해야 성공이다. 올바른 숫자 외에 다른
숫자가 추가되면 실패로 센다. 전체·행 입력은 엔진의 박스 중심이 사람 지정 정답 영역 안에 있는지와
값이 맞는지를 함께 확인한다. 다른 행의 같은 숫자는 정답으로 가져오지 않는다.</p>
<p>상품명은 공백·기호·대소문자를 제외하고 글자·숫자를 비교한다. 완전 일치와 문자 편집 오류율을
함께 제시한다. 상품 후보 병합과 최종 자동 연결 정확도는 이 시험에 포함되지 않는다.</p>
<h2>기기 비교의 범위</h2>
<p>입력은 같지만 실행 장치와 런타임이 다르다. 현재 결과는 해당 구성의 OCR 인식 비교이며,
휴대폰 속도·발열·메모리·APK 용량 순위로 해석할 수 없다. iOS 실행과 실기기 Paddle 배포 성능은 미측정이다.</p>
''')

comparison_rows = []
for label,kind,context in [
('수량 단독 영역','quantity',None),('금액 단독 영역','amount',None),
('전체 사진: 수량 위치·값','quantity','whole'),('전체 사진: 금액 위치·값','amount','whole'),
('숫자 행: 수량 위치·값','quantity','row'),('숫자 행: 금액 위치·값','amount','row')]:
    comparison_rows.append([label]+[measured_score(engine,kind,context) for engine in engines])
name_rows=[]
for engine,label in [('mlkit','ML Kit'),('paddle','PaddleOCR'),('tesseract-auto','Tesseract PSM 3'),('tesseract-line','Tesseract PSM 7')]:
    values=[v for v in field_summary if v['engine']==engine and v['kind']=='name' and v['photo'] in originals]
    edits=sum(v['name_edits'] for v in values)
    chars=sum(v['name_chars'] for v in values)
    name_rows.append([label,measured_score(engine,'name'),f'{edits}/{chars} = {edits/chars:.1%}'])
page('13. 사전 시험 · 원본 3장 21개 상품', '''
<p>표의 분모는 세 원본 사진의 상품 21개다. 모델별로 따로 실행한 결과이며 최종 앱 선택 결과가 아니다.</p>
'''+table(['입력 / 평가','ML Kit','PaddleOCR','Tesseract PSM 3'],comparison_rows)+'''
<h2>상품명 단독 영역</h2>
'''+table(['엔진','이름 전체 일치','문자 편집 오류율'],name_rows)+'''
<h2>확인된 차이</h2>
<p>수량 단독 영역은 PaddleOCR 21/21, ML Kit 1/21이었다. 반면 전체 사진에서 수량 위치와 값을
함께 찾은 성적은 ML Kit 15/21, PaddleOCR 7/21이었다. 지정된 영역에서 읽는 능력과 전체 사진에서
위치를 검출하는 능력이 다르게 나타났다.</p>
<p>PaddleOCR의 상품명 완전 일치는 더 많았지만 문자 편집 오류율은 ML Kit가 조금 낮았다.
이 결과만으로 모든 영수증이나 모든 기능에서 한 엔진이 우세하다고 단정하지 않는다.</p>
<p class="small">수치 근거: summary.json · localization-summary.json. PSM 7은 별도 설정이며 기본 PSM 3 결과와 합치지 않았다.</p>
''')

padding_rows=[]
for kind,label in [('quantity','수량 단독 영역'),('amount','금액 단독 영역')]:
    scores=[]
    for engine in engines:
        value=next(v for v in padding_summary if v['engine']==engine and v['kind']==kind)
        scores.append(f"{value['correct']}/{value['total']}")
    padding_rows.append([label]+scores)
page('14. 사전 시험의 실패와 추가 비교', '''
<h2>삼선 제로펩시: 입력 영역에 따른 차이</h2>
'''+table(['시험', '실제 반환 결과'],[
['수량 1 단독 영역', 'ML Kit: 빈 결과. PaddleOCR: 1, 점수 약 0.991. Tesseract PSM 3: 빈 결과, PSM 7: |, PSM 10 숫자 제한: 빈 결과.'],
['같은 상품의 숫자 행', 'ML Kit: 2.000 / 0 / 2,000. PaddleOCR: 2,000 / -·-.·. / 2,000 / 0. 두 엔진 모두 이 입력에서는 수량 1을 놓쳤다.'],
['점수 해석', 'Paddle의 점수는 해당 엔진이 반환한 토큰 점수다. 다른 모델 점수와 같은 확률처럼 비교하거나 빈 결과에 확신도 0을 임의 부여하지 않는다.'],
])+'''
<h2>트레이더스 저해상도 원본: 공통 여백 추가</h2>
<p>원본 사진은 334×598px다. 수량·금액·행 크롭 45건이 ML Kit 최소 입력 크기 조건에 걸렸다.
이를 글자 오인식과 구분했다. 각 변 최소 32px가 되도록 동일 흰 여백을 붙여 세 엔진을 다시 실행했다.
확대·대비 변경은 하지 않았다. 각 엔진의 추가 45건에서 실행 오류는 0건이었다.</p>
'''+table(['공통 여백 입력','ML Kit','PaddleOCR','Tesseract PSM 3'],padding_rows)+'''
<h2>해석과 남은 비교</h2>
<p>입력 오류가 없어져도 인식 성공이 보장되지는 않았다. 수량 단독 영역은 ML Kit 2/15,
PaddleOCR 7/15로 여전히 놓치는 숫자가 있었다. 전체 입력, 단독 영역, 행 입력 성적을 한 숫자로
섞으면 이런 차이를 잃는다.</p>
<p>이어지는 절에서는 세 엔진을 모두 같은 Android 에뮬레이터에서 새로 실행한다.
휴대폰 속도·발열·최대 메모리·엔진별 설치 용량은 별도 실기기 측정이 필요하다.
기술 교체나 최종 선정 결론은 내리지 않는다.</p>
<p class="small">사전 시험 원문·좌표·입력 해시·버전: docs/ocr-comparison/20261011/. Android 재시험은 다음 절 및 20261012-android/ 자료와 구분한다.</p>
''')

# [OCR 추가] 이번 Android 실행은 사전 Ubuntu 성적을 덮어쓰지 않고 따로 읽는다.
android_root = ROOT / 'docs/ocr-comparison/20261012-android'
android_fields = json.loads((android_root/'summary.json').read_text())
android_locations = json.loads((android_root/'localization-summary.json').read_text())
android_times = json.loads((android_root/'timings.json').read_text())
assert len(android_times) == 8, 'Android 독립 실행 8개가 모두 끝나야 보고서를 만든다.'
assert sum(v['count'] for v in android_times) == 1059


def android_score(run, kind, context=None, suite='base'):
    """Android 동일 입력의 독립 실행 하나만 집계한다."""
    source = android_fields if context is None else android_locations
    selected = [v for v in source if v['run']==run and v['kind']==kind and
                (suite=='padding' or v['photo'] in originals) and
                (context is None or v['context']==context)]
    assert selected, (run,kind,context)
    return f"{sum(v['correct'] for v in selected)}/{sum(v['total'] for v in selected)}"


page('15. 동일 Android 기기에서 독립 실행', '''
<p>세 엔진을 모두 Android 15 / API 35 / x86_64 에뮬레이터에서 새로 실행했다.
동일한 사진·영역 217개와 공통 여백 입력 45개를 엔진마다 SHA-256으로 확인했다.
Tesseract 추가 설정을 포함해 8회, 총 1,059건을 실행했다.
한 엔진이 놓친 값을 다른 엔진으로 보완하거나 결과를 합치지 않았다.</p>
''' + table(['엔진', '실제 Android 구성'], [
['ML Kit', '기존 한국어 SDK 16.0.1 / Flutter 플러그인 0.16.0. 전체·부분 이미지 모두 같은 엔진을 호출한다.' + cite(1,9)],
['PaddleOCR', '공식 Android SDK 고정 커밋. 기존 PP-OCRv5_mobile_det + korean_PP-OCRv5_mobile_rec 가중치를 ONNX opset 17로 변환. ONNX Runtime Android 1.21.1, CPU 4스레드, 검출 최대 변 1600px.' + cite(6,14)],
['Tesseract', 'Tesseract4Android 4.9.0 / 코어 5.5.1 / OEM LSTM / kor+eng. 언어 파일은 사전 시험과 같은 해시다. PSM 3·7·10을 각각 별도로 실행했다.' + cite(23)],
]) + '''
<h2>앱에 연결한 방법</h2>
<p>Flutter 전체·부분 OCR의 공통 인식기에서 빌드별로 한 엔진을 고른다. ML Kit는 기존 플러그인,
Paddle·Tesseract는 Android 플랫폼 채널로 호출한다. 글줄·단어의 원래 상자와 점수를
Flutter에 반환하며 임의로 단어를 나누거나 다른 엔진으로 재시도하지 않는다.</p>
<h2>사전 시험과 달라진 조건</h2>
<p>Paddle은 PaddlePaddle 대신 ONNX Runtime을 사용하고 내부 검출 최대 변을 4000px에서 1600px로
제한했다. 입력 사진 파일과 반환 좌표는 원본 기준이다. Tesseract 코어는 4.1.1에서 5.5.1로 달라졌다.
같은 모델 가중치·언어 파일이라도 이 구성 차이가 성적을 바꿀 수 있다.</p>
<p class="small">별도 비교 패키지: com.todayone.todo.ocrcompare2. 기본 앱은 ML Kit를 유지한다. 원문·모델 해시·버전·실행 로그는 docs/ocr-comparison/20261012-android/에 보관했다.</p>
''')

android_runs = ['mlkit-base-psm3','paddle-base-psm3','tesseract-base-psm3']
android_rows=[]
for label,kind,context in [
('수량 단독 영역','quantity',None),('금액 단독 영역','amount',None),
('전체 사진: 수량 위치·값','quantity','whole'),('전체 사진: 금액 위치·값','amount','whole'),
('숫자 행: 수량 위치·값','quantity','row'),('숫자 행: 금액 위치·값','amount','row')]:
    android_rows.append([label]+[android_score(run,kind,context) for run in android_runs])
android_names=[]
for run,label in [('mlkit-base-psm3','ML Kit'),('paddle-base-psm3','PaddleOCR'),
                  ('tesseract-base-psm3','Tesseract PSM 3'),('tesseract-base-psm7','Tesseract PSM 7')]:
    values=[v for v in android_fields if v['run']==run and v['kind']=='name' and v['photo'] in originals]
    edits=sum(v['name_edits'] for v in values)
    chars=sum(v['name_chars'] for v in values)
    android_names.append([label,android_score(run,'name'),f'{edits}/{chars} = {edits/chars:.1%}'])
page('16. Android · 원본 3장 21개 상품', '''
<p>교보 첫째 장 8개, 둘째 장 11개, 삼선 2개를 같은 수동 정답으로 채점했다.
숫자 천 단위 표기를 정규화하고 정답 하나가 맞아야 성공이다. 전체·행 사진은 해당 위치도 맞아야 한다.</p>
''' + table(['입력 / 평가','ML Kit','PaddleOCR','Tesseract PSM 3'],android_rows) + '''
<h2>상품명 단독 영역</h2>
''' + table(['엔진','이름 전체 일치','문자 편집 오류율'],android_names) + '''
<p>이름은 공백·기호·대소문자를 제외하고 한글 완성형·분해형을 NFC로 정규화했다.
모델이 반환한 한 글줄을 임의의 단어 좌표로 쪼개지 않았다.</p>
<p>단독 수량을 읽는 성적과 전체 사진에서 그 수량의 위치를 찾는 성적은 다르다.
상품 자동 연결·검토 화면의 최종 정확도는 이 표의 평가 대상이 아니다.</p>
<p class="small">근거: Android summary.json · localization-summary.json. 사전 Ubuntu 시험 성적과 합산하지 않는다.</p>
''')

android_padding=[]
for kind,label in [('quantity','수량 단독 영역'),('amount','금액 단독 영역')]:
    android_padding.append([label]+[android_score(f'{engine}-padding-psm3',kind,suite='padding') for engine in ['mlkit','paddle','tesseract']])
page('17. Android 추가 시험과 남은 제약', '''
<h2>최소 크기와 작은 숫자</h2>
<p>기본 입력 217건에서 ML Kit는 트레이더스의 작은 크롭 45건에 최소 크기 오류를 반환했다.
Paddle·Tesseract는 기본 217건에서 실행 오류가 없었다. 같은 흰 여백으로 최소 32px를 맞춘
45개 추가 입력은 세 엔진 모두 실행 오류가 없었다. 빈 인식과 실행 오류는 따로 센다.</p>
''' + table(['공통 여백 입력','ML Kit','PaddleOCR','Tesseract PSM 3'],android_padding) + '''
<h2>Tesseract 설정을 따로 비교</h2>
''' + table(['수량 단독 영역 / 원본 21개','정답'],[
['PSM 3: 자동 영역 분할',android_score('tesseract-base-psm3','quantity')],
['PSM 7: 한 줄',android_score('tesseract-base-psm7','quantity')],
['PSM 10: 한 글자, 숫자 제한',android_score('tesseract-base-psm10','quantity')],
]) + '''
<h2>배포 과정에서 실제 확인한 실패</h2>
<p>Paddle SDK의 예제 OpenCV 4.5.3은 x86_64 라이브러리 로딩 오류가 있었다. 비교 모듈에서 공식
OpenCV 4.12.0으로 연결했다. Paddle 모델의 이미지 입력을 준비하고 검출 상자를 처리하는 데 사용한다.
''' + cite(24) + '''</p>
<p>4000px 검출은 12MP 원본에서 Java 메모리 부족으로 종료됐고, 메모리 한도 확대 후에도
프로세스 메모리 약 1.9GB에서 종료됐다. 최종 비교는 한도 확대 없이 1600px 검출을 사용한다.</p>
<h2>해석 범위</h2>
<p>모두 Android에서 실행했지만 에뮬레이터 결과다. 실기기·iOS, 손글씨·매장·구매일 정확도,
발열·최대 메모리·엔진별 설치 용량은 미측정이다. 디버그 호출 시간은 입력 크기와 엔진별 빈 결과에
영향을 받으므로 휴대폰 속도 순위로 제시하지 않는다. 최종 기술 선정은 하지 않는다.</p>
''')

for start, end, title in [(0,11,'18. 공식 참고 자료 — OCR 개발 도구'),(11,len(SOURCES),'19. 공식 참고 자료 — OCR 모델·API')]:
    refs = ''.join(f'<li><a href="{url}">[{i+1}] {escape(label)}</a><div class="source-url">{escape(url)}</div></li>' for i,(label,url) in enumerate(SOURCES) if start <= i < end)
    page(title, '<p>공식 문서 확인일: 2026년 10월 11일. 각 제목과 본문의 출처 번호를 누르면 원문으로 이동한다.</p><ol class="references" start="'+str(start+1)+'">'+refs+'</ol>')

font_regular = (ROOT / 'app/assets/fonts/NotoSansKR-Regular.ttf').as_uri()
font_bold = (ROOT / 'app/assets/fonts/NotoSansKR-Bold.ttf').as_uri()
css = '''
@font-face {font-family:ReportKR;src:url("REGULAR");font-weight:400}
@font-face {font-family:ReportKR;src:url("BOLD");font-weight:700}
@page {size:A4;margin:17mm 18mm 18mm;
 @top-right {content:"얼마였지 · 온디바이스 AI";font-family:ReportKR;font-size:8pt;color:#71818b}
 @bottom-left {content:"2026.10.12 / OCR 기술 조사·모델 비교 v1.6";font-family:ReportKR;font-size:8pt;color:#71818b}
 @bottom-right {content:counter(page) " / " counter(pages);font-family:ReportKR;font-size:8pt;color:#71818b}}
* {box-sizing:border-box} body {font-family:ReportKR;color:#20323d;font-size:10pt;line-height:1.65}
section {break-before:page} section:first-of-type {break-before:auto}
.eyebrow {color:#ca6c32;font-weight:700;font-size:9pt;margin-bottom:12px}
h1 {font-size:23pt;line-height:1.35;margin:0 0 20px;white-space:pre-line;color:#173642}
h2 {font-size:13pt;line-height:1.45;margin:20px 0 9px;color:#173642;break-after:avoid}
p {margin:0 0 11px;overflow-wrap:break-word} .subtitle {font-size:12pt;color:#667883}
.cover-brand {font-size:32pt;color:#ca6c32;font-weight:700;margin:25px 0}
table {width:100%;border-collapse:collapse;table-layout:fixed;font-size:9pt;line-height:1.5;margin:12px 0 16px}
thead {display:table-header-group} tr {break-inside:avoid}
th {background:#173642;color:white;text-align:left;padding:8px 9px} td {padding:8px 9px;vertical-align:top;border-bottom:1px solid #d9e2e6;overflow-wrap:break-word;white-space:pre-line}
tr:nth-child(even) td {background:#f4f7f8}
pre {font-family:ReportKR;white-space:pre-wrap;overflow-wrap:break-word;font-size:8.2pt;line-height:1.48;background:#f4f7f8;border:1px solid #d9e2e6;padding:12px;margin:10px 0;break-inside:avoid}
.small {font-size:8.2pt;color:#667883} .cite {font-size:8pt} a {color:#256d85;text-decoration:none}
.references {list-style:none;padding-left:0;font-size:9pt;line-height:1.5} .references li {margin-bottom:10px;break-inside:avoid}
.source-url {font-size:7.1pt;color:#667883;overflow-wrap:anywhere}
'''.replace('REGULAR',font_regular).replace('BOLD',font_bold)
html = '<!doctype html><html lang="ko"><head><meta charset="utf-8"><title>'+NAME+'</title><style>'+css+'</style></head><body>'+''.join(pages)+'</body></html>'
(HERE / (NAME+'.html')).write_text(html)
HTML(string=html,base_url=str(HERE)).write_pdf(HERE / (NAME+'.pdf'))
print(HERE / (NAME+'.pdf'))
