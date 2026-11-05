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
  var joined = photos.first;
  for (var i = 1; i < photos.length; i++) {
    if (!isCurrent()) return null;
    final result = await compute(stitchReceiptPhotoPair, (
      first: joined,
      second: photos[i],
    ));
    if (!isCurrent()) return null;
    joined = result;
  }
  return joined;
}
