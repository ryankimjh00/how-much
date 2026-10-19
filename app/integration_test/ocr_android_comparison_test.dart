// [OCR 추가] 엔진마다 동일 실제 사진을 Android에서 독립 실행하여 원문·좌표를 남긴다.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';

import 'package:how_much/receipt_text_recognizer.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  final engine = ReceiptTextRecognizer.selectedEngine; // [OCR 수정]
  const suite = String.fromEnvironment('OCR_SUITE', defaultValue: 'base');
  const psm = int.fromEnvironment('OCR_PSM', defaultValue: 3);
  const maxCases = int.fromEnvironment('OCR_MAX_CASES', defaultValue: 10000);
  testWidgets(
    'Android $engine 동일 사진 독립 비교 / $suite / PSM $psm',
    (tester) async {
      final cases = await ReceiptTextRecognizer.comparisonChannel
          .invokeListMethod<dynamic>('prepareCases', {'suite': suite});
      expect(cases, isNotNull);
      final reader = ReceiptTextRecognizer();
      final path =
          '${Directory.systemTemp.path}/ocr-android-$engine-$suite-psm$psm.jsonl';
      final output = File(path).openWrite();
      var completed = 0;
      var successfulExecutions = 0; // [OCR 추가] 모델 초기화가 모두 실패한 실행은 통과시키지 않는다.
      try {
        for (final raw in cases!) {
          if (completed >= maxCases) break;
          final item = Map<String, dynamic>.from(raw as Map);
          if (psm == 10 && item['kind'] != 'quantity') continue;
          if (psm == 7 && item['kind'] == 'whole') continue;
          final input = File(item['path'] as String);
          expect(
            sha256.convert(await input.readAsBytes()).toString(),
            item['sha256'],
          );
          final record = <String, dynamic>{
            'id': item['id'],
            'engine': '$engine-android',
            'suite': suite,
            'sha256': item['sha256'],
            'psm': psm,
          };
          final timer = Stopwatch()..start();
          try {
            final recognized = await reader.processImage(
              InputImage.fromFilePath(input.path),
              psm: psm,
            );
            record['text'] = recognized.text;
            successfulExecutions++;
            record['tokens'] = [
              for (final block in recognized.blocks)
                for (final line in block.lines)
                  for (final element in line.elements)
                    {
                      'text': element.text,
                      'confidence': element.confidence,
                      'bounds': [
                        element.boundingBox.left,
                        element.boundingBox.top,
                        element.boundingBox.right,
                        element.boundingBox.bottom,
                      ],
                    },
            ];
            record['lines'] = [
              for (final block in recognized.blocks)
                for (final line in block.lines)
                  {
                    'text': line.text,
                    'bounds': [
                      line.boundingBox.left,
                      line.boundingBox.top,
                      line.boundingBox.right,
                      line.boundingBox.bottom,
                    ],
                  },
            ];
          } catch (error) {
            record['text'] = '';
            record['error'] = error.toString();
          }
          timer.stop();
          record['seconds'] = timer.elapsedMicroseconds / 1000000;
          final serialized = jsonEncode(record);
          output.writeln(serialized);
          await output.flush();
          // [OCR 추가] 앱 기록을 지우지 않고 시험 결과만 수집한다.
          // ignore: avoid_print
          print('ANDROID_OCR_COMPARE $serialized');
          completed++;
        }
      } finally {
        await reader.close();
        await output.close();
        await ReceiptTextRecognizer.comparisonChannel.invokeMethod<void>(
          'clearCases',
        );
      }
      expect(completed, greaterThan(0));
      expect(successfulExecutions, greaterThan(0));
      // [OCR 추가] 실행 완료와 인식 정답률을 구분하여 별도로 채점한다.
      // ignore: avoid_print
      print('ANDROID_OCR_OUTPUT $path $completed');
    },
    timeout: const Timeout(Duration(minutes: 30)),
  );
}
