import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/receipt_stitch_layout.dart';
import 'package:how_much/receipt_stitch_match.dart';

// [OCR 추가] 하단으로 갈수록 좁아지는 원근변환을 일부러 넣어 본문의 폭이 유지되는지 검사한다.
ReceiptStitchPairPlan pairPlan({int cutY = 1200}) {
  const matrix = [1.0, 0.0, 0.0, 0.0, 1.0, 600.0, 0.0, .0001, 1.0];
  return ReceiptStitchPairPlan(
    matrix: matrix,
    inverse: invertReceiptStitchMatrix(matrix)!,
    alignment: null,
    firstHeight: 1600,
    secondHeight: 1600,
    cutY: cutY,
    bodyScale: 1,
    bodyTranslateX: 0,
    checkLeft: 100,
    checkRight: 1500,
    corners: [
      for (final p in [
        (0.0, 0.0),
        (1000.0, 0.0),
        (1000.0, 1000.0),
        (0.0, 1000.0),
      ])
        projectReceiptStitchPoint(matrix, p.$1, p.$2)!,
    ],
  );
}

void main() {
  test('원근변환이 좁아져도 네 장 본문의 가로 배율은 높이와 무관하다', () {
    final plan = pairPlan();
    final topWidth = projectReceiptStitchPoint(plan.matrix, 1000, 0)!.x;
    final bottomWidth = projectReceiptStitchPoint(plan.matrix, 1000, 1000)!.x;
    expect(bottomWidth, lessThan(topWidth));
    final layout = ReceiptStitchLayout(List.filled(3, plan));
    for (final photo in layout.photos) {
      for (final y in [
        photo.start + photo.transitionHeight + 1,
        photo.end - 1,
      ]) {
        final left = photo.sourceAt(100, y)!;
        final right = photo.sourceAt(1500, y)!;
        expect(right.x - left.x, closeTo(1400, .001));
      }
    }
    expect(layout.width, 1600);
  });
  test('연결 경계에서는 원근 정합을 쓰고 본문에서는 원본 배율로 돌아온다', () {
    final plan = pairPlan();
    final photo = ReceiptStitchLayout([plan]).photos[1];
    final expected = plan.secondSourceAt(800, 1200)!;
    final actual = photo.sourceAt(800, photo.start)!;
    expect(actual.x, closeTo(expected.x, .001));
    expect(actual.y, closeTo(expected.y, .001));
    final end = photo.start + photo.transitionHeight;
    final before = photo.sourceAt(800, end - .001)!;
    final after = photo.sourceAt(800, end + .001)!;
    expect((before.x - after.x).abs(), lessThan(.01));
    expect((before.y - after.y).abs(), lessThan(.01));
    expect(after.x, closeTo(800, .001));
  });
  test('서로 교차하는 연결 경계와 과도한 사진 수는 거부한다', () {
    expect(
      () => ReceiptStitchLayout([pairPlan(cutY: 20)]),
      throwsFormatException,
    );
    expect(() => ReceiptStitchLayout([]), throwsFormatException);
    expect(
      () => ReceiptStitchLayout(List.filled(10, pairPlan())),
      throwsFormatException,
    );
  });
  test('본문 배율은 점의 간격을 따르며 퇴화하거나 과도한 배율은 거부한다', () {
    final second = [(x: 0.0, y: 0.0), (x: 400.0, y: 0.0), (x: 0.0, y: 200.0)];
    final first = [
      for (final p in second) (x: p.x * 1.2 + 10, y: p.y * 1.2 + 500),
    ];
    final result = estimateReceiptStitchBodyScale(first, second)!;
    expect(result.scale, closeTo(1.2, .001));
    expect(result.translateX, closeTo(10, .001));
    expect(
      estimateReceiptStitchBodyScale(
        [second[0], second[0]],
        [second[0], second[0]],
      ),
      isNull,
    );
    expect(
      estimateReceiptStitchBodyScale([
        for (final p in second) (x: p.x * 2, y: p.y * 2),
      ], second),
      isNull,
    );
  });
  test('역변환은 대응 좌표를 복원하고 특이 행렬은 거부한다', () {
    final plan = pairPlan();
    final transformed = projectReceiptStitchPoint(plan.matrix, 400, 300)!;
    final restored = projectReceiptStitchPoint(
      plan.inverse,
      transformed.x,
      transformed.y,
    )!;
    expect(restored.x, closeTo(400, .001));
    expect(restored.y, closeTo(300, .001));
    expect(invertReceiptStitchMatrix(List.filled(9, 0)), isNull);
  });
}
