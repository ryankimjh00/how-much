import 'dart:math' as math; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]

bool _sameNameRow(Rect anchor, Rect candidate) {
  // [OCR 추가]
  // [OCR 추가]
  final height = math.min(anchor.height, candidate.height); // [OCR 추가]
  return (anchor.top - candidate.top).abs() <= height * .35 && // [OCR 추가]
      (anchor.center.dy - candidate.center.dy).abs() <= height * .4; // [OCR 추가]
} // [OCR 추가]

String _joinName(String first, String second) {
  // [OCR 추가]
  // [OCR 추가]
  if (first.contains(second)) return first; // [OCR 추가]
  if (second.contains(first)) return second; // [OCR 추가]
  for (
    // [OCR 추가]
    var length = math.min(first.length, second.length); // [OCR 추가]
    length > 0; // [OCR 추가]
    length-- // [OCR 추가]
  ) {
    // [OCR 추가]
    // [OCR 추가]
    if (first.substring(first.length - length) == second.substring(0, length)) {
      // [OCR 추가]
      return first + second.substring(length); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return '$first $second'; // [OCR 추가]
} // [OCR 추가]

ReceiptOcrResult _withProducts(
  // [OCR 추가]
  ReceiptOcrResult source, // [OCR 추가]
  List<ReceiptOcrCandidate> products, // [OCR 추가]
) => ReceiptOcrResult(
  // [OCR 추가]
  text: source.text, // [OCR 추가]
  photoPath: source.photoPath, // [OCR 추가]
  photoBytes: source.photoBytes, // [OCR 추가]
  rows: source.rows, // [OCR 추가]
  products: products, // [OCR 추가]
  numbers: source.numbers, // [OCR 추가]
); // [OCR 추가]

/// [OCR 추가] 같은 행의 가까운 이름만 묶으며 원본 OCR 줄·단어와 숫자 좌표는 유지한다. 숫자·기호 영역을 넘어 합치지 않는다.
ReceiptOcrResult mergeReceiptProductRegions(ReceiptOcrResult source) {
  // [OCR 추가]
  // [OCR 추가]
  final candidates =
      List<ReceiptOcrCandidate>.of(source.products) // [OCR 추가]
        ..sort((a, b) {
          // [OCR 추가]
          final top = a.bounds.top.compareTo(b.bounds.top); // [OCR 추가]
          return top == 0
              ? a.bounds.left.compareTo(b.bounds.left)
              : top; // [OCR 추가]
        }); // [OCR 추가]
  final groups = <ReceiptOcrCandidate>[]; // [OCR 추가]
  final anchors = <String, Rect>{}; // [OCR 추가]
  final barriers = [
    // [OCR 추가] 이유: 정규화한 금액도 이름 조각 사이에 있으면 병합을 막는다. 원·통화 기호가 있는 숫자 후보도 포함한다.
    for (final number in source.numbers) // [OCR 추가]
      if (number.bounds.isFinite && !number.bounds.isEmpty)
        number.bounds, // [OCR 추가]
    for (final row in source.rows) // [OCR 추가]
      for (final token in row.tokens) // [OCR 추가]
        if (token.bounds.isFinite && // [OCR 추가]
            !token.bounds.isEmpty && // [OCR 추가]
            RegExp(
              r'^[+＋\-−－–\d,，\s]+$',
            ).hasMatch(token.text.trim()) && // [OCR 추가]
            token.text.trim().isNotEmpty) // [OCR 추가]
          token.bounds, // [OCR 추가]
  ]; // [OCR 추가]
  for (final candidate in candidates) {
    // [OCR 추가]
    // [OCR 추가]
    var matched = -1; // [OCR 추가]
    var bestGap = double.infinity; // [OCR 추가]
    for (var index = 0; index < groups.length; index++) {
      // [OCR 추가]
      // [OCR 추가]
      final group = groups[index]; // [OCR 추가]
      // [OCR 추가] 이유: 누적 박스의 높이가 커져도 첫 이름의 행을 기준으로 판단해 이웃 행으로 병합이 번지지 않는다.
      if (!_sameNameRow(anchors[group.id]!, candidate.bounds)) {
        // [OCR 추가]
        continue; // [OCR 추가]
      } // [OCR 추가]
      final left =
          group.bounds.left <=
              candidate
                  .bounds
                  .left // [OCR 추가]
          ? group
                .bounds // [OCR 추가]
          : candidate.bounds; // [OCR 추가]
      final right =
          group.bounds.left <=
              candidate
                  .bounds
                  .left // [OCR 추가]
          ? candidate
                .bounds // [OCR 추가]
          : group.bounds; // [OCR 추가]
      final gap = math.max(0.0, right.left - left.right); // [OCR 추가]
      if (gap > math.max(left.height, right.height) * 2) continue; // [OCR 추가]
      final start = math.min(left.right, right.left); // [OCR 추가]
      final end = math.max(left.right, right.left); // [OCR 추가]
      if (barriers.any(
        // [OCR 추가]
        (bounds) => // [OCR 추가]
            bounds.center.dx > start && // [OCR 추가]
            bounds.center.dx < end && // [OCR 추가]
            (bounds.center.dy - anchors[group.id]!.center.dy)
                    .abs() <= // [OCR 추가]
                math.max(bounds.height, anchors[group.id]!.height) *
                    .6, // [OCR 추가]
      )) {
        // [OCR 추가]
        continue; // [OCR 추가]
      } // [OCR 추가]
      if (gap < bestGap) {
        // [OCR 추가]
        matched = index; // [OCR 추가]
        bestGap = gap; // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    if (matched < 0) {
      // [OCR 추가]
      groups.add(candidate); // [OCR 추가]
      anchors[candidate.id] = candidate.bounds; // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    final current = groups[matched]; // [OCR 추가]
    final text =
        candidate.bounds.left <
            current
                .bounds
                .left // [OCR 추가]
        ? _joinName(candidate.text, current.text) // [OCR 추가]
        : _joinName(current.text, candidate.text); // [OCR 추가]
    groups[matched] = ReceiptOcrCandidate(
      // [OCR 추가]
      id: current.id, // [OCR 추가]
      text: text, // [OCR 추가]
      bounds: current.bounds.expandToInclude(candidate.bounds), // [OCR 추가]
      isMergedName: true, // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]
  groups.sort((a, b) {
    // [OCR 추가]
    final top = a.bounds.top.compareTo(b.bounds.top); // [OCR 추가]
    return top == 0 ? a.bounds.left.compareTo(b.bounds.left) : top; // [OCR 추가]
  }); // [OCR 추가]
  return _withProducts(source, groups); // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 합친 이름 영역만 다시 읽는다. 빈값·숫자만인 값·예외는 합치기 전 이름 정보를 유지하며 다음 영역을 계속 처리한다.
Future<ReceiptOcrResult> rereadMergedProductNames(
  // [OCR 추가]
  ReceiptOcrResult source, // [OCR 추가]
  Future<String> Function(Rect) recognize, // [OCR 추가]
) async {
  // [OCR 추가]
  // [OCR 추가]
  final products = <ReceiptOcrCandidate>[]; // [OCR 추가]
  for (final product in source.products) {
    // [OCR 추가]
    // [OCR 추가]
    var text = product.text; // [OCR 추가]
    if (product.isMergedName) {
      // [OCR 추가]
      // [OCR 추가]
      try {
        // [OCR 추가]
        // [OCR 추가]
        final recognized = (await recognize(
          // [OCR 추가]
          product.bounds, // [OCR 추가]
        )).replaceAll(RegExp(r'\s+'), ' ').trim(); // [OCR 추가]
        if (recognized.isNotEmpty && // [OCR 추가]
            recognized.length <= 50 && // [OCR 추가]
            RegExp(r'[가-힣A-Za-z]').hasMatch(recognized)) {
          // [OCR 추가]
          text = recognized; // [OCR 추가]
        } // [OCR 추가]
      } catch (_) {
        // [OCR 추가]
        /* 실패해도 기존 이름·영역·ID를 보존한다. */ // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    products.add(
      // [OCR 추가]
      ReceiptOcrCandidate(
        // [OCR 추가]
        id: product.id, // [OCR 추가]
        text: text, // [OCR 추가]
        bounds: product.bounds, // [OCR 추가]
        isMergedName: product.isMergedName, // [OCR 추가]
      ), // [OCR 추가]
    ); // [OCR 추가]
  } // [OCR 추가]
  return _withProducts(source, products); // [OCR 추가]
} // [OCR 추가]
