import 'dart:math' as math;
import 'receipt_stitch_alignment.dart';
import 'receipt_stitch_match.dart';

/// [OCR 추가] 인접 원본 두 장의 정합·절단 결과다. 네이티브 포인터를 포함하지 않아 isolate로 전달할 수 있다.
class ReceiptStitchPairPlan {
  const ReceiptStitchPairPlan({
    required this.matrix,
    required this.inverse,
    required this.alignment,
    required this.firstHeight,
    required this.secondHeight,
    required this.cutY,
    required this.bodyScale,
    required this.bodyTranslateX,
    required this.checkLeft,
    required this.checkRight,
    required this.corners,
  });
  final List<double> matrix;
  final List<double> inverse;
  final ReceiptStitchAlignment? alignment;
  final int firstHeight;
  final int secondHeight;
  final int cutY;
  final double bodyScale;
  final double bodyTranslateX;
  final double checkLeft;
  final double checkRight;
  final List<ReceiptStitchPoint> corners;

  /// [OCR 추가] 첫 사진 좌표에서 실제로 읽을 둘째 사진의 위치를 반환한다. 단위는 너비1600px 기준이다.
  ReceiptStitchPoint? secondSourceAt(double x, double y) {
    final shift = alignment?.offsetAt(x / 1.6, y / 1.6) ?? (x: 0.0, y: 0.0);
    final point = projectReceiptStitchPoint(
      inverse,
      x / 1.6 + shift.x,
      y / 1.6 + shift.y,
    );
    if (point == null) return null;
    return (x: point.x * 1.6, y: point.y * 1.6);
  }
}

/// [OCR 추가] 사진 한 장의 일정한 본문 배율과 연결부 변형을 분리한 배치다.
class ReceiptStitchPlacement {
  ReceiptStitchPlacement({
    required this.scale,
    required this.x,
    required this.y,
    required this.height,
    required this.start,
    this.incoming,
    this.previous,
  });
  final double scale;
  final double x;
  final double y;
  final int height;
  final double start;
  final ReceiptStitchPairPlan? incoming;
  final ReceiptStitchPlacement? previous;
  late final double end;
  late final double transitionHeight;

  /// [OCR 추가] 연결 경계에서는 정확한 원근 정합을 사용하고, 본문으로 갈수록 일정 배율로 돌아온다.
  ReceiptStitchPoint? sourceAt(double canvasX, double canvasY) {
    final body = (x: (canvasX - x) / scale, y: (canvasY - y) / scale);
    if (incoming == null || canvasY >= start + transitionHeight) return body;
    final reference = previous!;
    final aligned = incoming!.secondSourceAt(
      (canvasX - reference.x) / reference.scale,
      (canvasY - reference.y) / reference.scale,
    );
    if (aligned == null) return null;
    final distance = ((canvasY - start) / transitionHeight).clamp(0.0, 1.0);
    // 양 끝의 기울기가0인 보간으로 변형이 갑자기 꺾이는 경계를 만들지 않는다.
    final blend = distance * distance * (3 - 2 * distance);
    return (
      x: aligned.x * (1 - blend) + body.x * blend,
      y: aligned.y * (1 - blend) + body.y * blend,
    );
  }
}

/// [OCR 추가] 모든 사진의 좌표를 먼저 계산한다. 누적 이미지의 픽셀을 다시 변형하지 않는다.
class ReceiptStitchLayout {
  ReceiptStitchLayout(List<ReceiptStitchPairPlan> plans) {
    if (plans.isEmpty || plans.length > 9) {
      throw const FormatException('사진 연결 정보를 확인해주세요.');
    }
    photos.add(
      ReceiptStitchPlacement(
        scale: 1,
        x: 0,
        y: 0,
        height: plans.first.firstHeight,
        start: 0,
      ),
    );
    var left = 0.0;
    var right = 1600.0;
    for (final plan in plans) {
      final previous = photos.last;
      final cut = previous.y + previous.scale * plan.cutY;
      if (cut - previous.start < 64 || previous.height != plan.firstHeight) {
        throw const FormatException('사진의 연결 순서나 겹침 범위를 확인해주세요.');
      }
      previous.end = cut;
      previous.transitionHeight = math.min(
        240 * previous.scale,
        (cut - previous.start) * .45,
      );
      final source = plan.secondSourceAt(800, plan.cutY.toDouble());
      if (source == null || source.y < 0 || source.y >= plan.secondHeight) {
        throw const FormatException('연결 위치가 사진 안에 있는지 확인해주세요.');
      }
      final scale = previous.scale * plan.bodyScale;
      final photo = ReceiptStitchPlacement(
        scale: scale,
        x: previous.x + previous.scale * plan.bodyTranslateX,
        y: cut - scale * source.y,
        height: plan.secondHeight,
        start: cut,
        incoming: plan,
        previous: previous,
      );
      photos.add(photo);
      left = math.min(left, photo.x);
      right = math.max(right, photo.x + 1600 * scale);
      // 연결부가 본문보다 좌우로 넓어지는 경우에도 종이와 글자를 자르지 않는다.
      for (final point in plan.corners) {
        left = math.min(left, previous.x + previous.scale * point.x * 1.6);
        right = math.max(right, previous.x + previous.scale * point.x * 1.6);
      }
    }
    final last = photos.last;
    last.end = last.y + last.height * last.scale;
    if (last.end - last.start < 64) {
      throw const FormatException('마지막 사진의 추가 영역이 너무 작아요.');
    }
    last.transitionHeight = math.min(
      240 * last.scale,
      (last.end - last.start) * .45,
    );
    offsetX = -left.floor();
    width = right.ceil() + offsetX;
    height = last.end.ceil();
    if (width > 2600 || height > 16000 || width * height > 24000000) {
      throw const FormatException('이어붙일 사진이 너무 커요. 장별로 인식해주세요.');
    }
  }
  final List<ReceiptStitchPlacement> photos = [];
  late final int offsetX;
  late final int width;
  late final int height;
}
