import 'package:flutter/foundation.dart';
import 'receipt_stitch_opencv.dart';

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
  // [OCR 수정] 아래쪽부터 붙이되, 특징 대조는 항상 이웃한 원본 두 장으로 한다.
  // 이미 늘어나거나 여백이 생긴 누적 사진을 다시 대조하면 같은 무늬를 놓칠 수 있다.
  Uint8List? joined;
  var originX = 0;
  for (var i = photos.length - 2; i >= 0; i--) {
    if (!isCurrent()) return null;
    final result = await compute(stitchReceiptStep, (
      first: photos[i],
      second: photos[i + 1],
      tail: joined,
      tailOriginX: originX,
    ));
    if (!isCurrent()) return null;
    joined = result.bytes;
    originX = result.originX;
  }
  return joined;
}
