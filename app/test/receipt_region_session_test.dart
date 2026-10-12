import 'dart:async'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/services.dart'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/ocr_service.dart'; // [OCR 추가]
import 'package:how_much/receipt_image.dart'; // [OCR 추가]
import 'receipt_region_test.dart' show regionPhoto; // [OCR 추가]
import 'receipt_tilt_test.dart' show response; // [OCR 추가]

void main() {
  TestWidgetsFlutterBinding.ensureInitialized(); // [OCR 추가]
  // [OCR 추가] 네이티브 응답은 모의다. 실제 이미지 자르기와 인식기 ID/정리 순서를 검사한다.
  const channel = MethodChannel('google_mlkit_text_recognizer'); // [OCR 추가]
  final messenger = TestDefaultBinaryMessengerBinding
      .instance
      .defaultBinaryMessenger; // [OCR 추가]
  for (final outcome in ['success', 'error', 'cancel']) {
    testWidgets('사진 세션의 픽셀·좌표·인식기 재사용과 정리: $outcome', (tester) async {
      final path = await regionPhoto(tester); // [OCR 추가]
      await tester.runAsync(() async {
        final bytes = await File(path).readAsBytes(); // [OCR 추가]
        final ids = <String>[]; // [OCR 추가]
        final paths = <String>[]; // [OCR 추가]
        var closes = 0; // [OCR 추가]
        const firstBounds = ui.Rect.fromLTWH(
          30.3,
          40.2,
          150.4,
          80.6,
        ); // [OCR 추가]
        const secondBounds = ui.Rect.fromLTWH(10, 20, 200, 120); // [OCR 추가]
        final expected = [
          await cropReceiptRegion(bytes, firstBounds),
          await cropReceiptRegion(bytes, secondBounds),
        ]; // [OCR 추가]
        messenger.setMockMethodCallHandler(channel, (call) async {
          final arguments = call.arguments as Map; // [OCR 추가]
          if (call.method == 'vision#closeTextRecognizer') {
            closes++; // [OCR 추가]
            expect(arguments['id'], ids.first); // [OCR 추가]
            expect(await File(paths.last).exists(), isTrue); // [OCR 추가]
            return null;
          }
          ids.add(arguments['id'] as String); // [OCR 추가]
          paths.add(arguments['imageData']['path'] as String); // [OCR 추가]
          expect(
            await File(paths.last).readAsBytes(),
            orderedEquals(expected[ids.length - 1]),
          ); // [OCR 추가]
          if (outcome == 'error' && ids.length == 2) {
            throw PlatformException(code: 'test-ocr-failure'); // [OCR 추가]
          }
          return response(); // [OCR 추가]
        });
        ReceiptRegionSession? endedSession; // [OCR 추가]
        try {
          final work = OcrService(engine: 'mlkit').withReceiptRegionSession(
            bytes,
            (session) async {
              endedSession = session; // [OCR 추가]
              await session.recognizeRegion(firstBounds); // [OCR 추가]
              final rows = await session.recognizeRegionRows(
                secondBounds,
              ); // [OCR 추가]
              expect(rows, isNotEmpty); // [OCR 추가]
              expect(
                rows.first.bounds.left,
                50,
              ); // [OCR 추가] 크롭 왼쪽10+응답 왼쪽40으로 원본 좌표를 복원한다.
              expect(rows.first.bounds.top, 70); // [OCR 추가]
              expect(closes, 0); // [OCR 추가]
              return outcome == 'cancel' ? null : rows;
            },
          );
          if (outcome == 'error') {
            await expectLater(
              work,
              throwsA(isA<PlatformException>()),
            ); // [OCR 추가]
          } else {
            final result = await work; // [OCR 추가]
            if (outcome == 'cancel') expect(result, isNull); // [OCR 추가]
          }
          expect(ids, hasLength(2)); // [OCR 추가]
          expect(ids.toSet(), hasLength(1)); // [OCR 추가]
          expect(paths.toSet(), hasLength(1)); // [OCR 추가]
          expect(closes, 1); // [OCR 추가]
          expect(await File(paths.last).parent.exists(), isFalse); // [OCR 추가]
          await expectLater(
            endedSession!.recognizeRegion(firstBounds),
            throwsStateError,
          ); // [OCR 추가]
        } finally {
          messenger.setMockMethodCallHandler(channel, null); // [OCR 추가]
        }
      });
    });
  }
  for (final quantities in [
    <String>['1'],
    <String>['1', '1'],
    <String>[],
    <String>['1', '2'],
    <String>['I'],
    <String>['0'],
  ]) {
    // [OCR 추가]
    testWidgets('수량 행 문맥은 대상 영역 값만 확정한다: $quantities', (tester) async {
      // [OCR 추가]
      // [OCR 추가] 모의 응답이다. 가격/할인과 다른 행의 숫자를 수량으로 오인하지 않는지 검사한다.
      final path = await regionPhoto(tester); // [OCR 추가]
      await tester.runAsync(() async {
        // [OCR 추가]
        final bytes = await File(path).readAsBytes(); // [OCR 추가]
        const bounds = ui.Rect.fromLTWH(140, 80, 80, 80); // [OCR 추가]
        const crop = ui.Rect.fromLTWH(40, 80, 280, 80); // [OCR 추가]
        final expected = await cropReceiptRegion(bytes, crop); // [OCR 추가]
        messenger.setMockMethodCallHandler(channel, (call) async {
          // [OCR 추가]
          if (call.method == 'vision#closeTextRecognizer') {
            // [OCR 추가]
            return null; // [OCR 추가]
          } // [OCR 추가]
          final args = call.arguments as Map; // [OCR 추가]
          expect(
            await File(args['imageData']['path'] as String).readAsBytes(),
            orderedEquals(expected),
          ); // [OCR 추가]
          final raw = response(); // [OCR 추가]
          final lines = <Map<String, dynamic>>[]; // [OCR 추가]
          void add(
            String text,
            double left,
            double top,
            double right,
            double bottom,
          ) {
            // [OCR 추가]
            final line = Map<String, dynamic>.from(
              (raw['blocks'] as List).first['lines'][0] as Map,
            ); // [OCR 추가]
            line['text'] = text; // [OCR 추가]
            line['rect'] = {
              'left': left,
              'top': top,
              'right': right,
              'bottom': bottom,
            }; // [OCR 추가]
            line['points'] = <Map<String, int>>[]; // [OCR 추가]
            lines.add(line); // [OCR 추가]
          } // [OCR 추가]

          add('2,000', 10, 20, 80, 70); // [OCR 추가]
          add('0', 240, 20, 250, 70); // [OCR 추가]
          add('7', 110, 90, 120, 130); // [OCR 추가] 크롭 밖의 다른 행 응답도 제외한다.
          for (final value in quantities) {
            add(value, 110, 20, 120, 70);
          } // [OCR 추가]
          (raw['blocks'] as List).first['lines'] = lines; // [OCR 추가]
          return raw; // [OCR 추가]
        }); // [OCR 추가]
        try {
          // [OCR 추가]
          final value = await OcrService(engine: 'mlkit')
              .withReceiptRegionSession(
                bytes,
                (session) => session.recognizeQuantityRegion(
                  bounds,
                  horizontalContext: 100,
                ),
              ); // [OCR 추가]
          expect(
            value,
            quantities.isNotEmpty && quantities.every((v) => v == '1')
                ? '1'
                : '',
          ); // [OCR 추가]
        } finally {
          // [OCR 추가]
          messenger.setMockMethodCallHandler(channel, null); // [OCR 추가]
        } // [OCR 추가]
      }); // [OCR 추가]
    }); // [OCR 추가]
  } // [OCR 추가]
  testWidgets('두 인식기는 사진을 공유해도 파일이 분리되고 취소 후 두 종료를 기다린다', (tester) async {
    // [OCR 추가] 네이티브 호출을 동시에 대기시켜 같은 파일 덮어쓰기와 조기 정리를 검사한다.
    final path = await regionPhoto(tester);
    await tester.runAsync(() async {
      final bytes = await File(path).readAsBytes();
      final started = Completer<void>();
      final release = Completer<Map<String, dynamic>>();
      final ids = <String>[];
      final paths = <String>[];
      final closes = <String>[];
      final pending = <Future<String>>[];
      messenger.setMockMethodCallHandler(channel, (call) async {
        final args = call.arguments as Map;
        if (call.method == 'vision#closeTextRecognizer') {
          closes.add(args['id'] as String);
          expect(await File(paths.last).exists(), isTrue);
          return null;
        }
        ids.add(args['id'] as String);
        paths.add(args['imageData']['path'] as String);
        if (ids.length == 2) started.complete();
        return await release.future;
      });
      try {
        final work = OcrService(engine: 'mlkit').withReceiptRegionSession(
          bytes,
          (session) async {
            pending.add(
              session.recognizeRegion(const ui.Rect.fromLTWH(0, 0, 200, 200)),
            );
            pending.add(
              session.quantitySession!.recognizeRegion(
                const ui.Rect.fromLTWH(0, 0, 100, 100),
              ),
            );
            await started.future;
            return null; // [OCR 추가] 인식 진행 중 화면에서 취소한 상태를 재현한다.
          },
          parallelQuantity: true,
        );
        await started.future.timeout(const Duration(seconds: 2));
        expect(ids.toSet(), hasLength(2));
        expect(paths.toSet(), hasLength(2));
        expect(closes, isEmpty);
        release.complete(response());
        await work;
        await Future.wait(pending);
        expect(closes.toSet(), ids.toSet());
        for (final path in paths) {
          expect(await File(path).exists(), isFalse);
        } // [OCR 추가]
      } finally {
        if (!release.isCompleted) release.complete(response());
        messenger.setMockMethodCallHandler(channel, null);
      }
    });
  }); // [OCR 추가]
  testWidgets('취소 중인 OCR이 끝나기 전에 세션 자원을 닫지 않고 중복 호출을 막는다', (tester) async {
    final path = await regionPhoto(tester); // [OCR 추가]
    await tester.runAsync(() async {
      final bytes = await File(path).readAsBytes(); // [OCR 추가]
      final started = Completer<void>(); // [OCR 추가]
      final completed = Completer<Map<String, dynamic>>(); // [OCR 추가]
      var closes = 0; // [OCR 추가]
      String? temporaryPath; // [OCR 추가]
      messenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'vision#closeTextRecognizer') {
          closes++; // [OCR 추가]
          return null;
        }
        temporaryPath =
            (call.arguments as Map)['imageData']['path'] as String; // [OCR 추가]
        started.complete(); // [OCR 추가]
        return await completed.future; // [OCR 추가]
      });
      try {
        late Future<String> pending; // [OCR 추가]
        final work = OcrService(engine: 'mlkit').withReceiptRegionSession(
          bytes,
          (session) async {
            pending = session.recognizeRegion(
              const ui.Rect.fromLTWH(0, 0, 200, 200),
            ); // [OCR 추가]
            await started.future; // [OCR 추가]
            await expectLater(
              session.recognizeRegion(const ui.Rect.fromLTWH(0, 0, 30, 30)),
              throwsStateError,
            ); // [OCR 추가]
            return null; // [OCR 추가] 화면 취소로 먼저 반환해도 진행 중인 인식은 정리 전 기다린다.
          },
        );
        await started.future; // [OCR 추가]
        expect(closes, 0); // [OCR 추가]
        expect(await File(temporaryPath!).exists(), isTrue); // [OCR 추가]
        completed.complete(response()); // [OCR 추가]
        await work; // [OCR 추가]
        await pending; // [OCR 추가]
        expect(closes, 1); // [OCR 추가]
        expect(await File(temporaryPath!).parent.exists(), isFalse); // [OCR 추가]
      } finally {
        messenger.setMockMethodCallHandler(channel, null); // [OCR 추가]
      }
    });
  });
}
