// [OCR 추가] 운영 앱과 다른 패키지에서 실제 ML Kit 원문만 비교한다.
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('동일 사진의 한국어 ML Kit 독립 비교', (tester) async {
    const assetRoot = 'integration_test/model_compare_inputs';
    final cases =
        jsonDecode(await rootBundle.loadString('$assetRoot/manifest.json'))
            as List<dynamic>;
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    final folder = await Directory.systemTemp.createTemp('ocr-model-compare-');
    final output = File(
      '${Directory.systemTemp.path}/ocr-model-comparison.jsonl',
    ).openWrite();
    var completed = 0;
    try {
      for (final dynamic value in cases) {
        final item = value as Map<String, dynamic>;
        final id = item['id'] as String;
        final bytes = (await rootBundle.load(
          '$assetRoot/$id.png',
        )).buffer.asUint8List();
        expect(sha256.convert(bytes).toString(), item['sha256']);
        final photo = File('${folder.path}/$id.png');
        await photo.writeAsBytes(bytes, flush: true);
        final watch = Stopwatch()..start();
        final record = <String, dynamic>{
          'id': id,
          'engine': 'mlkit',
          'sha256': item['sha256'],
        };
        try {
          final result = await recognizer.processImage(
            InputImage.fromFilePath(photo.path),
          );
          watch.stop();
          record['text'] = result.text;
          record['tokens'] = [
            for (final block in result.blocks)
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
            for (final block in result.blocks)
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
        watch.stop();
        record['seconds'] = watch.elapsedMicroseconds / 1000000;
        final serialized = jsonEncode(record);
        output.writeln(serialized);
        // [OCR 추가] 호스트 로그에도 남겨 앱 저장소를 지우지 않고 결과를 회수한다.
        // ignore: avoid_print
        print('MODEL_COMPARE $serialized');
        await photo.delete();
        completed++;
      }
    } finally {
      await recognizer.close();
      await output.flush();
      await output.close();
      await folder.delete(recursive: true);
    }
    // [OCR 추가] 완료 건수만 확인한다. 인식 정확도는 별도 정답과 비교한다.
    expect(completed, cases.length);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
