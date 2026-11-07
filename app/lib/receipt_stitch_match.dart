import 'dart:math' as math;

/// [OCR 추가] OCR 좌표와 독립된 사진 정합용 점이다.
typedef ReceiptStitchPoint = ({double x, double y});

/// [OCR 수정] 비교 영상에서 일치점의 가로 300px·세로 8% 분포를 확인한다.
/// points와 shorterHeight는 너비 1000px로 맞춘 비교 영상 좌표를 사용한다.
bool hasReceiptStitchPointSpread(
  List<ReceiptStitchPoint> points, {
  required int shorterHeight,
}) {
  if (points.length < 2 || shorterHeight <= 0) return false;
  final xs = points.map((point) => point.x);
  final ys = points.map((point) => point.y);
  if (points.any((point) => !point.x.isFinite || !point.y.isFinite)) {
    return false;
  }
  // 영수증의 좁은 겹침에서도 분포를 인정하되 한 행 부근에 몰린 점은 계속 거부한다.
  return xs.reduce(math.max) - xs.reduce(math.min) >= 300 &&
      ys.reduce(math.max) - ys.reduce(math.min) >= shorterHeight * .08;
}

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

/// [OCR 수정] 같은 행에서 두 사진이 실제로 겹치는 범위를 반환한다.
/// start/end는 마스크 배열의 행 구간이며 end는 포함하지 않는다. 사진 밖 여백은 검사하지 않는다.
({int start, int end})? findReceiptStitchOverlap(
  List<int> coverage, {
  required int start,
  required int end,
  required int minimumWidth,
}) {
  if (start < 0 || end > coverage.length || start >= end || minimumWidth <= 0) {
    return null;
  }
  while (start < end && coverage[start] == 0) {
    start++;
  }
  while (end > start && coverage[end - 1] == 0) {
    end--;
  }
  // 영상 테두리의 보간·밝기 경계를 글자로 판단하지 않도록 공통 영역의 가장자리만 제외한다.
  final inset = math.max(8, ((end - start) * .05).ceil());
  start += inset;
  end -= inset;
  if (end - start < minimumWidth) return null;
  for (var index = start; index < end; index++) {
    if (coverage[index] == 0) return null;
  }
  return (start: start, end: end);
}

/// [OCR 수정] 두 사진의 실제 겹침에서 양쪽 모두 한 행이 비어 있는 경계를 고른다.
/// 잉크가 많은 줄의 점수를 낮춰 억지로 잘라 붙이지 않는다. 행별 비교 폭을 넘기면 잉크 한도도 그 폭에 맞춘다.
int? findReceiptStitchCut({
  required List<int> firstInk,
  required List<int> secondInk,
  required List<bool> covered,
  required int start,
  required int end,
  required int comparisonWidth,
  List<int>? comparisonWidths,
}) {
  if (firstInk.length != secondInk.length ||
      firstInk.length != covered.length ||
      end <= start ||
      (comparisonWidths != null &&
          comparisonWidths.length != firstInk.length)) {
    return null;
  }
  final margin = ((end - start) * .2).ceil();
  int? best;
  var bestCost = 1 << 30;
  for (var y = start + margin; y < end - margin; y++) {
    if (y < 0 || y >= firstInk.length) continue;
    // [OCR 수정] 글자 사이 한 행으로 절단할 수 있으므로 앞뒤 행까지 비도록 요구하지 않는다.
    // 행별 실제 비교 폭에 맞춘 작은 잡음 허용량과 양쪽의 픽셀 존재 검사는 유지한다.
    final width = comparisonWidths?[y] ?? comparisonWidth;
    final limit = math.max(2, (width * .004).floor());
    if (width <= 0 ||
        !covered[y] ||
        firstInk[y] > limit ||
        secondInk[y] > limit) {
      continue;
    }
    final cost = firstInk[y] + secondInk[y];
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
