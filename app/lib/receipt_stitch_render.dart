import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dartcv4/dartcv.dart' as cv;
import 'receipt_stitch_alignment.dart';
import 'receipt_stitch_layout.dart';
import 'receipt_stitch_match.dart';
import 'receipt_stitch_opencv.dart';

/// [OCR 추가] 원본별 배치를 먼저 확정한 뒤 사진마다 한 번 렌더링한다. 입력 파일과 목록은 수정하지 않는다.
Uint8List renderReceiptStitch(
  ({List<Uint8List> photos, List<ReceiptStitchPairPlan> plans}) input,
) {
  if (input.photos.length != input.plans.length + 1) {
    throw const FormatException('사진과 연결 정보의 개수가 달라요.');
  }
  final layout = ReceiptStitchLayout(input.plans);
  final white = cv.Scalar.all(255);
  final canvas = cv.Mat.fromScalar(
    layout.height,
    layout.width,
    cv.MatType.CV_8UC3,
    white,
  );
  cv.Mat? current;
  cv.Mat? next;
  try {
    current = decodeReceiptStitchPhoto(input.photos.first);
    var start = 0;
    for (var i = 0; i < input.photos.length; i++) {
      var end = layout.height;
      if (i + 1 < input.photos.length) {
        next = decodeReceiptStitchPhoto(input.photos[i + 1]);
        end = _verifiedCut(current!, next, layout, i);
      }
      if (end <= start) throw const FormatException('사진 연결 경계가 서로 교차해요.');
      final strip = _renderStrip(
        current!,
        layout.photos[i],
        layout,
        start,
        end,
      );
      final rectangle = cv.Rect(0, start, layout.width, end - start);
      cv.Mat? destination;
      try {
        destination = canvas.region(rectangle);
        // [OCR 추가] 경계 위·아래에서 한 사진의 픽셀만 쓴다. 글자를 섞어 뭉개지 않는다.
        strip.copyTo(destination);
      } finally {
        destination?.dispose();
        rectangle.dispose();
        strip.dispose();
      }
      start = end;
      current.dispose();
      current = next;
      next = null;
    }
    final (success, bytes) = cv.imencode('.png', canvas);
    if (!success) throw const FormatException('이어붙인 사진을 만들지 못했어요.');
    return bytes;
  } finally {
    next?.dispose();
    current?.dispose();
    canvas.dispose();
    white.dispose();
  }
}

// [OCR 추가] 실제 출력 배율에서 두 사진이 모두 빈 행을 확인한다. 축소 비교의 공백만 믿지 않는다.
int _verifiedCut(
  cv.Mat first,
  cv.Mat second,
  ReceiptStitchLayout layout,
  int index,
) {
  final previous = layout.photos[index];
  final incoming = layout.photos[index + 1];
  final plan = incoming.incoming!;
  final center = incoming.start.ceil();
  final top = center - 32;
  final a = _renderStrip(first, previous, layout, top, center + 32);
  cv.Mat? b;
  try {
    b = _renderStrip(second, incoming, layout, top, center + 32);
    final cut = verifyReceiptStitchCut(
      a,
      b,
      center: 32,
      left:
          (previous.x + previous.scale * plan.checkLeft + layout.offsetX)
              .ceil() +
          2,
      right:
          (previous.x + previous.scale * plan.checkRight + layout.offsetX)
              .floor() -
          2,
    );
    if (cut == null) {
      throw const FormatException('출력 사진에서 글자를 자르지 않을 공백을 찾지 못했어요.');
    }
    return top + cut;
  } finally {
    b?.dispose();
    a.dispose();
  }
}

// [OCR 추가] 필요한 띠만 원본에서 읽는다. 긴 누적 이미지를 다시 입력으로 사용하지 않는다.
cv.Mat _renderStrip(
  cv.Mat source,
  ReceiptStitchPlacement photo,
  ReceiptStitchLayout layout,
  int start,
  int end,
) {
  final rows = end - start;
  final cols = layout.width;
  if (rows < 2 || start < 0) throw const FormatException('사진의 출력 영역을 확인해주세요.');
  final mapX = cv.Mat.zeros(rows, cols, cv.MatType.CV_32FC1);
  final mapY = cv.Mat.zeros(rows, cols, cv.MatType.CV_32FC1);
  final white = cv.Scalar.all(255);
  try {
    // 작은 격자에서 역변환을 구해 보간한다. 픽셀마다 주변 대응점을 다시 정렬하지 않는다.
    const step = 24;
    final gridWidth = ((cols - 1) / step).ceil() + 1;
    final gridHeight = ((rows - 1) / step).ceil() + 1;
    final grid = List<ReceiptStitchPoint>.generate(gridWidth * gridHeight, (
      index,
    ) {
      final x = math.min(cols - 1, (index % gridWidth) * step) - layout.offsetX;
      final y = start + math.min(rows - 1, (index ~/ gridWidth) * step);
      final point = photo.sourceAt(x.toDouble(), y.toDouble());
      if (point == null || !point.x.isFinite || !point.y.isFinite) {
        throw const FormatException('연결부의 좌표를 확인하지 못했어요.');
      }
      return point;
    });
    // [OCR 추가] 보정을 본문 배율로 되돌리는 과정에서 격자가 접히면 연결을 거부한다.
    for (var gy = 0; gy < gridHeight - 1; gy++) {
      for (var gx = 0; gx < gridWidth - 1; gx++) {
        final a = grid[gy * gridWidth + gx], b = grid[gy * gridWidth + gx + 1];
        final c = grid[(gy + 1) * gridWidth + gx],
            d = grid[(gy + 1) * gridWidth + gx + 1];
        double cross(
          ReceiptStitchPoint a,
          ReceiptStitchPoint b,
          ReceiptStitchPoint c,
        ) => (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
        final cellWidth = math.min(step, cols - 1 - gx * step);
        final cellHeight = math.min(step, rows - 1 - gy * step);
        final minimumArea =
            cellWidth * cellHeight / (photo.scale * photo.scale) * .1;
        if (cross(a, b, c) <= minimumArea || cross(b, d, c) <= minimumArea) {
          throw const FormatException('연결부 변형이 너무 커요. 사진 경계를 다시 확인해주세요.');
        }
      }
    }
    final rawX = mapX.data, rawY = mapY.data;
    final xs = rawX.buffer.asFloat32List(rawX.offsetInBytes, rows * cols);
    final ys = rawY.buffer.asFloat32List(rawY.offsetInBytes, rows * cols);
    for (var y = 0; y < rows; y++) {
      final gy = math.min(y ~/ step, gridHeight - 2);
      final fy = (y - gy * step) / math.min(step, rows - 1 - gy * step);
      for (var x = 0; x < cols; x++) {
        final gx = math.min(x ~/ step, gridWidth - 2);
        final fx = (x - gx * step) / math.min(step, cols - 1 - gx * step);
        final a = grid[gy * gridWidth + gx], b = grid[gy * gridWidth + gx + 1];
        final c = grid[(gy + 1) * gridWidth + gx],
            d = grid[(gy + 1) * gridWidth + gx + 1];
        xs[y * cols + x] =
            (a.x * (1 - fx) + b.x * fx) * (1 - fy) +
            (c.x * (1 - fx) + d.x * fx) * fy;
        ys[y * cols + x] =
            (a.y * (1 - fx) + b.y * fx) * (1 - fy) +
            (c.y * (1 - fx) + d.y * fx) * fy;
      }
    }
    return cv.remap(source, mapX, mapY, cv.INTER_LINEAR, borderValue: white);
  } finally {
    mapX.dispose();
    mapY.dispose();
    white.dispose();
  }
}
