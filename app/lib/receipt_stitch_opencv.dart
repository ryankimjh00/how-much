import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dartcv4/dartcv.dart' as cv;
import 'receipt_stitch_match.dart';
import 'receipt_stitch_alignment.dart';

const _featureWidth = 1000;
const _outputWidth = 1600;

/// [OCR 추가] 원본 인접 사진 두 장과, 둘째 사진부터 이미 연결한 결과를 전달한다.
/// tailOriginX는 tail 안에 보존된 둘째 원본의 가로 원점이며 세로 원점은 항상 0이다.
typedef ReceiptStitchInput = ({
  Uint8List first,
  Uint8List second,
  Uint8List? tail,
  int tailOriginX,
});

/// [OCR 수정] 원본 쌍의 대응 좌표로 다음 연결 결과를 배치한다. 원본 파일은 변경하지 않는다.
/// 별도 isolate에서 호출하며, 사진과 가로 원점을 함께 반환해 다음 단계의 좌표를 보존한다.
({Uint8List bytes, int originX}) stitchReceiptStep(ReceiptStitchInput photos) {
  try {
    return _stitchReceiptStep(photos, useAkaze: true);
  } on FormatException {
    // [OCR 추가] AKAZE로 정합·공백 검증에 실패하면 기존 SIFT로 한 번 더 시도한다.
    // 두 방식 모두 검증에 실패하면 사진을 억지로 연결하지 않고 호출 화면에 실패를 알린다.
    return _stitchReceiptStep(photos, useAkaze: false);
  }
}

({Uint8List bytes, int originX}) _stitchReceiptStep(
  ReceiptStitchInput photos, {
  required bool useAkaze,
}) {
  final releases = <void Function()>[];
  T own<T extends cv.CvObject>(T resource) {
    releases.add(resource.dispose);
    return resource;
  }

  try {
    final first = own(_decodeReceipt(photos.first));
    final second = own(_decodeReceipt(photos.second));
    final a = own(
      cv.resize(first, (
        _featureWidth,
        (first.rows * _featureWidth / first.cols).round(),
      )),
    );
    final b = own(
      cv.resize(second, (
        _featureWidth,
        (second.rows * _featureWidth / second.cols).round(),
      )),
    );
    final grayA = own(cv.cvtColor(a, cv.COLOR_BGR2GRAY));
    final grayB = own(cv.cvtColor(b, cv.COLOR_BGR2GRAY));
    final white = own(cv.Scalar.all(255));
    final maskA = own(cv.Mat.zeros(a.rows, a.cols, cv.MatType.CV_8UC1));
    final maskB = own(cv.Mat.zeros(b.rows, b.cols, cv.MatType.CV_8UC1));
    // [OCR 수정] 연결 결과가 아닌 인접 원본의 아래·위 부분을 대조한다. 종이 밖 배경은 제외한다.
    final firstStart = math.max(0, a.rows - (b.rows * 1.2).ceil());
    final firstArea = own(cv.Rect(60, firstStart, 880, a.rows - firstStart));
    final secondArea = own(cv.Rect(60, 0, 880, (b.rows * .8).round()));
    own(maskA.region(firstArea)).setTo(white);
    own(maskB.region(secondArea)).setTo(white);
    late final (cv.VecKeyPoint, cv.Mat) featuresA;
    late final (cv.VecKeyPoint, cv.Mat) featuresB;
    if (useAkaze) {
      final detector = own(cv.AKAZE.empty());
      featuresA = detector.detectAndCompute(grayA, maskA);
      featuresB = detector.detectAndCompute(grayB, maskB);
    } else {
      final detector = own(cv.SIFT.create(nfeatures: 4000));
      featuresA = detector.detectAndCompute(grayA, maskA);
      featuresB = detector.detectAndCompute(grayB, maskB);
    }
    final (keyA, descriptorA) = featuresA;
    final (keyB, descriptorB) = featuresB;
    releases.add(keyA.dispose);
    own(descriptorA);
    releases.add(keyB.dispose);
    own(descriptorB);
    if (descriptorA.rows < 2 || descriptorB.rows < 2) {
      throw const FormatException(
        '겹치는 글자 무늬를 충분히 찾지 못했어요. 더 겹쳐 촬영하거나 장별로 인식해주세요.',
      );
    }
    final matcher = own(
      cv.BFMatcher.create(type: useAkaze ? cv.NORM_HAMMING : cv.NORM_L2),
    );
    final forward = matcher.knnMatch(descriptorB, descriptorA, 2);
    releases.add(forward.dispose);
    final reverse = matcher.knnMatch(descriptorA, descriptorB, 2);
    releases.add(reverse.dispose);
    final reversePairs = <(int, int)>{};
    for (var i = 0; i < reverse.length; i++) {
      final row = reverse[i];
      if (row.length < 2) continue;
      final best = own(row[0]);
      final next = own(row[1]);
      if (best.distance < .70 * next.distance) {
        reversePairs.add((best.queryIdx, best.trainIdx));
      }
    }
    final pointsA = <ReceiptStitchPoint>[];
    final pointsB = <ReceiptStitchPoint>[];
    for (var i = 0; i < forward.length; i++) {
      final row = forward[i];
      if (row.length < 2) continue;
      final best = own(row[0]);
      final next = own(row[1]);
      if (best.distance >= .70 * next.distance ||
          !reversePairs.contains((best.trainIdx, best.queryIdx))) {
        continue;
      }
      final pa = own(keyA[best.trainIdx]);
      final pb = own(keyB[best.queryIdx]);
      pointsA.add((x: pa.x, y: pa.y));
      pointsB.add((x: pb.x, y: pb.y));
    }
    if (pointsA.length < 20) {
      throw const FormatException(
        '서로 대응하는 글자 무늬가 부족해요. 사진 순서와 겹치는 부분을 확인해주세요.',
      );
    }
    final source = own(
      cv.Mat.fromList(pointsB.length, 1, cv.MatType.CV_64FC2, [
        for (final p in pointsB) ...[p.x, p.y],
      ]),
    );
    final destination = own(
      cv.Mat.fromList(pointsA.length, 1, cv.MatType.CV_64FC2, [
        for (final p in pointsA) ...[p.x, p.y],
      ]),
    );
    final inlierMask = own(cv.Mat.empty());
    final homography = own(
      cv.findHomography(
        source,
        destination,
        method: cv.RANSAC,
        mask: inlierMask,
        ransacReprojThreshold: 3,
        maxIters: 4000,
      ),
    );
    if (homography.isEmpty || inlierMask.isEmpty) {
      throw const FormatException(
        '사진 사이의 각도 차이를 맞추지 못했어요. 종이 경계를 다시 조정하거나 장별로 인식해주세요.',
      );
    }
    final matrix = [
      for (var row = 0; row < 3; row++)
        for (var column = 0; column < 3; column++)
          homography.at<double>(row, column),
    ];
    final inliers = [
      for (var i = 0; i < pointsA.length; i++)
        if (inlierMask.data[i] != 0) i,
    ];
    // [OCR 수정] 최소 정합 근거가 있으면 부분 보정의 지지를 먼저 구한다.
    // 전체 변환의 비율이 부족하다는 이유만으로 보정 가능한 사진을 미리 거부하지 않는다.
    ReceiptStitchAlignment? alignment;
    if (inliers.length >= 20) {
      alignment = ReceiptStitchAlignment.fromMatches(matrix, pointsA, pointsB);
    }
    if (!_validInliers(
      matrix,
      pointsA,
      pointsB,
      inliers,
      math.min(a.rows, b.rows),
      alignment: alignment,
    )) {
      throw const FormatException('겹침의 위치가 불확실해요. 사진 경계를 확인하거나 장별로 인식해주세요.');
    }
    final corners = validateReceiptStitchProjection(
      matrix,
      firstWidth: a.cols,
      firstHeight: a.rows,
      secondWidth: b.cols,
      secondHeight: b.rows,
    );
    if (corners == null) {
      throw const FormatException('사진이 뒤집히거나 중복된 것으로 보여요. 위에서 아래 순서인지 확인해주세요.');
    }
    // [OCR 수정] 정합과 절단 위치는 원본 쌍에서 구하고 출력 범위는 누적 사진까지 포함한다.
    // 누적 사진 안의 둘째 원본은 너비 1600px·세로 원점 0을 유지한다.
    cv.Mat? tail;
    var extentCorners = corners;
    if (photos.tail != null) {
      tail = own(cv.imdecode(photos.tail!, cv.IMREAD_COLOR));
      if (tail.isEmpty ||
          photos.tailOriginX < 0 ||
          photos.tailOriginX + _outputWidth > tail.cols ||
          tail.rows < second.rows ||
          tail.rows > 16000 ||
          tail.cols * tail.rows > 24000000) {
        throw const FormatException('이전 연결 사진의 좌표를 확인하지 못했어요.');
      }
      extentCorners = <ReceiptStitchPoint>[];
      for (final point in [
        (x: 0.0, y: 0.0),
        (x: tail.cols.toDouble(), y: 0.0),
        (x: tail.cols.toDouble(), y: tail.rows.toDouble()),
        (x: 0.0, y: tail.rows.toDouble()),
      ]) {
        final projected = projectReceiptStitchPoint(
          matrix,
          (point.x - photos.tailOriginX) * _featureWidth / _outputWidth,
          point.y * _featureWidth / _outputWidth,
        );
        if (projected == null) {
          throw const FormatException('이어붙일 사진의 원근 변화가 너무 커요.');
        }
        extentCorners.add(projected);
      }
    }
    final left = math
        .min(0, extentCorners.map((p) => p.x).reduce(math.min))
        .floor();
    final right = math
        .max(a.cols.toDouble(), extentCorners.map((p) => p.x).reduce(math.max))
        .ceil();
    final bottom = math
        .max(a.rows.toDouble(), extentCorners.map((p) => p.y).reduce(math.max))
        .ceil();
    const scale = _outputWidth / _featureWidth;
    final offset = (-left * scale).ceil();
    final width = (right * scale).ceil() + offset;
    final height = (bottom * scale).ceil();
    if (height > 16000 || width * height > 24000000 || width > 2600) {
      throw const FormatException('이어붙일 사진이 너무 커요. 촬영 완료로 장별 인식해주세요.');
    }
    // 공백 탐색은 작은 영상에서 한다. 대비 변환은 탐색에만 쓰고 저장·OCR 사진에는 적용하지 않는다.
    final shiftSmall = own(
      cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, [
        1.0,
        0.0,
        -left.toDouble(),
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ]),
    );
    final shiftedMatrix = List<double>.of(matrix);
    for (var column = 0; column < 3; column++) {
      shiftedMatrix[column] -= left * matrix[6 + column];
    }
    final shifted = own(
      cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, shiftedMatrix),
    );
    final smallA = own(
      cv.warpPerspective(grayA, shiftSmall, (
        right - left,
        bottom,
      ), borderValue: white),
    );
    final smallB = own(
      cv.warpPerspective(grayB, shifted, (
        right - left,
        bottom,
      ), borderValue: white),
    );
    final fullBMask = own(
      cv.Mat.fromScalar(b.rows, b.cols, cv.MatType.CV_8UC1, white),
    );
    final coverage = own(
      cv.warpPerspective(fullBMask, shifted, (
        right - left,
        bottom,
      ), flags: cv.INTER_NEAREST),
    );
    // [OCR 추가] 전체 원근변환 뒤에도 남는 작은 오차만 주변 대응점의 지지로 보정한다.
    // 그림은 흰색, 픽셀 존재 마스크는 검정색으로 채워 사진 밖을 공백으로 오인하지 않는다.
    if (alignment != null) {
      applyReceiptStitchAlignment(
        smallB,
        alignment,
        scale: 1,
        firstOffset: -left.toDouble(),
      );
      applyReceiptStitchAlignment(
        coverage,
        alignment,
        scale: 1,
        firstOffset: -left.toDouble(),
        isMask: true,
      );
    }
    final inkA = own(
      cv.adaptiveThreshold(
        smallA,
        255,
        cv.ADAPTIVE_THRESH_MEAN_C,
        cv.THRESH_BINARY_INV,
        31,
        12,
      ),
    );
    final inkB = own(
      cv.adaptiveThreshold(
        smallB,
        255,
        cv.ADAPTIVE_THRESH_MEAN_C,
        cv.THRESH_BINARY_INV,
        31,
        12,
      ),
    );
    final rowsA = List<int>.filled(bottom, 0);
    final rowsB = List<int>.filled(bottom, 0);
    final covered = List<bool>.filled(bottom, false);
    final dataA = inkA.data;
    final dataB = inkB.data;
    final dataMask = coverage.data;
    final comparisonWidths = List<int>.filled(bottom, 0);
    for (var y = 0; y < a.rows; y++) {
      final rowStart = y * inkA.cols;
      // [OCR 수정] 누적 캔버스 폭을 새 사진이 전부 덮을 필요는 없다.
      // 첫 사진 안쪽에서 실제로 겹치는 구간만 검사해 흰 여백·사진 외곽이 공백 선택을 막지 않게 한다.
      final overlap = findReceiptStitchOverlap(
        dataMask,
        start: rowStart - left,
        end: rowStart + a.cols - left,
        minimumWidth: (a.cols * .3).ceil(),
      );
      if (overlap == null) continue;
      for (var index = overlap.start; index < overlap.end; index++) {
        if (dataA[index] != 0) rowsA[y]++;
        if (dataB[index] != 0) rowsB[y]++;
      }
      covered[y] = true;
      comparisonWidths[y] = overlap.end - overlap.start;
    }
    final start = math.max(0, math.max(corners[0].y, corners[1].y).ceil());
    final end = math.min(a.rows, math.min(corners[2].y, corners[3].y).floor());
    final cut = findReceiptStitchCut(
      firstInk: rowsA,
      secondInk: rowsB,
      covered: covered,
      start: start,
      end: end,
      comparisonWidth: a.cols,
      comparisonWidths: comparisonWidths,
    );
    if (cut == null) {
      throw const FormatException('글자를 자르지 않고 연결할 공백을 찾지 못했어요. 장별로 인식해주세요.');
    }
    final outputMatrix = [
      matrix[0] + offset * matrix[6] / scale,
      matrix[1] + offset * matrix[7] / scale,
      scale * matrix[2] + offset * matrix[8],
      matrix[3],
      matrix[4],
      scale * matrix[5],
      matrix[6] / scale,
      matrix[7] / scale,
      matrix[8],
    ];
    if (tail != null) {
      // [OCR 수정] 누적 사진의 가로 여백을 빼서 원본 둘째 사진 좌표로 되돌린다.
      outputMatrix[2] -= outputMatrix[0] * photos.tailOriginX;
      outputMatrix[5] -= outputMatrix[3] * photos.tailOriginX;
      outputMatrix[8] -= outputMatrix[6] * photos.tailOriginX;
    }
    final transformB = own(
      cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, outputMatrix),
    );
    final transformA = own(
      cv.Mat.fromList(3, 3, cv.MatType.CV_64FC1, [
        1.0,
        0.0,
        offset.toDouble(),
        0.0,
        1.0,
        0.0,
        0.0,
        0.0,
        1.0,
      ]),
    );
    final joined = own(
      cv.warpPerspective(first, transformA, (
        width,
        height,
      ), borderValue: white),
    );
    final warped = own(
      cv.warpPerspective(tail ?? second, transformB, (
        width,
        height,
      ), borderValue: white),
    );
    if (alignment != null) {
      applyReceiptStitchAlignment(
        warped,
        alignment,
        scale: scale,
        firstOffset: offset.toDouble(),
      );
    }
    final overlap = findReceiptStitchOverlap(
      dataMask,
      start: cut * inkA.cols - left,
      end: cut * inkA.cols + a.cols - left,
      minimumWidth: (a.cols * .3).ceil(),
    )!;
    // [OCR 추가] 축소 영상에서 고른 경계는 출력 해상도에서도 빈 한 행인지 다시 확인한다.
    final cutY = verifyReceiptStitchCut(
      joined,
      warped,
      center: (cut * scale).round(),
      left:
          ((overlap.start - cut * inkA.cols + left) * scale + offset).ceil() +
          2,
      right:
          ((overlap.end - cut * inkA.cols + left) * scale + offset).floor() - 2,
    );
    if (cutY == null) {
      throw const FormatException('글자를 자르지 않을 공백을 출력 사진에서 확인하지 못했어요.');
    }
    final lowerArea = own(cv.Rect(0, cutY, width, height - cutY));
    final lowerSource = own(warped.region(lowerArea));
    final lowerDestination = own(joined.region(lowerArea));
    // 한쪽 사진만 복사한다. 겹친 글자를 혼합하지 않는다.
    lowerSource.copyTo(lowerDestination);
    final (success, bytes) = cv.imencode('.png', joined);
    if (!success) throw const FormatException('이어붙인 사진을 만들지 못했어요.');
    return (bytes: bytes, originX: offset);
  } finally {
    // 성공·실패 모두 네이티브 메모리를 즉시 해제한다. 여러 장 처리에서 GC를 기다리지 않는다.
    for (final release in releases.reversed) {
      release();
    }
  }
}

cv.Mat _decodeReceipt(Uint8List bytes) {
  final decoded = cv.imdecode(bytes, cv.IMREAD_COLOR);
  try {
    if (decoded.isEmpty || decoded.cols == 0) {
      throw const FormatException('사진을 열지 못했어요.');
    }
    final height = (decoded.rows * _outputWidth / decoded.cols).round();
    if (height > 16000 || height * _outputWidth > 24000000) {
      throw const FormatException('사진이 너무 커요. 장별로 인식해주세요.');
    }
    return cv.resize(decoded, (_outputWidth, height));
  } finally {
    decoded.dispose();
  }
}

bool _validInliers(
  List<double> matrix,
  List<ReceiptStitchPoint> a,
  List<ReceiptStitchPoint> b,
  List<int> inliers,
  int shorterHeight, {
  ReceiptStitchAlignment? alignment,
}) {
  // [OCR 수정] 최소20개·전체 변환 오차·양쪽 분포 검사는 부분 보정 여부와 관계없이 유지한다.
  if (inliers.length < 20) return false;
  final errors = <double>[];
  for (final index in inliers) {
    final projected = projectReceiptStitchPoint(matrix, b[index].x, b[index].y);
    if (projected == null) return false;
    errors.add(
      math.sqrt(
        math.pow(projected.x - a[index].x, 2) +
            math.pow(projected.y - a[index].y, 2),
      ),
    );
  }
  errors.sort();
  if (errors[errors.length ~/ 2] > 2.5) return false;
  // [OCR 수정] 전체 변환을 지지하는 점은 양쪽 사진에 충분히 퍼져 있어야 한다.
  for (final points in [a, b]) {
    final selected = [for (final index in inliers) points[index]];
    if (!hasReceiptStitchPointSpread(selected, shorterHeight: shorterHeight)) {
      return false;
    }
  }
  if (inliers.length / a.length >= .35) return true;
  // [OCR 추가] 전체 변환의 비율이 부족하면 부분 보정 후에도 기존 비율·오차 기준을 만족해야 한다.
  // 이후 격자 접힘 검사와 최종 출력의 빈 한 행 검사까지 통과해야 실제로 연결한다.
  return alignment?.hasReliableSupport(
        matchCount: a.length,
        shorterHeight: shorterHeight,
      ) ??
      false;
}
