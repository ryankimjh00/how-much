import 'package:flutter/foundation.dart';
import 'receipt_stitch_opencv.dart';
import 'receipt_stitch_layout.dart';
import 'receipt_stitch_render.dart';

/// [OCR 추가] 보정한 사진을 촬영 순서로 연결한다. 원본 목록과 파일은 변경하지 않는다.
/// 무거운 정합은 별도 isolate에서 실행하며, 취소·계정 변경 후의 결과는 반환하지 않는다.
Future<Uint8List?> stitchReceiptPhotos(
  List<Uint8List> photos, {
  required bool Function() isCurrent,
}) async {
  if (photos.length < 2 || photos.length > 10) {
    throw const FormatException('이어붙일 사진을 2~10장 선택해주세요.');
  }
  if (!isCurrent()) return null;
  // [OCR 수정] 먼저 원본 인접 쌍의 좌표를 구하고, 원본마다 한 번 렌더링해 합친다.
  // 이미 연결한 긴 사진을 다시 원근변환하지 않아 하단의 폭이 누적해서 줄지 않는다.
  final plans = <ReceiptStitchPairPlan>[];
  for (var i = 0; i < photos.length - 1; i++) {
    if (!isCurrent()) return null;
    final plan = await compute(planReceiptStitchPair, (
      first: photos[i],
      second: photos[i + 1],
    ));
    if (!isCurrent()) return null;
    plans.add(plan);
  }
  if (!isCurrent()) return null;
  final joined = await compute(renderReceiptStitch, (
    photos: photos,
    plans: plans,
  ));
  return isCurrent() ? joined : null;
}
