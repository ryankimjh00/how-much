import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:how_much/models.dart';
import 'package:how_much/memo_text_recognizer.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const encodedFixtures = String.fromEnvironment('MEMO_OCR_FIXTURES');
  const fixtureDirectory = String.fromEnvironment('MEMO_OCR_FIXTURE_DIRECTORY');
  final fixtures = encodedFixtures.isEmpty
      ? <dynamic>[]
      : jsonDecode(encodedFixtures) as List;
  final reports = <Map<String, Object?>>[];
  final failures = <String>[];

  testWidgets('실제 사진과 기기 내 모델로 손글씨 인식을 검증한다', (tester) async {
    expect(fixtures, isNotEmpty, reason: 'MEMO_OCR_FIXTURES에 사진을 지정해야 합니다.');
    final directory = await Directory.systemTemp.createTemp('memo-ocr-test-');
    try {
      for (final fixture in fixtures) {
        final name = fixture['name'] as String;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(body: Center(child: Text('$name 인식 중'))),
          ),
        );
        final photo = File('${directory.path}/$name.jpg');
        final sourceDirectory = fixtureDirectory.isEmpty
            ? '${Directory.systemTemp.path}/memo-ocr-fixtures'
            : fixtureDirectory;
        final source = File('$sourceDirectory/${fixture['file']}');
        await source.copy(photo.path);
        final stopwatch = Stopwatch()..start();
        // 저장소만 분리하는 다른 시험과 달리 OCR의 네이티브 호출은 대체하지 않는다.
        final raw = await MemoTextRecognizer().processImage(photo.path);
        final lines = parseMemoText(raw);
        final normalized = raw.replaceAll(RegExp(r'\s'), '');
        reports.add({
          'name': name,
          'milliseconds': stopwatch.elapsedMilliseconds,
          'raw': raw,
          'items': [
            for (final line in lines)
              {'title': line.title, 'quantity': line.quantity},
          ],
        });
        binding.reportData = {'memoOcr': reports};
        for (final word in fixture['words'] as List) {
          if (!normalized.contains(word)) failures.add('$name: $word 누락');
        }
        final wordCounts = fixture['wordCounts'] as Map? ?? {};
        for (final word in wordCounts.keys) {
          final count = RegExp(
            RegExp.escape(word as String),
          ).allMatches(normalized).length;
          if (count < (wordCounts[word] as int)) {
            failures.add('$name: $word $count/${wordCounts[word]}개 인식');
          }
        }
        expect(lines.every((line) => !line.selected), isTrue);
      }
      expect(failures, isEmpty, reason: jsonEncode(reports));
    } finally {
      await directory.delete(recursive: true);
    }
  }, skip: encodedFixtures.isEmpty);
}
