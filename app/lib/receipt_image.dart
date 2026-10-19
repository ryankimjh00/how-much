import 'dart:math' as math; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]

/// [OCR 추가] 긴 가로 글줄 세 개 이상이 일치할 때만 작은 기울기(라디안)를 반환한다.
double estimateReceiptTilt(Iterable<List<ui.Offset>> lines) {
  // [OCR 추가]
  // [OCR 추가]
  final angles = <double>[]; // [OCR 추가]
  for (final points in lines) {
    // [OCR 추가]
    // [OCR 추가]
    if (points.length != 4 || // [OCR 추가]
        points.any((point) => !point.dx.isFinite || !point.dy.isFinite)) {
      // [OCR 추가]
      // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    final edge = points[1] - points[0]; // [OCR 추가]
    final height = (points[3] - points[0]).distance; // [OCR 추가]
    if (edge.dx <= 0 || height <= 0 || edge.distance < height * 3) {
      // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    final angle = math.atan2(edge.dy, edge.dx); // [OCR 추가]
    if (angle.abs() <= 12 * math.pi / 180) angles.add(angle); // [OCR 추가]
  } // [OCR 추가]
  if (angles.length < 3) return 0; // [OCR 추가]
  angles.sort(); // [OCR 추가]
  final middle = angles[angles.length ~/ 2]; // [OCR 추가]
  final consistent = // [OCR 추가]
      angles // [OCR 추가]
          .where(
            // [OCR 추가]
            (angle) => (angle - middle).abs() <= 2 * math.pi / 180, // [OCR 추가]
          ) // [OCR 추가]
          .toList(); // [OCR 추가]
  if (consistent.length < 3 || consistent.length < angles.length * .6) {
    // [OCR 추가]
    return 0; // [OCR 추가]
  } // [OCR 추가]
  final angle = consistent[consistent.length ~/ 2]; // [OCR 추가]
  return angle.abs() < .5 * math.pi / 180 ? 0 : angle; // [OCR 추가]
} // [OCR 추가]

/// [OCR 수정] 긴 변 1600px를 목표로 최대 3배 확대하고 선택적 기울기를 원본에서 함께 보정한다.
Future<({Uint8List bytes, ui.Size size})> prepareReceiptPhoto(
  // [OCR 수정]
  // [OCR 수정]
  Uint8List bytes, { // [OCR 수정]
  double angle = 0, // [OCR 수정]
}) async {
  // [OCR 수정]
  // [OCR 수정]
  if (!angle.isFinite || angle.abs() > 12 * math.pi / 180) {
    // [OCR 수정]
    throw const FormatException('보정할 기울기가 올바르지 않아요.'); // [OCR 수정]
  } // [OCR 수정]
  final codec = await ui.instantiateImageCodec(bytes); // [OCR 수정]
  ui.Image? source; // [OCR 수정]
  ui.Picture? picture; // [OCR 수정]
  ui.Image? corrected; // [OCR 수정]
  try {
    // [OCR 수정]
    source = (await codec.getNextFrame()).image; // [OCR 수정]
    final scale = (1600 / math.max(source.width, source.height)).clamp(
      // [OCR 수정]
      1.0, // [OCR 수정]
      3.0, // [OCR 수정]
    ); // [OCR 수정]
    if (scale == 1 && angle == 0) {
      // [OCR 수정]
      // [OCR 수정]
      return (
        // [OCR 수정]
        bytes: bytes, // [OCR 수정]
        size: ui.Size(
          source.width.toDouble(),
          source.height.toDouble(),
        ), // [OCR 수정]
      ); // [OCR 수정]
    } // [OCR 수정]
    final width = source.width * scale; // [OCR 수정]
    final height = source.height * scale; // [OCR 수정]
    final cosine = math.cos(angle).abs(); // [OCR 수정]
    final sine = math.sin(angle).abs(); // [OCR 수정]
    final outputWidth = (width * cosine + height * sine).ceil(); // [OCR 수정]
    final outputHeight = (height * cosine + width * sine).ceil(); // [OCR 수정]
    final recorder = ui.PictureRecorder(); // [OCR 수정]
    final canvas = ui.Canvas(recorder); // [OCR 수정]
    // 이유: 확대와 회전은 최초 원본에서 한 번에 수행해 이중 확대·보간을 피한다. 대비는 바꾸지 않는다. // [OCR 수정]
    canvas.drawColor(const ui.Color(0xffffffff), ui.BlendMode.src); // [OCR 수정]
    canvas.translate(outputWidth / 2, outputHeight / 2); // [OCR 수정]
    canvas.rotate(-angle); // [OCR 수정]
    canvas.drawImageRect(
      // [OCR 수정]
      source, // [OCR 수정]
      ui.Rect.fromLTWH(
        // [OCR 수정]
        0, // [OCR 수정]
        0, // [OCR 수정]
        source.width.toDouble(), // [OCR 수정]
        source.height.toDouble(), // [OCR 수정]
      ), // [OCR 수정]
      ui.Rect.fromLTWH(-width / 2, -height / 2, width, height), // [OCR 수정]
      ui.Paint()..filterQuality = ui.FilterQuality.high, // [OCR 수정]
    ); // [OCR 수정]
    picture = recorder.endRecording(); // [OCR 수정]
    corrected = await picture.toImage(outputWidth, outputHeight); // [OCR 수정]
    final data = await corrected.toByteData(
      format: ui.ImageByteFormat.png, // [OCR 수정]
    ); // [OCR 수정]
    if (data == null) {
      // [OCR 수정]
      throw const FormatException('영수증 보정 사진을 만들지 못했어요.'); // [OCR 수정]
    } // [OCR 수정]
    return (
      // [OCR 수정]
      // [OCR 수정]
      bytes: data.buffer.asUint8List(
        // [OCR 수정]
        data.offsetInBytes, // [OCR 수정]
        data.lengthInBytes, // [OCR 수정]
      ), // [OCR 수정]
      size: ui.Size(
        // [OCR 수정]
        outputWidth.toDouble(), // [OCR 수정]
        outputHeight.toDouble(), // [OCR 수정]
      ), // [OCR 수정]
    ); // [OCR 수정]
  } finally {
    // [OCR 수정]
    corrected?.dispose(); // [OCR 수정]
    picture?.dispose(); // [OCR 수정]
    source?.dispose(); // [OCR 수정]
    codec.dispose(); // [OCR 수정]
  } // [OCR 수정]
} // [OCR 수정]

/// [OCR 수정] 화면에 사용한 사진의 지정 좌표만 자른다. 부분 OCR에는 추가 확대·대비·회전을 적용하지 않는다.
Future<Uint8List> cropReceiptRegion(Uint8List bytes, ui.Rect bounds) async {
  // [OCR 추가]
  // [OCR 추가]
  if (!bounds.isFinite || bounds.isEmpty) {
    // [OCR 추가]
    throw const FormatException('사진 안의 영역을 선택해주세요.'); // [OCR 추가]
  } // [OCR 추가]
  final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
  ui.Image? source; // [OCR 추가]
  try {
    source = (await codec.getNextFrame()).image; // [OCR 수정]
    return await cropDecodedReceiptRegion(source, bounds); // [OCR 수정]
  } finally {
    source?.dispose(); // [OCR 수정]
    codec.dispose(); // [OCR 수정]
  }
} // [OCR 수정]

/// [OCR 추가] 디코딩된 사진에서 기존과 같은 좌표·픽셀로 자른다. 원본 이미지의 수명은 호출자가 관리한다.
Future<Uint8List> cropDecodedReceiptRegion(
  ui.Image source,
  ui.Rect bounds,
) async {
  if (!bounds.isFinite || bounds.isEmpty) {
    throw const FormatException('사진 안의 영역을 선택해주세요.');
  } // [OCR 추가]
  ui.Picture? picture; // [OCR 추가]
  ui.Image? cropped; // [OCR 추가]
  try {
    final clipped = bounds.intersect(
      // [OCR 추가]
      ui.Rect.fromLTWH(
        0,
        0,
        source.width.toDouble(),
        source.height.toDouble(),
      ), // [OCR 추가]
    ); // [OCR 추가]
    if (clipped.isEmpty) {
      // [OCR 추가]
      throw const FormatException('사진 안의 영역을 선택해주세요.'); // [OCR 추가]
    } // [OCR 추가]
    final rect = ui.Rect.fromLTRB(
      // [OCR 추가]
      clipped.left.floorToDouble(), // [OCR 추가]
      clipped.top.floorToDouble(), // [OCR 추가]
      clipped.right.ceilToDouble(), // [OCR 추가]
      clipped.bottom.ceilToDouble(), // [OCR 추가]
    ); // [OCR 추가]
    final recorder = ui.PictureRecorder(); // [OCR 추가]
    ui.Canvas(recorder).drawImageRect(
      // [OCR 추가]
      source, // [OCR 추가]
      rect, // [OCR 추가]
      ui.Rect.fromLTWH(0, 0, rect.width, rect.height), // [OCR 추가]
      ui.Paint(), // [OCR 추가]
    ); // [OCR 추가]
    picture = recorder.endRecording(); // [OCR 추가]
    cropped = await picture.toImage(
      // [OCR 추가]
      rect.width.toInt(), // [OCR 추가]
      rect.height.toInt(), // [OCR 추가]
    ); // [OCR 추가]
    final data = await cropped.toByteData(
      // [OCR 추가]
      format: ui.ImageByteFormat.png, // [OCR 추가]
    ); // [OCR 추가]
    if (data == null) {
      // [OCR 추가]
      throw const FormatException('선택 영역을 읽지 못했어요.'); // [OCR 추가]
    } // [OCR 추가]
    return data.buffer.asUint8List(
      // [OCR 추가]
      data.offsetInBytes, // [OCR 추가]
      data.lengthInBytes, // [OCR 추가]
    ); // [OCR 추가]
  } finally {
    // [OCR 추가]
    // [OCR 추가]
    cropped?.dispose(); // [OCR 추가]
    picture?.dispose(); // [OCR 추가]
  } // [OCR 추가]
} // [OCR 추가]
