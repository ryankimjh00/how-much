// [OCR 수정] ML Kit 호출을 모의 응답으로 바꿔 인식기 사용·해제와 좌표 전달을 검사한다.
// 실제 사진 OCR은 실행하지 않는다. 호출 횟수·객체 구분을 검증하며 모델의 정확도나 속도는 측정하지 않는다.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:how_much/receipt_text_recognizer.dart';
import 'receipt_recognizer_response.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const channel = MethodChannel('google_mlkit_text_recognizer');
  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('전체·부분 인식은 한국어 ML Kit를 재사용하고 한 번 해제한다', () async {
    final methods = <String>[];
    final ids = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      methods.add(call.method);
      final args = call.arguments as Map;
      ids.add(args['id'] as String);
      if (call.method == 'vision#closeTextRecognizer') return null;
      expect(args['script'], TextRecognitionScript.korean.index);
      return {'text': '퍼실', 'blocks': []};
    });
    final reader = ReceiptTextRecognizer();
    final image = InputImage.fromFilePath('/photo.png');
    expect((await reader.processImage(image)).text, '퍼실');
    await reader.processImage(image);
    await reader.close();
    await reader.close();
    // [OCR 추가] 같은 인식기 ID로 두 번 읽고 한 번만 닫아야 모델을 불필요하게 다시 만들지 않는다.
    expect(ids.toSet(), hasLength(1));
    expect(methods, [
      'vision#startTextRecognizer',
      'vision#startTextRecognizer',
      'vision#closeTextRecognizer',
    ]);
    await expectLater(reader.processImage(image), throwsStateError);
    expect(methods, hasLength(3));
  });

  test('ML Kit 실패를 빈 성공으로 바꾸지 않고 해제한다', () async {
    var closes = 0;
    messenger.setMockMethodCallHandler(channel, (call) async {
      if (call.method == 'vision#closeTextRecognizer') {
        closes++;
        return null;
      }
      throw PlatformException(code: 'ocr_failed');
    });
    final reader = ReceiptTextRecognizer();
    await expectLater(
      reader.processImage(InputImage.fromFilePath('/photo.png')),
      throwsA(isA<PlatformException>()),
    );
    await reader.close();
    expect(closes, 1);
  });

  test('서로 다른 인식기를 해제해도 다른 사진 인식기는 유지한다', () async {
    final ids = <String>[];
    final closes = <String>[];
    messenger.setMockMethodCallHandler(channel, (call) async {
      final id = (call.arguments as Map)['id'] as String;
      if (call.method == 'vision#closeTextRecognizer') {
        closes.add(id);
        return null;
      }
      ids.add(id);
      return {'text': '', 'blocks': []};
    });
    final first = ReceiptTextRecognizer();
    final second = ReceiptTextRecognizer();
    final image = InputImage.fromFilePath('/photo.png');
    await first.processImage(image);
    await second.processImage(image);
    await first.close();
    await second.processImage(image);
    expect(ids.toSet(), hasLength(2));
    // [OCR 추가] 첫 인식기를 닫은 뒤에도 두 번째는 자기 ID로 계속 읽을 수 있어야 한다.
    expect(ids[1], ids[2]);
    expect(closes, [ids[0]]);
    await second.close();
  });

  test('서로 다른 위치의 수량 1 두 개를 각각 보존한다', () async {
    final result = mlkitResponseFromRecorded({
      'text': '1\n1',
      'lines': [
        for (final top in [200.0, 400.0])
          {
            'text': '1',
            'bounds': [100.0, top, 120.0, top + 30],
            'points': [
              [100, top],
              [120, top],
              [120, top + 30],
              [100, top + 30],
            ],
            'elements': [],
          },
      ],
    });
    messenger.setMockMethodCallHandler(
      channel,
      (call) async =>
          call.method == 'vision#closeTextRecognizer' ? null : result,
    );
    final reader = ReceiptTextRecognizer();
    final text = await reader.processImage(
      InputImage.fromFilePath('/photo.png'),
    );
    expect(
      text.blocks[0].lines.single.boundingBox,
      const Rect.fromLTRB(100, 200, 120, 230),
    );
    expect(
      text.blocks[1].lines.single.boundingBox,
      const Rect.fromLTRB(100, 400, 120, 430),
    );
    await reader.close();
  });
}
