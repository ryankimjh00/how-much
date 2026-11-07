import 'package:dartcv4/dartcv.dart' as cv;
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/receipt_stitch_alignment.dart';
import 'package:how_much/receipt_stitch_match.dart';

// [OCR 추가] 실제 OCR 결과 대신 좌표 오차와 픽셀 존재 마스크의 안전 조건을 검사한다.
void main() {
  const identity = [1.0, 0.0, 0.0, 0.0, 1.0, 0.0, 0.0, 0.0, 1.0];
  final points = <ReceiptStitchPoint>[
    for (var row = 0; row < 5; row++)
      for (var column = 0; column < 6; column++)
        (x: 100.0 + column * 70, y: 100.0 + row * 40),
  ];
  test('주변이 지지한 이동량을 보정하고 겹침에서 멀어지면 보정을 없앤다', () {
    final alignment = ReceiptStitchAlignment.fromMatches(identity, points, [
      for (final point in points) (x: point.x + 4, y: point.y - 12),
    ])!;
    expect(alignment.offsetAt(250, 180).x, closeTo(4, .001));
    expect(alignment.offsetAt(250, 180).y, closeTo(-12, .001));
    expect(alignment.offsetAt(250, 600).y, 0);
    expect(alignment.offsetAt(250, -200).x, 0);
  });
  test('이동량이 너무 크거나 이웃 지지가 없는 점은 부분 보정에 쓰지 않는다', () {
    expect(
      ReceiptStitchAlignment.fromMatches(identity, points, [
        for (final point in points) (x: point.x, y: point.y + 36),
      ]),
      isNull,
    );
    final isolated = [
      for (var i = 0; i < 25; i++) (x: i * 200.0, y: i * 200.0),
    ];
    expect(
      ReceiptStitchAlignment.fromMatches(identity, isolated, isolated),
      isNull,
    );
    expect(ReceiptStitchAlignment.fromMatches(identity, points, []), isNull);
  });
  // [OCR 추가] 낮은 전체 정합 비율을 보완할 때도 충분한 지지와 독립된 예측이 필요하다.
  test('주변 보정이 가능한 점이35% 이상일 때만 추가 경로를 허용한다', () {
    final alignment = ReceiptStitchAlignment.fromMatches(identity, points, [
      for (final point in points) (x: point.x + 4, y: point.y - 12),
    ])!;
    expect(
      alignment.hasReliableSupport(matchCount: 80, shorterHeight: 1000),
      isTrue,
    );
    expect(
      alignment.hasReliableSupport(matchCount: 100, shorterHeight: 1000),
      isFalse,
    );
    expect(
      alignment.hasReliableSupport(matchCount: 20, shorterHeight: 1000),
      isFalse,
    );
    expect(
      alignment.hasReliableSupport(matchCount: 80, shorterHeight: 3000),
      isFalse,
    );
  });
  test('자기 점만으로 맞아 보이는 불규칙한 이동량은 보정 근거로 인정하지 않는다', () {
    final alignment = ReceiptStitchAlignment.fromMatches(identity, points, [
      for (var i = 0; i < points.length; i++)
        (x: points[i].x, y: points[i].y + (i.isEven ? 20 : -20)),
    ])!;
    expect(
      alignment.hasReliableSupport(
        matchCount: points.length,
        shorterHeight: 1000,
      ),
      isFalse,
    );
  });
  test('영역 밖을 가져온 픽셀 존재 마스크는 흰 공백으로 바꾸지 않는다', () {
    final alignment = ReceiptStitchAlignment.fromMatches(identity, points, [
      for (final point in points) (x: point.x + 10, y: point.y),
    ])!;
    final white = cv.Scalar.all(255);
    final mask = cv.Mat.fromScalar(500, 600, cv.MatType.CV_8UC1, white);
    try {
      applyReceiptStitchAlignment(
        mask,
        alignment,
        scale: 1,
        firstOffset: 0,
        isMask: true,
      );
      expect(mask.at<int>(180, 599), 0);
      expect(mask.at<int>(180, 300), 255);
    } finally {
      mask.dispose();
      white.dispose();
    }
  });
  test('출력 경계에 한쪽 글자만 있어도 절단하지 않는다', () {
    final white = cv.Scalar.all(255);
    final black = cv.Scalar.all(0);
    final first = cv.Mat.fromScalar(100, 300, cv.MatType.CV_8UC3, white);
    final second = first.clone();
    final rect = cv.Rect(140, 0, 20, 100);
    cv.Mat? stripe;
    try {
      expect(
        verifyReceiptStitchCut(first, second, center: 50, left: 20, right: 280),
        50,
      );
      stripe = second.region(rect);
      stripe.setTo(black);
      expect(
        verifyReceiptStitchCut(first, second, center: 50, left: 20, right: 280),
        isNull,
      );
      expect(
        verifyReceiptStitchCut(first, second, center: 5, left: 20, right: 280),
        isNull,
      );
    } finally {
      stripe?.dispose();
      rect.dispose();
      second.dispose();
      first.dispose();
      black.dispose();
      white.dispose();
    }
  });
}
