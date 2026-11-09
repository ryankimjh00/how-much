import 'dart:math' as math;
import 'package:dartcv4/dartcv.dart' as cv;
import 'receipt_stitch_match.dart';

/// [OCR 추가] 전체 원근변환 뒤의 작은 위치 오차를 주변 대응점으로 보간한다.
/// 모든 좌표는 너비 1000px 비교 영상 기준이다. OCR 문자값은 사용하지 않는다.
class ReceiptStitchAlignment {
  ReceiptStitchAlignment._(this.points, this.offsets)
    : left = points.map((point) => point.x).reduce(math.min),
      right = points.map((point) => point.x).reduce(math.max),
      top = points.map((point) => point.y).reduce(math.min),
      bottom = points.map((point) => point.y).reduce(math.max);

  final List<ReceiptStitchPoint> points;
  final List<ReceiptStitchPoint> offsets;
  final double left;
  final double right;
  final double top;
  final double bottom;

  /// [OCR 추가] 주변의 다른 두 점 이상이 비슷한 이동량을 지지하는 대응점만 채택한다.
  /// 지지점이 부족하면 null을 반환해 전체 원근변환만 사용한다.
  static ReceiptStitchAlignment? fromMatches(
    List<double> matrix,
    List<ReceiptStitchPoint> first,
    List<ReceiptStitchPoint> second,
  ) {
    if (first.length != second.length) return null;
    final points = <ReceiptStitchPoint>[];
    final offsets = <ReceiptStitchPoint>[];
    for (var i = 0; i < first.length; i++) {
      final target = first[i];
      if (!target.x.isFinite || !target.y.isFinite) continue;
      final projected = projectReceiptStitchPoint(
        matrix,
        second[i].x,
        second[i].y,
      );
      if (projected == null) continue;
      // 역방향 표본 좌표: 출력 위치에서 이만큼 이동한 입력 픽셀을 가져온다.
      final offset = (x: projected.x - target.x, y: projected.y - target.y);
      if (offset.x.abs() > 10 || offset.y.abs() > 35) continue;
      points.add(target);
      offsets.add(offset);
    }
    final selected = <int>[];
    for (var i = 0; i < points.length; i++) {
      var support = 0;
      for (var j = 0; j < points.length; j++) {
        final dx = (points[i].x - points[j].x).abs();
        final dy = (points[i].y - points[j].y).abs();
        if (dx > 150 || dy > 180) continue;
        if ((offsets[i].x - offsets[j].x).abs() <= 4 &&
            (offsets[i].y - offsets[j].y).abs() <= 8 + dx * .12 + dy * .1) {
          support++;
        }
      }
      if (support >= 3) selected.add(i);
    }
    if (selected.length < 20) return null;
    final alignment = ReceiptStitchAlignment._(
      [for (final i in selected) points[i]],
      [for (final i in selected) offsets[i]],
    );
    return alignment;
  }

  /// [OCR 추가] 대응점의 35% 이상을 주변 점으로 보정해 설명할 수 있는지 검증한다.
  /// 자기 자신을 제외한 예측 오차를 검사해 각 점을 그대로 따라 맞추는 과적합을 막는다.
  bool hasReliableSupport({
    required int matchCount,
    required int shorterHeight,
  }) {
    if (matchCount < points.length ||
        matchCount <= 0 ||
        points.length / matchCount < .35 ||
        !hasReceiptStitchPointSpread(points, shorterHeight: shorterHeight)) {
      return false;
    }
    final errors = <double>[];
    for (var i = 0; i < points.length; i++) {
      final expected = _offsetAt(points[i].x, points[i].y, excludedIndex: i);
      errors.add(
        math.sqrt(
          math.pow(offsets[i].x - expected.x, 2) +
              math.pow(offsets[i].y - expected.y, 2),
        ),
      );
    }
    errors.sort();
    return errors[errors.length ~/ 2] <= 2.5;
  }

  /// [OCR 추가] 가까운 여덟 점을 사용한다. 겹침 밖에서는 보정량을 서서히 0으로 줄인다.
  ReceiptStitchPoint offsetAt(double x, double y) => _offsetAt(x, y);

  ReceiptStitchPoint _offsetAt(double x, double y, {int? excludedIndex}) {
    final sampleX = x.clamp(left, right);
    final sampleY = y.clamp(top, bottom);
    final nearest = <({double distance, int index})>[];
    for (var i = 0; i < points.length; i++) {
      if (i == excludedIndex) continue;
      final dx = (sampleX - points[i].x) / 130;
      final dy = (sampleY - points[i].y) / 180;
      nearest.add((distance: dx * dx + dy * dy, index: i));
    }
    nearest.sort((a, b) => a.distance.compareTo(b.distance));
    var weight = 0.0;
    var offsetX = 0.0;
    var offsetY = 0.0;
    for (final item in nearest.take(8)) {
      final currentWeight = 1 / (item.distance + .0025);
      weight += currentWeight;
      offsetX += currentWeight * offsets[item.index].x;
      offsetY += currentWeight * offsets[item.index].y;
    }
    var fade = 1.0;
    if (y < top) fade = (1 - (top - y) / 140).clamp(0.0, 1.0);
    if (y > bottom) fade = (1 - (y - bottom) / 160).clamp(0.0, 1.0);
    return (x: offsetX / weight * fade, y: offsetY / weight * fade);
  }
}

/// [OCR 추가] 겹침 주변의 작은 띠만 보정하고 나머지 사진은 그대로 둔다. 입력 Mat을 수정한다.
void applyReceiptStitchAlignment(
  cv.Mat image,
  ReceiptStitchAlignment alignment, {
  required double scale,
  required double firstOffset,
  bool isMask = false,
}) {
  final start = math.max(0, ((alignment.top - 140) * scale).floor());
  final end = math.min(image.rows, ((alignment.bottom + 160) * scale).ceil());
  if (end <= start) return;
  final rows = end - start;
  final cols = image.cols;
  final mapX = cv.Mat.zeros(rows, cols, cv.MatType.CV_32FC1);
  final mapY = cv.Mat.zeros(rows, cols, cv.MatType.CV_32FC1);
  final border = cv.Scalar.all(isMask ? 0 : 255);
  final rectangle = cv.Rect(0, start, cols, rows);
  cv.Mat? result;
  cv.Mat? area;
  try {
    final rawX = mapX.data;
    final rawY = mapY.data;
    final xs = rawX.buffer.asFloat32List(rawX.offsetInBytes, rows * cols);
    final ys = rawY.buffer.asFloat32List(rawY.offsetInBytes, rows * cols);
    // [OCR 추가] 모든 픽셀에서 대응점을 정렬하지 않도록 격자 보정량을 먼저 구해 보간한다.
    const step = 24;
    final gridWidth = ((cols - 1) / step).ceil() + 1;
    final gridHeight = ((rows - 1) / step).ceil() + 1;
    final grid = List<ReceiptStitchPoint>.generate(gridWidth * gridHeight, (i) {
      final x = math.min(cols - 1, (i % gridWidth) * step).toDouble();
      final y = start + math.min(rows - 1, (i ~/ gridWidth) * step).toDouble();
      return alignment.offsetAt((x - firstOffset) / scale, y / scale);
    });
    // [OCR 추가] 보정 격자가 접히거나 방향을 뒤집으면 글자가 손상되므로 적용하지 않는다.
    for (var gy = 0; gy < gridHeight - 1; gy++) {
      for (var gx = 0; gx < gridWidth - 1; gx++) {
        final x0 = gx * step.toDouble();
        final y0 = gy * step.toDouble();
        final x1 = math.min(cols - 1, (gx + 1) * step).toDouble();
        final y1 = math.min(rows - 1, (gy + 1) * step).toDouble();
        ReceiptStitchPoint mapped(int index, double x, double y) =>
            (x: x + grid[index].x * scale, y: y + grid[index].y * scale);
        final a = mapped(gy * gridWidth + gx, x0, y0);
        final b = mapped(gy * gridWidth + gx + 1, x1, y0);
        final c = mapped((gy + 1) * gridWidth + gx, x0, y1);
        final d = mapped((gy + 1) * gridWidth + gx + 1, x1, y1);
        double cross(
          ReceiptStitchPoint a,
          ReceiptStitchPoint b,
          ReceiptStitchPoint c,
        ) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        final minimumArea = (x1 - x0) * (y1 - y0) * .1;
        if (cross(a, b, c) <= minimumArea || cross(b, d, c) <= minimumArea) {
          throw const FormatException('부분 보정의 변형이 너무 커요. 사진 경계를 다시 확인해주세요.');
        }
      }
    }
    for (var y = 0; y < rows; y++) {
      final gy = math.min(y ~/ step, gridHeight - 2);
      final fy =
          (y - gy * step) / math.max(1, math.min(step, rows - 1 - gy * step));
      for (var x = 0; x < cols; x++) {
        final gx = math.min(x ~/ step, gridWidth - 2);
        final fx =
            (x - gx * step) / math.max(1, math.min(step, cols - 1 - gx * step));
        final a = grid[gy * gridWidth + gx];
        final b = grid[gy * gridWidth + gx + 1];
        final c = grid[(gy + 1) * gridWidth + gx];
        final d = grid[(gy + 1) * gridWidth + gx + 1];
        final dx =
            (a.x * (1 - fx) + b.x * fx) * (1 - fy) +
            (c.x * (1 - fx) + d.x * fx) * fy;
        final dy =
            (a.y * (1 - fx) + b.y * fx) * (1 - fy) +
            (c.y * (1 - fx) + d.y * fx) * fy;
        xs[y * cols + x] = x + dx * scale;
        ys[y * cols + x] = start + y + dy * scale;
      }
    }
    result = cv.remap(
      image,
      mapX,
      mapY,
      isMask ? cv.INTER_NEAREST : cv.INTER_LINEAR,
      borderValue: border,
    );
    area = image.region(rectangle);
    result.copyTo(area);
  } finally {
    area?.dispose();
    result?.dispose();
    rectangle.dispose();
    border.dispose();
    mapX.dispose();
    mapY.dispose();
  }
}

/// [OCR 추가] 최종 출력에서 양쪽 모두 잉크가 없는 한 행을 찾는다. 없으면 null이다.
/// 축소 때 사라진 글자를 공백으로 오인하지 않도록 절단 후보 주변만 원래 해상도로 검사한다.
int? verifyReceiptStitchCut(
  cv.Mat first,
  cv.Mat second, {
  required int center,
  required int left,
  required int right,
}) {
  if (left < 0 ||
      right > math.min(first.cols, second.cols) ||
      right <= left ||
      center < 32 ||
      center + 32 > math.min(first.rows, second.rows)) {
    return null;
  }
  final rectangle = cv.Rect(left, center - 32, right - left, 64);
  final areaA = first.region(rectangle);
  final areaB = second.region(rectangle);
  final grayA = cv.cvtColor(areaA, cv.COLOR_BGR2GRAY);
  final grayB = cv.cvtColor(areaB, cv.COLOR_BGR2GRAY);
  final inkA = cv.adaptiveThreshold(
    grayA,
    255,
    cv.ADAPTIVE_THRESH_MEAN_C,
    cv.THRESH_BINARY_INV,
    31,
    12,
  );
  final inkB = cv.adaptiveThreshold(
    grayB,
    255,
    cv.ADAPTIVE_THRESH_MEAN_C,
    cv.THRESH_BINARY_INV,
    31,
    12,
  );
  try {
    final dataA = inkA.data;
    final dataB = inkB.data;
    final candidates = [for (var y = 26; y <= 38; y++) y]
      ..sort((a, b) => (a - 32).abs().compareTo((b - 32).abs()));
    for (final y in candidates) {
      var empty = true;
      for (var x = 0; x < inkA.cols; x++) {
        if (dataA[y * inkA.cols + x] != 0 || dataB[y * inkB.cols + x] != 0) {
          empty = false;
          break;
        }
      }
      if (empty) return center - 32 + y;
    }
    return null;
  } finally {
    inkA.dispose();
    inkB.dispose();
    grayA.dispose();
    grayB.dispose();
    areaA.dispose();
    areaB.dispose();
    rectangle.dispose();
  }
}
