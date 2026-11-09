import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dartcv4/dartcv.dart' as cv;
import 'receipt_stitch_match.dart';
import 'receipt_stitch_alignment.dart';
import 'receipt_stitch_layout.dart';

const _featureWidth = 1000;
const _outputWidth = 1600;

/// [OCR 수정] 원본 인접 두 사진의 대응점과 절단 위치만 계산한다. 누적 이미지는 입력하지 않는다.
ReceiptStitchPairPlan planReceiptStitchPair(
  ({Uint8List first, Uint8List second}) photos,
) {
  try {
    return _planReceiptStitchPair(photos, useAkaze: true);
  } on FormatException {
    return _planReceiptStitchPair(photos, useAkaze: false);
  }
}

ReceiptStitchPairPlan _planReceiptStitchPair(
  ({Uint8List first, Uint8List second}) photos, {
  required bool useAkaze,
}) {
  final releases = <void Function()>[];
  T own<T extends cv.CvObject>(T resource) {
    releases.add(resource.dispose);
    return resource;
  }

  try {
    final first = own(decodeReceiptStitchPhoto(photos.first));
    final second = own(decodeReceiptStitchPhoto(photos.second));
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
    final left = math.min(0, corners.map((p) => p.x).reduce(math.min)).floor();
    final right = math
        .max(a.cols.toDouble(), corners.map((p) => p.x).reduce(math.max))
        .ceil();
    final bottom = math
        .max(a.rows.toDouble(), corners.map((p) => p.y).reduce(math.max))
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
      cv.warpPerspective(second, transformB, (
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
    final inverse = invertReceiptStitchMatrix(matrix);
    final body = estimateReceiptStitchBodyScale(
      [for (final i in inliers) pointsA[i]],
      [for (final i in inliers) pointsB[i]],
    );
    if (inverse == null || body == null) {
      throw const FormatException('사진 사이의 일정한 배율을 구하지 못했어요.');
    }
    return ReceiptStitchPairPlan(
      matrix: matrix,
      inverse: inverse,
      alignment: alignment,
      firstHeight: first.rows,
      secondHeight: second.rows,
      cutY: cutY,
      bodyScale: body.scale,
      bodyTranslateX: body.translateX * scale,
      checkLeft: (overlap.start - cut * inkA.cols + left) * scale,
      checkRight: (overlap.end - cut * inkA.cols + left) * scale,
      corners: corners,
    );
  } finally {
    // 성공·실패 모두 네이티브 메모리를 즉시 해제한다. 여러 장 처리에서 GC를 기다리지 않는다.
    for (final release in releases.reversed) {
      release();
    }
  }
}

/// [OCR 추가] 너비1600px 원본을 반환한다. 호출자가 Mat을 해제하며 파일은 수정하지 않는다.
cv.Mat decodeReceiptStitchPhoto(Uint8List bytes) {
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
