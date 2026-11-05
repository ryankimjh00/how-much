import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/receipt_stitch.dart';
import 'package:how_much/receipt_stitch_match.dart';

// [OCR 추가] 합성 영상은 연결 안전성을 검사한다. 실제 영수증 촬영 결과와는 구분한다.
Future<Uint8List> photo(
  int top, {
  int seed = 51,
  bool tilted = false,
  bool blank = false,
}) async {
  const width = 600;
  const height = 1000;
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawColor(const ui.Color(0xffeeeeee), ui.BlendMode.src);
  if (tilted) {
    canvas.translate(width / 2, height / 2);
    canvas.rotate(.018);
    canvas.scale(1.02, .99);
    canvas.translate(-width / 2, -height / 2);
  }
  final paint = ui.Paint()..color = const ui.Color(0xff101010);
  if (!blank) {
    for (var row = 0; row < 1600; row += 40) {
      final random = Random(seed + row);
      for (var glyph = 0; glyph < 35; glyph++) {
        final left = 60 + random.nextInt(450);
        final y = row + 4 + random.nextInt(4) - top;
        final w = 3 + random.nextInt(9);
        final h = 9 + random.nextInt(9);
        canvas.drawRect(
          ui.Rect.fromLTWH(
            left.toDouble(),
            y.toDouble(),
            w.toDouble(),
            h.toDouble(),
          ),
          paint,
        );
      }
    }
  }
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  test('원근 행렬의 투영과 정상적인 아래쪽 확장을 허용한다', () {
    const matrix = [1.0, .01, 2.0, .01, 1.02, 600.0, .00001, .00001, 1.0];
    final corners = validateReceiptStitchProjection(
      matrix,
      firstWidth: 1000,
      firstHeight: 1000,
      secondWidth: 1000,
      secondHeight: 1000,
    );
    expect(corners, isNotNull);
    expect(projectReceiptStitchPoint(matrix, 0, 0), (x: 2.0, y: 600.0));
  });
  test('동일 사진·반전·발산·과도한 확대를 연결하지 않는다', () {
    for (final matrix in [
      [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0],
      [-1.0, 0.0, 1000.0, 0.0, 1.0, 600.0, 0.0, 0.0, 1.0],
      [1.0, 0.0, 0.0, 0.0, 1.0, 600.0, -.01, 0.0, 1.0],
      [5.0, 0.0, 0.0, 0.0, 1.0, 600.0, 0.0, 0.0, 1.0],
    ]) {
      expect(
        validateReceiptStitchProjection(
          matrix,
          firstWidth: 1000,
          firstHeight: 1000,
          secondWidth: 1000,
          secondHeight: 1000,
        ),
        isNull,
      );
    }
  });
  test('글자가 없는 실제 겹침에서만 경계를 고른다', () {
    final inkA = List<int>.filled(100, 0);
    final inkB = List<int>.filled(100, 0);
    final covered = List<bool>.filled(100, true);
    // 한쪽 사진에만 글자가 있어도 그 부근은 절단하지 않는다.
    inkB[50] = 30;
    final cut = findReceiptStitchCut(
      firstInk: inkA,
      secondInk: inkB,
      covered: covered,
      start: 10,
      end: 90,
      comparisonWidth: 900,
    );
    expect(cut, isNotNull);
    expect((cut! - 50).abs(), greaterThan(2));
    expect(
      findReceiptStitchCut(
        firstInk: inkA,
        secondInk: inkB,
        covered: List<bool>.filled(100, false),
        start: 10,
        end: 90,
        comparisonWidth: 900,
      ),
      isNull,
    );
    expect(
      findReceiptStitchCut(
        firstInk: List<int>.filled(100, 50),
        secondInk: inkB,
        covered: covered,
        start: 10,
        end: 90,
        comparisonWidth: 900,
      ),
      isNull,
    );
  });
  testWidgets('별도 각도·배율의 합성 두 장을 원근 정합하고 끝부분도 보존한다', (tester) async {
    await tester.runAsync(() async {
      final a = await photo(0);
      final b = await photo(600, tilted: true);
      final joined = await stitchReceiptPhotos([a, b], isCurrent: () => true);
      expect(joined, isNotNull);
      final codec = await ui.instantiateImageCodec(joined!);
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.height, closeTo(1600 * 1600 / 600, 200));
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final fraction in [.10, .90]) {
          var dark = 0;
          final start = (image.height * fraction).floor();
          for (var y = start; y < start + 80; y++) {
            for (var x = image.width ~/ 5; x < image.width * 4 ~/ 5; x++) {
              if (raw.getUint8((y * image.width + x) * 4) < 100) dark++;
            }
          }
          expect(
            dark,
            greaterThan(100),
            reason: '앞뒤 내용이 모두 남아야 하며 빈 결과를 성공으로 보지 않는다.',
          );
        }
      } finally {
        image.dispose();
        codec.dispose();
      }
    });
  });
  testWidgets('빈 사진·다른 무늬·동일 사진의 중복을 성공시키지 않는다', (tester) async {
    await tester.runAsync(() async {
      final a = await photo(0);
      for (final b in [
        await photo(600, blank: true),
        await photo(600, seed: 9876),
        a,
      ]) {
        await expectLater(
          stitchReceiptPhotos([a, b], isCurrent: () => true),
          throwsA(isA<FormatException>()),
        );
      }
    });
  });
  test('이미 취소된 작업은 사진을 디코딩하지 않는다', () async {
    expect(
      await stitchReceiptPhotos([
        Uint8List(0),
        Uint8List(0),
      ], isCurrent: () => false),
      isNull,
    );
  });
  testWidgets('처리 중 취소되면 늦게 도착한 연결 결과를 적용하지 않는다', (tester) async {
    await tester.runAsync(() async {
      final a = await photo(0);
      final b = await photo(600);
      var active = true;
      final pending = stitchReceiptPhotos([a, b], isCurrent: () => active);
      active = false;
      expect(await pending, isNull);
    });
  });
}
