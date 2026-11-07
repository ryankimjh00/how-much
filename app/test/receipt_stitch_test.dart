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
  int leftMargin = 0,
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
  canvas.translate(leftMargin.toDouble(), 0);
  final paint = ui.Paint()..color = const ui.Color(0xff101010);
  if (!blank) {
    for (var row = 0; row < 2800; row += 40) {
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
  final image = await picture.toImage(width + leftMargin, height);
  try {
    final data = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  test('실측 143.3px 세로 분포를 8% 기준으로 허용한다', () {
    expect(
      hasReceiptStitchPointSpread([
        (x: 100.0, y: 10.0),
        (x: 555.8, y: 153.291015625),
      ], shorterHeight: 1466),
      isTrue,
    );
  });
  test('8%보다 좁은 세로 분포는 계속 거부한다', () {
    expect(
      hasReceiptStitchPointSpread([
        (x: 100.0, y: 10.0),
        (x: 555.8, y: 125.0),
      ], shorterHeight: 1466),
      isFalse,
    );
  });
  test('세로가 충분해도 가로 한 곳에 몰린 일치점은 거부한다', () {
    expect(
      hasReceiptStitchPointSpread([
        (x: 100.0, y: 10.0),
        (x: 350.0, y: 170.0),
      ], shorterHeight: 1466),
      isFalse,
    );
  });
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
  test('사진 바깥 여백을 제외한 실제 겹침은 누적 폭을 다 덮지 않아도 허용한다', () {
    final mask = List<int>.filled(2000, 0);
    mask.fillRange(1040, 1880, 255);
    final overlap = findReceiptStitchOverlap(
      mask,
      start: 1000,
      end: 2000,
      minimumWidth: 300,
    );
    expect(overlap, (start: 1082, end: 1838));
    // 같은 행의 공통 구간 내부에 실제 픽셀이 빠지면 공백으로 간주하지 않는다.
    mask[1500] = 0;
    expect(
      findReceiptStitchOverlap(mask, start: 1000, end: 2000, minimumWidth: 300),
      isNull,
    );
  });
  test('너무 좁거나 없는 겹침은 여백을 무시해도 거부한다', () {
    final mask = List<int>.filled(1000, 0);
    expect(
      findReceiptStitchOverlap(mask, start: 0, end: 1000, minimumWidth: 300),
      isNull,
    );
    mask.fillRange(400, 600, 255);
    expect(
      findReceiptStitchOverlap(mask, start: 0, end: 1000, minimumWidth: 300),
      isNull,
    );
  });
  test('비교 폭이 좁아진 행에서는 같은 잉크량을 더 느슨하게 허용하지 않는다', () {
    expect(
      findReceiptStitchCut(
        firstInk: List<int>.filled(100, 3),
        secondInk: List<int>.filled(100, 0),
        covered: List<bool>.filled(100, true),
        start: 10,
        end: 90,
        comparisonWidth: 900,
        comparisonWidths: List<int>.filled(100, 400),
      ),
      isNull,
    );
  });
  test('글자가 없는 실제 겹침에서만 경계를 고른다', () {
    final inkA = List<int>.filled(100, 0);
    final inkB = List<int>.filled(100, 0);
    final covered = List<bool>.filled(100, true);
    // [OCR 수정] 한쪽 사진에만 글자가 있어도 그 행은 절단하지 않는다.
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
    expect(cut, isNot(50));
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
  // [OCR 추가] 이웃 행에 글자가 있어도 양쪽이 함께 빈 한 행은 사용할 수 있다.
  test('고립된 한 공백 행을 선택하고 서로 다른 높이의 공백은 거부한다', () {
    final firstInk = List<int>.filled(100, 30);
    final secondInk = List<int>.filled(100, 30);
    final covered = List<bool>.filled(100, true);
    firstInk[50] = 0;
    secondInk[50] = 0;
    int? chooseCut() => findReceiptStitchCut(
      firstInk: firstInk,
      secondInk: secondInk,
      covered: covered,
      start: 10,
      end: 90,
      comparisonWidth: 900,
    );
    expect(chooseCut(), 50);
    covered[50] = false;
    expect(chooseCut(), isNull);
    covered[50] = true;
    secondInk[50] = 30;
    secondInk[51] = 0;
    expect(chooseCut(), isNull);
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
  testWidgets('옆 여백이 넓어진 누적 사진에도 다음 장의 내용 영역을 이어붙인다', (tester) async {
    await tester.runAsync(() async {
      final joined = await stitchReceiptPhotos([
        await photo(0),
        await photo(600, leftMargin: 300),
        await photo(1200),
      ], isCurrent: () => true);
      expect(joined, isNotNull);
      final codec = await ui.instantiateImageCodec(joined!);
      final image = (await codec.getNextFrame()).image;
      try {
        // [OCR 수정] 누적 폭이 아닌 첫 원본 너비 600px를 기준으로 배율을 유지한다.
        expect(image.height, closeTo(2200 * 1600 / 600, 200));
        final raw = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        var dark = 0;
        for (var y = image.height * 9 ~/ 10; y < image.height * 19 ~/ 20; y++) {
          for (var x = 0; x < image.width; x++) {
            if (raw.getUint8((y * image.width + x) * 4) < 100) dark++;
          }
        }
        expect(dark, greaterThan(100), reason: '다음 장 끝부분의 내용도 남겨야 한다.');
      } finally {
        image.dispose();
        codec.dispose();
      }
    });
  });
  // [OCR 추가] 매번 원본 인접 쌍으로 대조해 중간 장과 마지막 장을 모두 유지한다.
  testWidgets('합성 네 장을 연결해 처음과 끝의 내용 및 전체 길이를 유지한다', (tester) async {
    await tester.runAsync(() async {
      final joined = await stitchReceiptPhotos([
        await photo(0),
        await photo(600),
        await photo(1200),
        await photo(1800),
      ], isCurrent: () => true);
      expect(joined, isNotNull);
      final codec = await ui.instantiateImageCodec(joined!);
      final image = (await codec.getNextFrame()).image;
      try {
        expect(image.height, closeTo(2800 * 1600 / 600, 200));
        final pixels = (await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        ))!;
        for (final fraction in [.1, .35, .6, .9]) {
          final y = (image.height * fraction).floor();
          var dark = 0;
          for (var row = y; row < y + 110; row++) {
            for (var x = image.width ~/ 5; x < image.width * 4 ~/ 5; x++) {
              if (pixels.getUint8((row * image.width + x) * 4) < 100) dark++;
            }
          }
          expect(
            dark,
            greaterThan(100),
            reason: '중간 장이나 끝 장이 빈 영역으로 사라지면 안 된다.',
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
