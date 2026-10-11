import 'dart:math' as math; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'package:flutter/foundation.dart'; // [OCR 추가]

/// [OCR 추가] 축소 이미지의 밝은 연결 영역에서 종이 모서리를 추정한다. 불확실하면 null을 반환한다.
List<ui.Offset>? detectReceiptCorners(Uint8List rgba, int width, int height) {
  // [OCR 추가]
  final visited = Uint8List(width * height); // [OCR 추가]
  List<int> largest = []; // [OCR 추가]
  bool paper(int index) {
    // [OCR 추가]
    final offset = index * 4; // [OCR 추가]
    final red = rgba[offset]; // [OCR 추가]
    final green = rgba[offset + 1]; // [OCR 추가]
    final blue = rgba[offset + 2]; // [OCR 추가]
    return math.min(red, math.min(green, blue)) > 125 && // [OCR 추가]
        math.max(red, math.max(green, blue)) -
                math.min(red, math.min(green, blue)) <
            65; // [OCR 추가]
  } // [OCR 추가]

  // [OCR 추가] 글자 대신 종이의 연속된 밝은 영역을 이용해 배경과 구분한다.
  for (var index = 0; index < visited.length; index++) {
    // [OCR 추가]
    if (visited[index] != 0 || !paper(index)) continue; // [OCR 추가]
    final queue = <int>[index]; // [OCR 추가]
    visited[index] = 1; // [OCR 추가]
    for (var head = 0; head < queue.length; head++) {
      // [OCR 추가]
      final current = queue[head]; // [OCR 추가]
      final x = current % width; // [OCR 추가]
      final y = current ~/ width; // [OCR 추가]
      for (final next in [
        if (x > 0) current - 1, if (x + 1 < width) current + 1, // [OCR 추가]
        if (y > 0) current - width, if (y + 1 < height) current + width,
      ]) {
        // [OCR 추가]
        if (visited[next] == 0 && paper(next)) {
          // [OCR 추가]
          visited[next] = 1; // [OCR 추가]
          queue.add(next); // [OCR 추가]
        } // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    if (queue.length > largest.length) largest = queue; // [OCR 추가]
  } // [OCR 추가]
  if (largest.length < width * height * .15) return null; // [OCR 추가]
  ui.Offset extreme(double Function(ui.Offset) score, bool minimum) {
    // [OCR 추가]
    var best = ui.Offset(
      (largest.first % width).toDouble(),
      (largest.first ~/ width).toDouble(),
    ); // [OCR 추가]
    for (final index in largest) {
      // [OCR 추가]
      final point = ui.Offset(
        (index % width).toDouble(),
        (index ~/ width).toDouble(),
      ); // [OCR 추가]
      if (minimum ? score(point) < score(best) : score(point) > score(best)) {
        // [OCR 추가]
        best = point; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    return best; // [OCR 추가]
  } // [OCR 추가]

  final corners = [
    extreme((p) => p.dx + p.dy, true),
    extreme((p) => p.dx - p.dy, false), // [OCR 추가]
    extreme((p) => p.dx + p.dy, false), extreme((p) => p.dx - p.dy, true),
  ]; // [OCR 추가]
  return validReceiptCorners(
        corners,
        ui.Size(width.toDouble(), height.toDouble()),
      )
      ? corners
      : null; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 좌상→우상→우하→좌하의 볼록 사각형만 허용하고 교차·극소 영역을 거부한다.
bool validReceiptCorners(List<ui.Offset> corners, ui.Size size) {
  // [OCR 추가]
  if (corners.length != 4 ||
      corners.any(
        (p) =>
            !p.dx.isFinite ||
            !p.dy.isFinite || // [OCR 추가]
            p.dx < 0 ||
            p.dy < 0 ||
            p.dx > size.width - 1 ||
            p.dy > size.height - 1,
      )) {
    // [OCR 추가]
    return false; // [OCR 추가]
  } // [OCR 추가]
  var area = 0.0; // [OCR 추가]
  for (var index = 0; index < 4; index++) {
    // [OCR 추가]
    final current = corners[index]; // [OCR 추가]
    final next = corners[(index + 1) % 4]; // [OCR 추가]
    final following = corners[(index + 2) % 4]; // [OCR 추가]
    final first = next - current; // [OCR 추가]
    final second = following - next; // [OCR 추가]
    if (first.dx * second.dy - first.dy * second.dx <= 1 ||
        first.distance < 8) {
      // [OCR 추가]
      return false; // [OCR 추가]
    } // [OCR 추가]
    area += current.dx * next.dy - next.dx * current.dy; // [OCR 추가]
  } // [OCR 추가]
  return area / 2 >= size.width * size.height * .01; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 원본을 보존하고 축소 사진에서 찾은 좌표를 원본 좌표로 되돌린다.
Future<({ui.Size size, List<ui.Offset>? corners})> findReceiptCorners(
  Uint8List bytes,
) async {
  // [OCR 추가]
  final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
  final image = (await codec.getNextFrame()).image; // [OCR 추가]
  codec.dispose(); // [OCR 추가]
  final scale = math.min(
    1.0,
    400 / math.max(image.width, image.height),
  ); // [OCR 추가]
  final width = (image.width * scale).round(); // [OCR 추가]
  final height = (image.height * scale).round(); // [OCR 추가]
  final recorder = ui.PictureRecorder(); // [OCR 추가]
  ui.Canvas(recorder).drawImageRect(
    image,
    ui.Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    ), // [OCR 추가]
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..filterQuality = ui.FilterQuality.medium,
  ); // [OCR 추가]
  final picture = recorder.endRecording(); // [OCR 추가]
  final small = await picture.toImage(width, height); // [OCR 추가]
  try {
    // [OCR 추가]
    final data = await small.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ); // [OCR 추가]
    final size = ui.Size(
      image.width.toDouble(),
      image.height.toDouble(),
    ); // [OCR 추가]
    final points = await compute(_detectPixels, (
      data!.buffer.asUint8List(),
      width,
      height,
    )); // [OCR 추가]
    return (
      size: size,
      corners: points
          ?.map(
            (p) => ui.Offset(
              p.dx * (image.width - 1) / (width - 1), // [OCR 추가]
              p.dy * (image.height - 1) / (height - 1),
            ),
          )
          .toList(),
    ); // [OCR 추가]
  } finally {
    // [OCR 추가]
    small.dispose();
    picture.dispose();
    image.dispose(); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]

List<ui.Offset>? _detectPixels((Uint8List, int, int) input) =>
    detectReceiptCorners(input.$1, input.$2, input.$3); // [OCR 추가]

// [OCR 추가] 출력→원본의 투영 행렬을 풀어 빈 픽셀이 생기지 않도록 역변환한다.
List<double> _inverseProjection(
  List<ui.Offset> corners,
  int width,
  int height,
) {
  // [OCR 추가]
  final destinations = [
    ui.Offset.zero,
    ui.Offset(width - 1.0, 0),
    ui.Offset(width - 1.0, height - 1.0),
    ui.Offset(0, height - 1.0),
  ]; // [OCR 추가]
  final matrix = <List<double>>[]; // [OCR 추가]
  for (var index = 0; index < 4; index++) {
    // [OCR 추가]
    final x = destinations[index].dx;
    final y = destinations[index].dy; // [OCR 추가]
    final sourceX = corners[index].dx;
    final sourceY = corners[index].dy; // [OCR 추가]
    matrix.add([
      x,
      y,
      1,
      0,
      0,
      0,
      -sourceX * x,
      -sourceX * y,
      sourceX,
    ]); // [OCR 추가]
    matrix.add([
      0,
      0,
      0,
      x,
      y,
      1,
      -sourceY * x,
      -sourceY * y,
      sourceY,
    ]); // [OCR 추가]
  } // [OCR 추가]
  for (var column = 0; column < 8; column++) {
    // [OCR 추가]
    var pivot = column; // [OCR 추가]
    for (var row = column + 1; row < 8; row++) {
      // [OCR 추가]
      if (matrix[row][column].abs() > matrix[pivot][column].abs()) {
        // [OCR 추가]
        pivot = row; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    if (matrix[pivot][column].abs() < 1e-10) {
      // [OCR 추가]
      throw const FormatException('보정 영역을 다시 지정해주세요.'); // [OCR 추가]
    } // [OCR 추가]
    final swap = matrix[column];
    matrix[column] = matrix[pivot];
    matrix[pivot] = swap; // [OCR 추가]
    final divisor = matrix[column][column]; // [OCR 추가]
    for (var item = column; item <= 8; item++) {
      matrix[column][item] /= divisor;
    } // [OCR 추가]
    for (var row = 0; row < 8; row++) {
      // [OCR 추가]
      if (row == column) continue; // [OCR 추가]
      final factor = matrix[row][column]; // [OCR 추가]
      for (var item = column; item <= 8; item++) {
        matrix[row][item] -= factor * matrix[column][item];
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return [for (final row in matrix) row[8]]; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 원본 사각형을 직사각형으로 보간한다. OCR과 독립된 순수 픽셀 변환이다.
({Uint8List pixels, int width, int height}) warpReceiptPixels(
  Uint8List pixels,
  int sourceWidth,
  int sourceHeight,
  List<ui.Offset> corners,
) {
  // [OCR 추가]
  if (!validReceiptCorners(
    corners,
    ui.Size(sourceWidth.toDouble(), sourceHeight.toDouble()),
  )) {
    // [OCR 추가]
    throw const FormatException('네 모서리가 교차하지 않도록 맞춰주세요.'); // [OCR 추가]
  } // [OCR 추가]
  final width =
      math
          .max(
            (corners[1] - corners[0]).distance,
            (corners[2] - corners[3]).distance,
          )
          .round() +
      1; // [OCR 추가]
  final height =
      math
          .max(
            (corners[3] - corners[0]).distance,
            (corners[2] - corners[1]).distance,
          )
          .round() +
      1; // [OCR 추가]
  final matrix = _inverseProjection(corners, width, height); // [OCR 추가]
  final output = Uint8List(width * height * 4); // [OCR 추가]
  for (var y = 0; y < height; y++) {
    // [OCR 추가]
    for (var x = 0; x < width; x++) {
      // [OCR 추가]
      final divisor = matrix[6] * x + matrix[7] * y + 1; // [OCR 추가]
      final sourceX = ((matrix[0] * x + matrix[1] * y + matrix[2]) / divisor)
          .clamp(0.0, sourceWidth - 1.0); // [OCR 추가]
      final sourceY = ((matrix[3] * x + matrix[4] * y + matrix[5]) / divisor)
          .clamp(0.0, sourceHeight - 1.0); // [OCR 추가]
      final left = sourceX.floor();
      final top = sourceY.floor(); // [OCR 추가]
      final right = math.min(left + 1, sourceWidth - 1);
      final bottom = math.min(top + 1, sourceHeight - 1); // [OCR 추가]
      final horizontal = sourceX - left;
      final vertical = sourceY - top; // [OCR 추가]
      for (var channel = 0; channel < 4; channel++) {
        // [OCR 추가]
        final upper =
            pixels[(top * sourceWidth + left) * 4 + channel] *
                (1 - horizontal) +
            pixels[(top * sourceWidth + right) * 4 + channel] *
                horizontal; // [OCR 추가]
        final lower =
            pixels[(bottom * sourceWidth + left) * 4 + channel] *
                (1 - horizontal) +
            pixels[(bottom * sourceWidth + right) * 4 + channel] *
                horizontal; // [OCR 추가]
        output[(y * width + x) * 4 + channel] =
            (upper * (1 - vertical) + lower * vertical).round(); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return (pixels: output, width: width, height: height); // [OCR 추가]
} // [OCR 추가]

({Uint8List pixels, int width, int height}) _warpPixels(
  (Uint8List, int, int, List<ui.Offset>) input,
) => warpReceiptPixels(input.$1, input.$2, input.$3, input.$4); // [OCR 추가]

/// [OCR 추가] 원본을 덮어쓰지 않고 PNG를 반환한다. 무거운 픽셀 연산은 별도 isolate에서 실행한다.
Future<Uint8List> correctReceiptPerspective(
  Uint8List bytes,
  List<ui.Offset> corners,
) async {
  // [OCR 추가]
  final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
  final image = (await codec.getNextFrame()).image; // [OCR 추가]
  codec.dispose(); // [OCR 추가]
  late final ({Uint8List pixels, int width, int height}) warped; // [OCR 추가]
  try {
    // [OCR 추가]
    final data = await image.toByteData(
      format: ui.ImageByteFormat.rawRgba,
    ); // [OCR 추가]
    warped = await compute(_warpPixels, (
      data!.buffer.asUint8List(),
      image.width,
      image.height,
      corners,
    )); // [OCR 추가]
  } finally {
    image.dispose();
  } // [OCR 추가]
  final buffer = await ui.ImmutableBuffer.fromUint8List(
    warped.pixels,
  ); // [OCR 추가]
  final descriptor = ui.ImageDescriptor.raw(
    buffer,
    width: warped.width,
    height: warped.height,
    pixelFormat: ui.PixelFormat.rgba8888,
  ); // [OCR 추가]
  final outputCodec = await descriptor.instantiateCodec(); // [OCR 추가]
  final output = (await outputCodec.getNextFrame()).image; // [OCR 추가]
  try {
    // [OCR 추가]
    final png = await output.toByteData(
      format: ui.ImageByteFormat.png,
    ); // [OCR 추가]
    if (png == null) {
      // [OCR 추가]
      throw const FormatException('보정 사진을 만들지 못했어요.'); // [OCR 추가]
    } // [OCR 추가]
    return png.buffer.asUint8List(
      png.offsetInBytes,
      png.lengthInBytes,
    ); // [OCR 추가]
  } finally {
    output.dispose();
    outputCodec.dispose();
    descriptor.dispose();
    buffer.dispose();
  } // [OCR 추가]
} // [OCR 추가]
