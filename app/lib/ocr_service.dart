import 'receipt_pages.dart'; // [OCR 추가]
import 'receipt_product_regions.dart'; // [OCR 추가]
import 'dart:io'; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui' as ui; // [OCR 추가]
import 'receipt_image.dart'; // [OCR 추가]
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

import 'models.dart';
import 'receipt_ocr.dart'; // [OCR 추가]
import 'receipt_column_scan.dart'; // [OCR 추가]

class OcrService {
  final ImagePicker _picker = ImagePicker();

  Future<ReceiptDraft?> pickFromGallery({
    // [OCR 수정]
    Future<Uint8List?> Function(Uint8List)? correctPhoto, // [OCR 추가]
  }) async {
    // [OCR 수정]
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return null;
    final original = await File(image.path).readAsBytes(); // [OCR 추가]
    final corrected = correctPhoto == null
        ? original
        : await correctPhoto(original); // [OCR 추가]
    if (corrected == null) return null; // [OCR 추가] 모서리 확인 취소 시 OCR을 실행하지 않는다.
    return recognizePath(
      image.path,
      allowManualRegions: true,
      photoBytes: corrected,
    ); // [OCR 수정]
  } // [OCR 추가]

  /// [OCR 추가] 앨범에서 사진 경로만 수집한다. OCR은 실행하지 않으며 취소하면 빈 목록을 반환한다.
  Future<List<ReceiptPhotoPage>> pickReceiptPages({required int limit}) async {
    // [OCR 추가]
    // [OCR 추가]
    final images = await _picker.pickMultiImage(
      // [OCR 추가]
      imageQuality: 92, // [OCR 추가]
      maxWidth: 2400, // [OCR 추가]
      limit: limit, // [OCR 추가]
    ); // [OCR 추가]
    return [
      // [OCR 추가]
      for (final image in images)
        ReceiptPhotoPage(path: image.path), // [OCR 추가]
    ]; // [OCR 수정] 앨범에서 고를 때는 파일 경로만 반환한다.
  } // [OCR 추가]

  Future<List<MemoLineDraft>?> pickMemo(ImageSource source) async {
    final image = await _picker.pickImage(
      source: source,
      imageQuality: 92,
      maxWidth: 2400,
    );
    if (image == null) return null;
    return recognizeMemoPath(image.path);
  }

  Future<List<MemoLineDraft>> recognizeMemoPath(String path) async {
    final lines = parseMemoText(await _recognizeText(path));
    if (lines.isEmpty) {
      throw const FormatException('메모에서 상품을 찾지 못했어요. 다시 촬영하거나 직접 입력해주세요.');
    }
    return lines;
  }

  /// [OCR 수정] 사진을 인식해 기존 검토 초안과 임시 OCR 원문·좌표를 함께 반환한다.
  Future<ReceiptDraft> recognizePath(
    // [OCR 추가]
    String path, { // [OCR 추가]
    bool allowManualRegions = false, // [OCR 추가]
    Uint8List? photoBytes, // [OCR 추가]
  }) async {
    // [OCR 추가]
    // [OCR 수정]
    final photo = await _recognizeReceiptPhoto(
      path,
      photoBytes,
    ); // [OCR 수정] // [OCR 추가]
    final recognized = photo.recognized; // [OCR 수정]
    final draft = parseReceiptText(
      recognized.text, // [OCR 수정]
      id: DateTime.now().microsecondsSinceEpoch.toString(),
    );
    // [OCR 수정] 문자열 파서가 항목을 제외해도 좌표 후보를 직접 선택할 수 있도록 원문 인식 실패만 중단합니다.
    // [OCR 추가] 이유: 사진 선택 흐름은 빈 OCR이어도 수동 영역을 지정할 수 있다. 일반 인식 호출의 실패 계약은 유지한다.
    if (recognized.text.trim().isEmpty && !allowManualRegions) {
      // [OCR 추가]
      // [OCR 수정]
      throw const FormatException('영수증을 읽지 못했어요. 다시 촬영하거나 직접 입력해주세요.');
    }
    final result = mergeReceiptProductRegions(
      // [OCR 추가]
      receiptOcrFromRecognizedText(
        // [OCR 추가]
        recognized, // [OCR 추가]
        path, // [OCR 추가]
        photoBytes: photo.bytes, // [OCR 추가]
      ), // [OCR 수정]
    ); // [OCR 추가]
    draft.ocrResult = result; // [OCR 추가]
    if (result.products.any((product) => product.isMergedName)) {
      // [OCR 추가]
      // [OCR 추가]
      try {
        // [OCR 추가]
        // [OCR 추가]
        final bytes = photo.bytes; // [OCR 수정]
        draft.ocrResult = await rereadMergedProductNames(
          // [OCR 추가]
          result, // [OCR 추가]
          (bounds) => recognizeRegion(bytes, bounds), // [OCR 추가]
        ); // [OCR 추가]
      } on FileSystemException {
        // [OCR 추가]
        // [OCR 추가]
        // [OCR 추가] 이유: 원본을 다시 열지 못해도 전체 OCR에서 읽은 이름과 합친 좌표를 버리지 않는다.
      } // [OCR 추가]
    } // [OCR 추가]
    return draft;
  }

  // 이유: 첫 OCR도 확대 사진에서 수행한다. 최종 사진과 좌표를 항상 함께 유지한다. // [OCR 수정]
  Future<({RecognizedText recognized, Uint8List bytes})> _recognizeReceiptPhoto(
    // [OCR 수정]
    String path, // [OCR 수정]
    Uint8List? photoBytes, // [OCR 추가]
  ) async {
    // [OCR 수정]
    // [OCR 수정]
    final original = photoBytes ?? await File(path).readAsBytes(); // [OCR 수정]
    final firstPhoto = await prepareReceiptPhoto(original); // [OCR 수정]
    final firstResult = await _recognizePhoto(firstPhoto.bytes); // [OCR 수정]
    final angle = estimateReceiptTilt([
      // [OCR 수정]
      for (final block in firstResult.blocks) // [OCR 수정]
        for (final line in block.lines) // [OCR 수정]
          [
            for (final point in line.cornerPoints) // [OCR 수정]
              ui.Offset(point.x.toDouble(), point.y.toDouble()), // [OCR 수정]
          ], // [OCR 수정]
    ]); // [OCR 수정]
    if (angle != 0) {
      // [OCR 수정]
      // [OCR 수정]
      try {
        // [OCR 수정]
        // [OCR 수정]
        // 첫 확대 사진을 재확대하지 않고 최초 원본에 확대와 회전을 함께 적용한다. // [OCR 수정]
        final corrected = await prepareReceiptPhoto(
          // [OCR 수정]
          original, // [OCR 수정]
          angle: angle, // [OCR 수정]
        ); // [OCR 수정]
        final recognized = await _recognizePhoto(corrected.bytes); // [OCR 수정]
        if (recognized.text.trim().isNotEmpty) {
          // [OCR 수정]
          // [OCR 수정]
          return (recognized: recognized, bytes: corrected.bytes); // [OCR 수정]
        } // [OCR 수정]
      } catch (_) {
        // [OCR 수정]
        // [OCR 수정]
        // 보정 재시도에 실패하면 첫 확대 사진과 그 좌표를 함께 유지한다. // [OCR 수정]
      } // [OCR 수정]
    } // [OCR 수정]
    return (recognized: firstResult, bytes: firstPhoto.bytes); // [OCR 수정]
  } // [OCR 수정]

  // 호출별 임시 사진은 첫 인식과 재인식의 성공·실패 모두 정리한다. // [OCR 수정]
  Future<RecognizedText> _recognizePhoto(Uint8List bytes) async {
    // [OCR 수정]
    // [OCR 수정]
    final directory = await Directory.systemTemp.createTemp(
      // [OCR 수정]
      'receipt-ocr-', // [OCR 수정]
    ); // [OCR 수정]
    try {
      // [OCR 수정]
      final file = File('${directory.path}/photo.png'); // [OCR 수정]
      await file.writeAsBytes(bytes, flush: true); // [OCR 수정]
      return await _recognize(file.path); // [OCR 수정]
    } finally {
      // [OCR 수정]
      // [OCR 수정]
      await directory.delete(recursive: true); // [OCR 수정]
    } // [OCR 수정]
  } // [OCR 수정]

  /// [OCR 추가] 현재 한 장의 자동 선택 동안 사진·인식기만 재사용하고 작업 완료/취소/실패 후 정리한다.
  Future<T> withReceiptRegionSession<T>(
    Uint8List bytes,
    Future<T> Function(ReceiptRegionSession session) work, {
    bool parallelQuantity = false, // [OCR 추가] 사진은 공유하고 수량 전용 인식기/파일만 추가한다.
  }) async {
    final codec = await ui.instantiateImageCodec(bytes); // [OCR 추가]
    ui.Image? photo; // [OCR 추가]
    Directory? directory; // [OCR 추가]
    ReceiptRegionSession? session; // [OCR 추가]
    try {
      photo = (await codec.getNextFrame()).image; // [OCR 추가]
      directory = await Directory.systemTemp.createTemp(
        'receipt-session-',
      ); // [OCR 추가]
      final quantitySession = parallelQuantity
          ? ReceiptRegionSession._(photo, directory, fileName: 'quantity.png')
          : null; // [OCR 추가]
      session = ReceiptRegionSession._(
        photo,
        directory,
        quantitySession: quantitySession,
      ); // [OCR 수정]
      return await work(session); // [OCR 추가]
    } finally {
      // [OCR 추가] 진행 중 호출이 끝나기 전 사진/파일/네이티브 인식기를 해제하지 않는다.
      try {
        await session?._close(); // [OCR 추가]
      } finally {
        photo?.dispose(); // [OCR 추가]
        codec.dispose(); // [OCR 추가]
        await directory?.delete(recursive: true); // [OCR 추가]
      }
    }
  } // [OCR 추가]

  /// [OCR 수정] 표시 사진 좌표의 부분만 인식하고 임시 파일과 인식기를 완료·실패 모두 정리한다.
  Future<String> recognizeRegion(Uint8List bytes, ui.Rect bounds) async {
    // [OCR 추가]
    // [OCR 추가]
    final cropped = await cropReceiptRegion(bytes, bounds); // [OCR 추가]
    final directory = await Directory.systemTemp.createTemp(
      // [OCR 추가]
      'receipt-region-', // [OCR 추가]
    ); // [OCR 추가]
    try {
      // [OCR 추가]
      // [OCR 추가]
      final image = File('${directory.path}/region.png'); // [OCR 추가]
      await image.writeAsBytes(cropped, flush: true); // [OCR 추가]
      // [OCR 수정] 이유: 부분 재인식도 세로 글씨를 후보에 다시 넣지 않도록 동일한 방향 기준을 적용한다.
      final recognized = await _recognize(image.path); // [OCR 추가]
      return receiptHorizontalText(
        // [OCR 추가]
        receiptOcrFromRecognizedText(recognized, image.path), // [OCR 추가]
      ); // [OCR 추가]
    } finally {
      // [OCR 추가]
      await directory.delete(recursive: true); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]

  /// [OCR 추가] 열 크롭의 가로 행 위치를 보정 사진 좌표로 반환한다. 문자열의 숫자 정확도와 위치 탐색을 분리한다.
  Future<List<ReceiptOcrCandidate>> recognizeRegionRows(
    Uint8List bytes,
    ui.Rect bounds,
  ) async {
    // [OCR 추가] 호출 영역을 정수 경계로 맞춰 실제 크롭과 좌표 복원의 기준을 일치시킨다.
    final crop = ui.Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(), // [OCR 추가]
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(), // [OCR 추가]
    ); // [OCR 추가]
    final cropped = await cropReceiptRegion(bytes, crop); // [OCR 추가]
    final recognized = await _recognizePhoto(cropped); // [OCR 추가]
    return receiptCropRowsInPhoto(
      receiptOcrFromRecognizedText(recognized, ''),
      crop, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]

  Future<String> _recognizeText(String path) async {
    return (await _recognize(path)).text; // [OCR 수정]
  } // [OCR 추가]

  Future<RecognizedText> _recognize(String path) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.korean);
    try {
      final result = await recognizer.processImage(
        InputImage.fromFilePath(path),
      );
      return result; // [OCR 수정]
    } finally {
      await recognizer.close();
    }
  }
}

/// [OCR 추가] 한 사진 전용 부분 OCR 세션이다. 순차 호출하며 세션 밖으로 보관하지 않는다.
class ReceiptRegionSession {
  ReceiptRegionSession._(
    this._photo,
    this._directory, {
    String fileName = 'region.png',
    this.quantitySession,
  }) : _fileName = fileName; // [OCR 수정]
  /// [OCR 추가] 같은 사진을 공유하는 별도 수량 작업자다. 각 작업자 내부는 순차 호출한다.
  final ReceiptRegionSession? quantitySession; // [OCR 추가]
  final String _fileName; // [OCR 추가]
  final ui.Image _photo; // [OCR 추가]
  final Directory _directory; // [OCR 추가]
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.korean,
  ); // [OCR 추가]
  Future<RecognizedText>? _pending; // [OCR 추가]
  bool _closed = false; // [OCR 추가]

  Future<RecognizedText> _read(ui.Rect bounds) async {
    if (_closed || _pending != null) {
      throw StateError('사진 인식 세션은 열린 상태에서 순차 호출해야 합니다.');
    } // [OCR 추가]
    final pending = _process(bounds); // [OCR 추가]
    _pending = pending; // [OCR 추가]
    try {
      return await pending; // [OCR 추가]
    } finally {
      _pending = null; // [OCR 추가]
    }
  } // [OCR 추가]

  Future<RecognizedText> _process(ui.Rect bounds) async {
    final cropped = await cropDecodedReceiptRegion(_photo, bounds); // [OCR 추가]
    final file = File('${_directory.path}/$_fileName'); // [OCR 수정]
    await file.writeAsBytes(cropped, flush: true); // [OCR 추가]
    return await _recognizer.processImage(
      InputImage.fromFilePath(file.path),
    ); // [OCR 추가]
  } // [OCR 추가]

  /// [OCR 추가] 기존 부분 인식과 같은 가로 글씨 제외 기준을 적용한다.
  Future<String> recognizeRegion(ui.Rect bounds) async {
    final recognized = await _read(bounds); // [OCR 추가]
    return receiptHorizontalText(
      receiptOcrFromRecognizedText(recognized, ''),
    ); // [OCR 추가]
  } // [OCR 추가]

  /// [OCR 추가] 수량 주변의 같은 높이 행을 함께 읽되 지정한 수량 영역 안의 값만 반환한다.
  Future<String> recognizeQuantityRegion(
    ui.Rect bounds, {
    required double horizontalContext,
  }) async {
    if (!bounds.isFinite ||
        bounds.isEmpty ||
        !horizontalContext.isFinite ||
        horizontalContext < 0) {
      throw const FormatException('사진 안의 수량 영역을 선택해주세요.'); // [OCR 추가]
    } // [OCR 추가]
    // [OCR 추가] 작은 1도 행 문맥으로 인식하며 높이는 늘리지 않아 아래 상품을 읽지 않는다.
    final crop = ui.Rect.fromLTRB(
      (bounds.left - horizontalContext).clamp(0, _photo.width).floorToDouble(),
      bounds.top.clamp(0, _photo.height).floorToDouble(),
      (bounds.right + horizontalContext).clamp(0, _photo.width).ceilToDouble(),
      bounds.bottom.clamp(0, _photo.height).ceilToDouble(),
    ); // [OCR 추가]
    final recognized = await _read(crop); // [OCR 추가]
    final result = receiptOcrFromRecognizedText(recognized, ''); // [OCR 추가]
    final values = <int>{}; // [OCR 추가]
    for (final candidate in result.numbers) {
      final center = candidate.bounds.center + crop.topLeft; // [OCR 추가]
      if (!bounds.contains(center)) {
        // [OCR 추가]
        continue; // [OCR 추가] 가격·할인 열의 숫자는 수량으로 가져오지 않는다.
      } // [OCR 추가]
      final value = candidate.number!; // [OCR 추가]
      if (value < 1 || value > 999) return ''; // [OCR 추가]
      values.add(value); // [OCR 추가]
    } // [OCR 추가]
    // [OCR 추가] 서로 다른 수량이 겹치거나 인식이 비면 임의의 1로 확정하지 않는다.
    return values.length == 1 ? values.single.toString() : ''; // [OCR 추가]
  } // [OCR 추가]

  /// [OCR 추가] 크롭 행을 현재 표시 사진의 원본 좌표로 복원한다.
  Future<List<ReceiptOcrCandidate>> recognizeRegionRows(ui.Rect bounds) async {
    final crop = ui.Rect.fromLTRB(
      bounds.left.floorToDouble(),
      bounds.top.floorToDouble(),
      bounds.right.ceilToDouble(),
      bounds.bottom.ceilToDouble(),
    ); // [OCR 추가]
    final recognized = await _read(crop); // [OCR 추가]
    return receiptCropRowsInPhoto(
      receiptOcrFromRecognizedText(recognized, ''),
      crop,
    ); // [OCR 추가]
  } // [OCR 추가]

  Future<void> _close() async {
    _closed = true; // [OCR 추가]
    try {
      await _pending; // [OCR 추가]
    } catch (_) {
      // [OCR 추가] 인식 오류는 호출자에게 전달하며 정리까지 막지 않도록 한다.
    } finally {
      await Future.wait<void>([
        _recognizer.close(),
        if (quantitySession != null) quantitySession!._close(),
      ]); // [OCR 수정] 두 인식기의 종료까지 기다린 뒤 공유 사진·파일을 정리한다.
    }
  } // [OCR 추가]
}

/// [OCR 추가] ML Kit 줄·단어 좌표를 보존한다. 단어가 없는 줄은 줄 좌표를 대신 사용한다.
ReceiptOcrResult receiptOcrFromRecognizedText(
  // [OCR 추가]
  RecognizedText recognized, // [OCR 추가]
  String path, { // [OCR 수정]
  Uint8List? photoBytes, // [OCR 추가]
}) {
  // [OCR 추가]
  // [OCR 추가]
  final rows = <ReceiptOcrRow>[]; // [OCR 추가]
  for (
    // [OCR 추가]
    var blockIndex = 0; // [OCR 추가]
    blockIndex < recognized.blocks.length; // [OCR 추가]
    blockIndex++ // [OCR 추가]
  ) {
    // [OCR 추가]
    final block = recognized.blocks[blockIndex]; // [OCR 추가]
    for (var lineIndex = 0; lineIndex < block.lines.length; lineIndex++) {
      // [OCR 추가]
      final line = block.lines[lineIndex]; // [OCR 추가]
      final id = 'block-$blockIndex-line-$lineIndex'; // [OCR 추가]
      final tokens = <ReceiptOcrToken>[]; // [OCR 추가]
      for (var index = 0; index < line.elements.length; index++) {
        // [OCR 추가]
        final element = line.elements[index]; // [OCR 추가]
        tokens.add(
          // [OCR 추가]
          ReceiptOcrToken(
            // [OCR 추가]
            id: '$id-element-$index', // [OCR 추가]
            text: element.text, // [OCR 추가]
            bounds: element.boundingBox, // [OCR 추가]
            angle: element.angle ?? line.angle, // [OCR 추가]
          ), // [OCR 추가]
        ); // [OCR 추가]
      } // [OCR 추가]
      if (tokens.isEmpty) {
        // [OCR 추가]
        tokens.add(
          // [OCR 추가]
          ReceiptOcrToken(
            // [OCR 추가]
            id: '$id-fallback', // [OCR 추가]
            text: line.text, // [OCR 추가]
            bounds: line.boundingBox, // [OCR 추가]
            angle: line.angle, // [OCR 추가]
          ), // [OCR 추가]
        ); // [OCR 추가]
      } // [OCR 추가]
      rows.add(
        // [OCR 추가]
        ReceiptOcrRow(
          // [OCR 추가]
          id: id, // [OCR 추가]
          text: line.text, // [OCR 추가]
          bounds: line.boundingBox, // [OCR 추가]
          tokens: tokens, // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return buildReceiptOcrResult(
    // [OCR 추가]
    text: recognized.text, // [OCR 추가]
    photoPath: path, // [OCR 추가]
    photoBytes: photoBytes, // [OCR 추가]
    rows: rows, // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]
