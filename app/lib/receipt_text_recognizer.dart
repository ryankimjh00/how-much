import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// [OCR 수정] 영수증과 메모에서 공통으로 사용하는 한국어 ML Kit 연결부다.
/// 이 객체 안에서는 인식기를 재사용하지만, 다른 객체와 인식기를 공유하지는 않는다.
/// 사진 보정·상품 선택·수량 계산은 담당하지 않고 인식된 글자와 좌표를 그대로 전달한다.
class ReceiptTextRecognizer {
  TextRecognizer? _recognizer;
  bool _closed = false;

  /// [OCR 수정] 사진을 읽고 ML Kit의 원문·좌표를 반환한다. 오류도 호출자에게 그대로 전달한다.
  /// 호출자는 인식이 끝난 뒤 close()를 호출해야 한다. close() 자체는 진행 중 인식을 기다리지 않는다.
  Future<RecognizedText> processImage(InputImage image) async {
    if (_closed) throw StateError('종료된 OCR 인식기입니다.');
    // [OCR 추가] 첫 요청에서만 인식기를 만든다. 같은 사진을 다시 읽을 때마다 모델을 준비하지 않기 위해서다.
    final recognizer = _recognizer ??= TextRecognizer(
      script: TextRecognitionScript.korean,
    );
    return recognizer.processImage(image);
  }

  /// [OCR 수정] 성공·실패와 관계없이 사용이 끝나면 호출해 기기 자원을 해제한다.
  /// 여러 번 호출해도 해제 요청은 한 번만 보낸다. 인식한 적이 없다면 해제할 자원도 없다.
  Future<void> close() async {
    if (_closed) return;
    // [OCR 추가] 기기 쪽 해제가 끝나기 전에도 새 인식 요청을 받지 않도록 먼저 종료 상태로 바꾼다.
    _closed = true;
    await _recognizer?.close();
  }
}
