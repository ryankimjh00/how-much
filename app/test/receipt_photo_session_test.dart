// [OCR 수정] 고정 좌표의 ML Kit 모의 응답으로 사진별 인식기 수명과 실패 복구를 검증한다.
import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/ocr_service.dart';
import 'receipt_recognizer_response.dart';
import 'receipt_region_test.dart' show regionPhoto;
import 'receipt_tilt_test.dart' show response;

Map<String, dynamic> recordedPhotoResponse({bool corrected = false}) {
  final source = response(corrected: corrected);
  return {
    'text': source['text'],
    'lines': [
      for (final line in source['blocks'][0]['lines'])
        {
          'text': line['text'],
          'bounds': [
            line['rect']['left'],
            line['rect']['top'],
            line['rect']['right'],
            line['rect']['bottom'],
          ],
          'points': [
            for (final point in line['points']) [point['x'], point['y']],
          ],
          'elements': [],
        },
    ],
  };
}

Map<String, dynamic> fragmentedResponse() {
  Map<String, dynamic> line(String text, List<double> bounds) => {
    'text': text,
    'bounds': bounds,
    'points': [
      [bounds[0], bounds[1]],
      [bounds[2], bounds[1]],
      [bounds[2], bounds[3]],
      [bounds[0], bounds[3]],
    ],
    'elements': [],
  };
  return {
    'text': '스녀 섬으 유연제 를\n3\n80,940',
    'lines': [
      line('스녀', [104, 589, 168, 616]),
      line('섬으 유연제 를', [222, 589, 432, 629]),
      line('3', [500, 589, 520, 619]),
      line('80,940', [700, 589, 812, 619]),
    ],
  };
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(
      const MethodChannel('google_mlkit_text_recognizer'),
      null,
    ),
  );

  for (final outcome in [
    'success',
    'first-error',
    'corrected-error',
    'merged-error',
    'empty',
  ]) {
    testWidgets('사진 한 장 ML Kit 재사용과 해제: $outcome', (tester) async {
      final path = await regionPhoto(tester, width: 600, height: 400);
      final readIds = <String>[];
      final closedIds = <String>[];
      final paths = <String>[];
      messenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'),
        (call) async {
          final args = Map<String, dynamic>.from(call.arguments as Map);
          final id = args['id'] as String;
          if (call.method == 'vision#closeTextRecognizer') {
            closedIds.add(id);
            return null;
          }
          expect(closedIds, isEmpty); // [OCR 추가] 재인식 도중 공유 모델을 해제하지 않는다.
          readIds.add(id);
          paths.add((args['imageData'] as Map)['path'] as String);
          expect(await File(paths.last).exists(), isTrue);
          if (outcome == 'first-error' ||
              (outcome == 'corrected-error' && readIds.length == 2) ||
              (outcome == 'merged-error' && readIds.length == 3)) {
            throw PlatformException(code: 'read-failed');
          }
          if (outcome == 'empty') return {'text': '', 'blocks': []};
          if (readIds.length == 1) {
            return mlkitResponseFromRecorded(recordedPhotoResponse());
          }
          if (readIds.length == 2) {
            return mlkitResponseFromRecorded(fragmentedResponse());
          }
          return mlkitResponseFromRecorded({
            'text': '스너글 섬유유연제',
            'lines': [
              {
                'text': '스너글 섬유유연제',
                'bounds': [0.0, 0.0, 328.0, 40.0],
                'points': [
                  [0, 0],
                  [328, 0],
                  [328, 40],
                  [0, 40],
                ],
                'elements': [],
              },
            ],
          });
        },
      );
      await tester.runAsync(() async {
        final service = OcrService();
        if (outcome == 'first-error' || outcome == 'empty') {
          await expectLater(
            service.recognizePath(path),
            outcome == 'empty'
                ? throwsFormatException
                : throwsA(isA<PlatformException>()),
          );
        } else {
          final result = (await service.recognizePath(path)).ocrResult!;
          expect(
            result.numbers.map((candidate) => candidate.number),
            outcome == 'corrected-error' ? [2, 53960] : [3, 80940],
          );
          expect(result.products.single.text, switch (outcome) {
            'corrected-error' => '퍼실',
            'merged-error' => '스녀 섬으 유연제 를',
            _ => '스너글 섬유유연제',
          });
        }
        final expectedReads = switch (outcome) {
          'first-error' || 'empty' => 1,
          'corrected-error' => 2,
          _ => 3,
        };
        expect(readIds.length, expectedReads);
        expect(readIds.toSet(), hasLength(1));
        expect(closedIds, [readIds.first]);
        for (final path in paths) {
          expect(await File(path).parent.exists(), isFalse);
        }
      });
    });
  }

  testWidgets('같은 서비스의 동시 사진은 인식기를 서로 해제하지 않는다', (tester) async {
    final path = await regionPhoto(tester);
    final ids = <String>[];
    final closes = <String>[];
    // [OCR 추가] 모의 채널의 비동기 응답도 실제 비동기 영역에 등록해 가상 시계 대기를 피한다.
    await tester.runAsync(() async {
      final secondStarted = Completer<void>();
      messenger.setMockMethodCallHandler(
        const MethodChannel('google_mlkit_text_recognizer'),
        (call) async {
          final id = (call.arguments as Map)['id'] as String;
          if (call.method == 'vision#closeTextRecognizer') {
            closes.add(id);
            return null;
          }
          ids.add(id);
          if (ids.length == 1) {
            await secondStarted.future.timeout(const Duration(seconds: 30));
          } else {
            secondStarted.complete();
          }
          expect(closes.contains(id), isFalse);
          return mlkitResponseFromRecorded(
            recordedPhotoResponse(corrected: true),
          );
        },
      );
      final service = OcrService();
      final drafts = await Future.wait([
        service.recognizePath(path),
        service.recognizePath(path),
      ]);
      expect(drafts, hasLength(2));
      expect(ids.toSet(), hasLength(2));
      expect(closes.toSet(), ids.toSet());
      expect(closes, hasLength(2));
    });
  });
}
