// [OCR 추가] 대체 엔진의 실패 은폐와 동일 숫자 좌표 혼동을 검증한다.

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import 'package:how_much/receipt_text_recognizer.dart';

Map<String, dynamic> candidate(double top) => {
  'text': '1',
  'bounds': [100.0, top, 120.0, top + 30],
  'points': [
    [100.0, top],
    [120.0, top],
    [120.0, top + 30],
    [100.0, top + 30],
  ],
  'confidence': 0.9,
  'angle': 0.0,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    debugDefaultTargetPlatformOverride = null; // [OCR 추가]
    messenger.setMockMethodCallHandler(ReceiptTextRecognizer.channel, null);
    messenger.setMockMethodCallHandler(
      ReceiptTextRecognizer.comparisonChannel,
      null,
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_text_recognizer'),
      null,
    );
  });

  test('Android 기본 인식기는 Paddle을 사용한다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(ReceiptTextRecognizer().engine, 'paddle');
  }); // [OCR 추가] 비교 옵션 없이 앱을 빌드해도 교체가 적용되어야 한다.

  test('iOS는 기존 ML Kit를 유지한다', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(ReceiptTextRecognizer().engine, 'mlkit');
  }); // [OCR 추가] Android 네이티브 채널을 iOS에 호출하지 않는다.

  test('같은 수량 두 개의 서로 다른 원본 상자를 보존한다', () {
    final first = candidate(200);
    final second = candidate(400);
    final result = receiptRecognizedTextFromNative({
      'text': '1\n1',
      'lines': [
        {
          ...first,
          'elements': [first],
        },
        {
          ...second,
          'elements': [second],
        },
      ],
    });
    expect(
      result.blocks[0].lines.single.elements.single.boundingBox,
      const Rect.fromLTRB(100, 200, 120, 230),
    );
    expect(
      result.blocks[1].lines.single.elements.single.boundingBox,
      const Rect.fromLTRB(100, 400, 120, 430),
    );
  });

  test('Paddle 실패를 ML Kit 성공이나 빈 성공으로 대체하지 않는다', () async {
    var fallbackCalls = 0;
    messenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_text_recognizer'),
      (call) async {
        fallbackCalls++;
        return {'text': '가짜 성공', 'blocks': []};
      },
    );
    messenger.setMockMethodCallHandler(ReceiptTextRecognizer.channel, (
      call,
    ) async {
      if (call.method == 'recognize') {
        throw PlatformException(code: 'ocr_failed', message: '모델 로딩 실패');
      }
      return null;
    });
    final reader = ReceiptTextRecognizer(engine: 'paddle');
    await expectLater(
      reader.processImage(InputImage.fromFilePath('/photo.png')),
      throwsA(isA<PlatformException>()),
    );
    expect(fallbackCalls, 0);
    await reader.close();
  });

  test('세션 ID를 분리하고 종료한 인식기는 다시 실행하지 않는다', () async {
    final ids = <String>[];
    messenger.setMockMethodCallHandler(
      ReceiptTextRecognizer.comparisonChannel,
      (call) async {
        if (call.method == 'recognize') {
          ids.add((call.arguments as Map)['id'] as String);
          return {'text': '', 'lines': []};
        }
        return null;
      },
    );
    final first = ReceiptTextRecognizer(engine: 'tesseract');
    final second = ReceiptTextRecognizer(engine: 'tesseract');
    final image = InputImage.fromFilePath('/photo.png');
    await first.processImage(image);
    await second.processImage(image);
    expect(ids.toSet(), hasLength(2));
    await first.close();
    await expectLater(first.processImage(image), throwsStateError);
    expect(ids, hasLength(2));
    await second.close();
  });
}
