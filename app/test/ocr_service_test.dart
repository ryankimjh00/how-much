import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:how_much/ocr_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('google_mlkit_text_recognizer');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('메모 사진에 한국어 모델을 요청하고 검토할 상품을 반환한다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#closeTextRecognizer') return null;
      return {'text': '- 우유 2개\n- 계란\n- 닭가슴살', 'blocks': []};
    });

    final lines = await OcrService().recognizeMemoPath('/memo.jpg');

    expect(lines.map((line) => line.title), ['우유', '계란', '닭가슴살']);
    expect(lines.first.quantity, 2);
    expect(lines.every((line) => !line.selected), isTrue);
    expect(calls.first.arguments['script'], TextRecognitionScript.korean.index);
    expect(calls.first.arguments['imageData']['type'], 'file');
    expect(calls.first.arguments['imageData']['path'], '/memo.jpg');
    expect(calls.last.method, 'vision#closeTextRecognizer');
    expect(calls.last.arguments['id'], calls.first.arguments['id']);
  });

  test('빈 인식 결과는 상품으로 만들지 않고 인식기를 해제한다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#closeTextRecognizer') return null;
      return {'text': '', 'blocks': []};
    });

    await expectLater(
      OcrService().recognizeMemoPath('/blank.jpg'),
      throwsA(isA<FormatException>()),
    );

    expect(calls.last.method, 'vision#closeTextRecognizer');
  });

  test('숫자와 기호로 오인식한 메모는 검토 상품으로 반환하지 않는다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#closeTextRecognizer') return null;
      return {'text': '7}971', 'blocks': []};
    });

    await expectLater(
      OcrService().recognizeMemoPath('/handwritten.jpg'),
      throwsA(isA<FormatException>()),
    );

    expect(calls.last.method, 'vision#closeTextRecognizer');
  });

  test('플랫폼 인식 오류를 숨기지 않고 인식기를 해제한다', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'vision#closeTextRecognizer') return null;
      throw PlatformException(code: 'image_unavailable');
    });

    await expectLater(
      OcrService().recognizeMemoPath('/missing.jpg'),
      throwsA(isA<PlatformException>()),
    );

    expect(calls.last.method, 'vision#closeTextRecognizer');
  });
}
