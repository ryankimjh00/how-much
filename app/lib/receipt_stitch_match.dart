import 'dart:math' as math;

/// [OCR 추가] OCR 좌표와 독립된 사진 정합용 점이다.
typedef ReceiptStitchPoint = ({double x, double y});

/// [OCR 추가] 둘째 사진의 점을 첫째 사진 좌표로 옮긴다. 무한대로 향하는 변환은 거부한다.
ReceiptStitchPoint? projectReceiptStitchPoint(
  List<double> matrix,
  double x,
  double y,
) {
  if (matrix.length != 9 || matrix.any((value) => !value.isFinite)) return null;
  final divisor = matrix[6] * x + matrix[7] * y + matrix[8];
  if (!divisor.isFinite || divisor <= .2) return null;
  final point = (
    x: (matrix[0] * x + matrix[1] * y + matrix[2]) / divisor,
    y: (matrix[3] * x + matrix[4] * y + matrix[5]) / divisor,
  );
  return point.x.isFinite && point.y.isFinite ? point : null;
}

/// [OCR 추가] 뒤집힘·과도한 늘어남·같은 사진의 중복 연결을 출력 이미지 생성 전에 막는다.
List<ReceiptStitchPoint>? validateReceiptStitchProjection(
  List<double> matrix, {
  required int firstWidth,
  required int firstHeight,
  required int secondWidth,
  required int secondHeight,
}) {
  final corners = <ReceiptStitchPoint>[];
  for (final point in [
    (x: 0.0, y: 0.0),
    (x: secondWidth.toDouble(), y: 0.0),
    (x: secondWidth.toDouble(), y: secondHeight.toDouble()),
    (x: 0.0, y: secondHeight.toDouble()),
  ]) {
    final projected = projectReceiptStitchPoint(matrix, point.x, point.y);
    if (projected == null) return null;
    corners.add(projected);
  }
  for (var i = 0; i < 4; i++) {
    final a = corners[i];
    final b = corners[(i + 1) % 4];
    final c = corners[(i + 2) % 4];
    final cross = (b.x - a.x) * (c.y - b.y) - (b.y - a.y) * (c.x - b.x);
    if (cross <= 0) return null;
  }
  final topWidth = corners[1].x - corners[0].x;
  final bottomWidth = corners[2].x - corners[3].x;
  final top = (corners[0].y + corners[1].y) / 2;
  final bottom = (corners[2].y + corners[3].y) / 2;
  final projectedHeight = bottom - top;
  if (topWidth < firstWidth * .6 ||
      topWidth > firstWidth * 1.6 ||
      bottomWidth < firstWidth * .6 ||
      bottomWidth > firstWidth * 1.6 ||
      projectedHeight < secondHeight * .5 ||
      projectedHeight > secondHeight * 1.8 ||
      top < 0 ||
      top >= firstHeight - 30 ||
      bottom < firstHeight + math.max(30, secondHeight * .08)) {
    return null;
  }
  return corners;
}

/// [OCR 추가] 두 사진에 모두 실제 픽셀이 있고, 양쪽 모두 글자 없는 경계만 고른다.
/// 잉크가 많은 줄의 점수를 낮춰 억지로 잘라 붙이지 않는다.
int? findReceiptStitchCut({
  required List<int> firstInk,
  required List<int> secondInk,
  required List<bool> covered,
  required int start,
  required int end,
  required int comparisonWidth,
}) {
  if (firstInk.length != secondInk.length ||
      firstInk.length != covered.length ||
      end <= start) {
    return null;
  }
  final margin = ((end - start) * .2).ceil();
  final limit = math.max(2, (comparisonWidth * .004).floor());
  int? best;
  var bestCost = 1 << 30;
  for (var y = start + margin; y < end - margin; y++) {
    if (y < 2 || y + 2 >= firstInk.length) continue;
    var cost = 0;
    var safe = true;
    for (var row = y - 2; row <= y + 2; row++) {
      if (!covered[row] || firstInk[row] > limit || secondInk[row] > limit) {
        safe = false;
        break;
      }
      cost += firstInk[row] + secondInk[row];
    }
    if (!safe) continue;
    if (cost < bestCost ||
        (cost == bestCost &&
            (y - (start + end) / 2).abs() <
                (best! - (start + end) / 2).abs())) {
      best = y;
      bestCost = cost;
    }
  }
  return best;
}
