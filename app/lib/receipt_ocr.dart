import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]

/// [OCR 추가] 원본 OCR 단어와 사진 픽셀 좌표를 보존한다.
class ReceiptOcrToken {
  // [OCR 추가]
  const ReceiptOcrToken({
    // [OCR 추가]
    required this.id, // [OCR 추가]
    required this.text, // [OCR 추가]
    required this.bounds, // [OCR 추가]
    this.angle, // [OCR 추가]
  }); // [OCR 추가]
  final double? angle; // [OCR 추가]
  final String id; // [OCR 추가]
  final String text; // [OCR 추가]
  final Rect bounds; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] OCR 줄의 원문과 단어를 보관하며, 다른 줄의 숫자는 합치지 않는다.
class ReceiptOcrRow {
  // [OCR 추가]
  ReceiptOcrRow({
    // [OCR 추가]
    required this.id, // [OCR 추가]
    required this.text, // [OCR 추가]
    required this.bounds, // [OCR 추가]
    required List<ReceiptOcrToken> tokens, // [OCR 추가]
  }) : tokens = List.unmodifiable(tokens); // [OCR 추가]
  final String id; // [OCR 추가]
  final String text; // [OCR 추가]
  final Rect bounds; // [OCR 추가]
  final List<ReceiptOcrToken> tokens; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 같은 값도 원본 위치별 ID로 구분한다. 수정은 이후 선택 단계의 사본에서 수행한다.
class ReceiptOcrCandidate {
  // [OCR 추가]
  const ReceiptOcrCandidate({
    // [OCR 추가]
    required this.id, // [OCR 추가]
    required this.text, // [OCR 추가]
    required this.bounds, // [OCR 추가]
    this.number, // [OCR 추가]
    this.isMergedName = false, // [OCR 추가]
  }); // [OCR 추가]
  final String id; // [OCR 추가]
  final String text; // [OCR 추가]
  final Rect bounds; // [OCR 추가]
  final bool isMergedName; // [OCR 추가]
  final int? number; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 사진 경로는 이번 검토용 임시 파일이며 구매 기록이나 서버에 저장하지 않는다.
/// [OCR 수정] 좌표는 photoBytes가 있으면 최종 전처리 사진, 없으면 photoPath의 원본 사진 픽셀 좌표다.
class ReceiptOcrResult {
  // [OCR 추가]
  ReceiptOcrResult({
    // [OCR 추가]
    required this.text, // [OCR 추가]
    required this.photoPath, // [OCR 추가]
    this.photoBytes, // [OCR 추가]
    required List<ReceiptOcrRow> rows, // [OCR 추가]
    required List<ReceiptOcrCandidate> products, // [OCR 추가]
    required List<ReceiptOcrCandidate> numbers, // [OCR 추가]
  }) : rows = List.unmodifiable(rows), // [OCR 추가]
       products = List.unmodifiable(products), // [OCR 추가]
       numbers = List.unmodifiable(numbers); // [OCR 추가]
  final String text; // [OCR 추가]
  // [OCR 추가] 확대·회전한 전처리 사진은 검토 동안만 메모리에 보관한다. 원본 파일과 저장·서버 모델은 바꾸지 않는다.
  final Uint8List? photoBytes; // [OCR 추가]
  final String photoPath; // [OCR 추가]
  final List<ReceiptOcrRow> rows; // [OCR 추가]
  final List<ReceiptOcrCandidate> products; // [OCR 추가]
  final List<ReceiptOcrCandidate> numbers; // [OCR 추가]
} // [OCR 추가]

final _integer = RegExp(r'^[₩￦]?(-?(?:\d{1,3}(?:,\d{3})+|\d+))원?$'); // [OCR 추가]
final _letters = RegExp(r'[가-힣A-Za-z]'); // [OCR 추가]

/// [OCR 추가] 숫자 10자리 이상에 영문자 하나만 붙은 코드는 상품명에서 제외한다. 한글 이름은 유지한다.
bool receiptIsNumericCode(String text) {
  // [OCR 추가]
  return RegExp(r'[0-9]').allMatches(text).length >= 10 && // [OCR 추가]
      RegExp(r'[A-Za-z]').allMatches(text).length == 1 && // [OCR 추가]
      !RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]').hasMatch(text); // [OCR 추가]
} // [OCR 추가]

// [OCR 추가] 머리글과 세금 경계가 같은 기준으로 열별 글줄을 한 사진 행으로 비교한다.
List<({String text, Rect bounds})> _receiptRowBands(List<ReceiptOcrRow> rows) {
  final validRows =
      rows
          .where((row) => row.bounds.isFinite && !row.bounds.isEmpty)
          .toList() // [OCR 수정]
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top)); // [OCR 수정]
  final groups = <List<ReceiptOcrRow>>[]; // [OCR 수정]
  // ML Kit가 열별로 나눈 줄을 먼저 같은 사진 행으로 모은다.
  for (final row in validRows) {
    // [OCR 수정]
    if (groups.isEmpty) {
      // [OCR 수정]
      groups.add([row]); // [OCR 수정]
      continue; // [OCR 수정]
    } // [OCR 수정]
    final anchor = groups.last.first.bounds; // [OCR 수정]
    final height = row.bounds.height < anchor.height
        ? row.bounds.height
        : anchor.height; // [OCR 수정]
    if ((row.bounds.center.dy - anchor.center.dy).abs() <= height * .65) {
      // [OCR 수정]
      groups.last.add(row); // [OCR 수정]
    } else {
      // [OCR 수정]
      groups.add([row]); // [OCR 수정]
    } // [OCR 수정]
  } // [OCR 수정]
  return groups.map((group) {
    final words = List<ReceiptOcrRow>.of(group)
      ..sort(
        (a, b) => a.bounds.left.compareTo(b.bounds.left),
      ); // [OCR 추가] 기울기로 글자의 위쪽 순서가 바뀌어도 단어는 왼쪽부터 연결한다.
    return (
      text: words.map((row) => row.text).join().replaceAll(RegExp(r'\s+'), ''),
      bounds: group
          .map((row) => row.bounds)
          .reduce((a, b) => a.expandToInclude(b)),
    );
  }).toList(); // [OCR 수정]
}

/// [OCR 수정] 수량과 상품명/단가/금액 중 하나가 한 행 또는 붙은 두 행에 있으면 마지막 행 하단을 반환한다.
double? receiptProductStartBelowHeader(List<ReceiptOcrRow> rows) {
  final bands = _receiptRowBands(rows); // [OCR 수정]
  const labels = ['단가', '수량', '금액', '상품코드', '상품명']; // [OCR 수정]
  bool hasHeaderPair(String text) =>
      text.contains('수량') && // [OCR 수정]
      const ['상품명', '단가', '금액'].any(text.contains); // [OCR 수정]
  for (var index = 0; index < bands.length; index++) {
    // [OCR 수정]
    final first = bands[index]; // [OCR 수정]
    if (index + 1 < bands.length) {
      // [OCR 수정]
      final second = bands[index + 1]; // [OCR 수정]
      final height =
          first.bounds.height <
              second
                  .bounds
                  .height // [OCR 수정]
          ? first.bounds.height
          : second.bounds.height; // [OCR 수정]
      final gap = second.bounds.top - first.bounds.bottom; // [OCR 수정]
      // 바로 붙은 두 행만 묶는다. 첫 행에 쌍이 있어도 다음 머리글 행까지 제외해야 한다.
      if (gap <= height * .5 &&
          labels.any(first.text.contains) && // [OCR 수정]
          labels.any(second.text.contains) &&
          hasHeaderPair(first.text + second.text)) {
        // [OCR 수정]
        return second.bounds.bottom; // [OCR 수정]
      } // [OCR 수정]
    } // [OCR 수정]
    if (hasHeaderPair(first.text)) return first.bounds.bottom; // [OCR 수정]
  } // [OCR 수정]
  return null; // [OCR 수정]
} // [OCR 수정]

/// [OCR 수정] 세금 요약 또는 결제·대상·금액이 함께 있는 행 위에서 자동 탐색을 종료한다.
/// [OCR 수정] 떨어진 두 행을 합치지 않으며 비과세는 과세로 취급하지 않는다. 원문 후보는 변경하지 않는다.
double? receiptProductEndAboveTax(List<ReceiptOcrRow> rows) {
  final headerEnd = receiptProductStartBelowHeader(rows); // [OCR 추가]
  for (final band in _receiptRowBands(rows)) {
    if (headerEnd != null && band.bounds.top < headerEnd) continue; // [OCR 추가]
    final hasTax = RegExp(r'(?<!비)과세').hasMatch(band.text); // [OCR 수정]
    final hasTaxSummary =
        hasTax &&
        (band.text.contains('부가세') || band.text.contains('합계')); // [OCR 수정]
    final hasTaxableGoodsValue = RegExp(
      r'(?<!비)과세물품가액',
    ).hasMatch(band.text); // [OCR 추가]
    final hasPaymentTarget = const [
      '결제',
      '대상',
      '금액',
    ].every(band.text.contains); // [OCR 추가]
    if (hasTaxSummary || hasTaxableGoodsValue || hasPaymentTarget) {
      // [OCR 수정]
      return band.bounds.top; // [OCR 수정] 요약 행 자체와 아래 안내는 자동 OCR에서 제외한다.
    }
  }
  return null; // [OCR 수정] 요약 정지 조건이 없으면 기존 수량 간격 종료를 유지한다.
}

// [OCR 추가] 이유: 세로 회전한 글씨와 세로로 쌓인 글자만 후보에서 제외한다. 좁은 수량 1이나 짧은 가로 상품명은 남긴다.
Set<String> _verticalTokenIds(List<ReceiptOcrRow> rows) {
  // [OCR 추가]
  // [OCR 추가]
  final tokens = [
    // [OCR 추가]
    // [OCR 추가]
    for (final row in rows) // [OCR 추가]
      for (final token in row.tokens) // [OCR 추가]
        if (token.bounds.isFinite && !token.bounds.isEmpty) token, // [OCR 추가]
  ]; // [OCR 추가]
  final vertical = <String>{}; // [OCR 추가]
  for (final token in tokens) {
    // [OCR 추가]
    // [OCR 추가]
    final angle = token.angle; // [OCR 추가]
    final degrees =
        angle == null ||
            !angle
                .isFinite // [OCR 추가]
        ? null // [OCR 추가]
        : angle.abs() % 180; // [OCR 추가]
    final letters = RegExp(
      // [OCR 추가]
      r'[가-힣A-Za-z]', // [OCR 추가]
    ).allMatches(token.text).length; // [OCR 추가]
    final characters = RegExp(
      // [OCR 추가]
      r'[가-힣A-Za-z0-9]', // [OCR 추가]
    ).allMatches(token.text).length; // [OCR 추가]
    if ((degrees != null && degrees > 45 && degrees < 135) || // [OCR 추가]
        (letters >= 2 && // [OCR 추가]
            token.bounds.height > token.bounds.width * 1.5) || // [OCR 추가]
        (characters >= 2 && token.bounds.height > token.bounds.width * 2.5)) {
      // [OCR 추가]
      // [OCR 추가]
      // [OCR 추가]
      vertical.add(token.id); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  final characters = // [OCR 추가]
      tokens // [OCR 추가]
          .where(
            // [OCR 추가]
            (token) => RegExp(
              r'^[가-힣A-Za-z]$',
            ).hasMatch(token.text.trim()), // [OCR 추가]
          ) // [OCR 추가]
          .toList() // [OCR 추가]
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top)); // [OCR 추가]
  for (final first in characters) {
    // [OCR 추가]
    // [OCR 추가]
    final group = [first]; // [OCR 추가]
    for (final next in characters) {
      // [OCR 추가]
      // [OCR 추가]
      final previous = group.last; // [OCR 추가]
      final height = previous.bounds.height; // [OCR 추가]
      final distance = // [OCR 추가]
          next.bounds.center.dy - previous.bounds.center.dy; // [OCR 추가]
      final sameColumn = // [OCR 추가]
          (next.bounds.center.dx - first.bounds.center.dx).abs() <= // [OCR 추가]
          first.bounds.width * .35; // [OCR 추가]
      if (sameColumn && distance >= height * .75 && distance <= height * 1.35) {
        // [OCR 추가]
        // [OCR 추가]
        group.add(next); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    // [OCR 추가] 이유: 서로 다른 상품의 한 글자 이름을 없애지 않도록, 촘촘히 이어진 세 글자 이상인 열만 제외한다. 숫자 수량 열은 대상이 아니다.
    if (group.length >= 3) {
      // [OCR 추가]
      // [OCR 추가]
      vertical.addAll(group.map((token) => token.id)); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return vertical; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 부분 OCR의 세로 글씨를 빼고 가로 원문만 반환한다. 좌표가 없으면 방향을 추측하지 않는다.
String receiptHorizontalText(ReceiptOcrResult source) {
  // [OCR 추가]
  // [OCR 추가]
  if (source.rows.isEmpty) {
    // [OCR 추가]
    // [OCR 추가]
    return source.text; // [OCR 추가]
  } // [OCR 추가]
  final vertical = _verticalTokenIds(source.rows); // [OCR 추가]
  return [
    // [OCR 추가]
    // [OCR 추가]
    for (final row in source.rows) // [OCR 추가]
      row
          .tokens // [OCR 추가]
          .where((token) => !vertical.contains(token.id)) // [OCR 추가]
          .map((token) => token.text) // [OCR 추가]
          .join(' '), // [OCR 추가]
  ].where((line) => line.trim().isNotEmpty).join('\n'); // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 전체 원문은 그대로 남기고, 숫자는 토큰 전체가 정수인 경우에만 후보로 만든다.
/// [OCR 추가] 후보는 아직 상품이나 결제금액으로 확정하지 않는다.
ReceiptOcrResult buildReceiptOcrResult({
  // [OCR 추가]
  required String text, // [OCR 추가]
  required String photoPath, // [OCR 추가]
  Uint8List? photoBytes, // [OCR 추가]
  required List<ReceiptOcrRow> rows, // [OCR 추가]
}) {
  // [OCR 추가]
  final products = <ReceiptOcrCandidate>[]; // [OCR 추가]
  final numbers = <ReceiptOcrCandidate>[]; // [OCR 추가]
  final vertical = _verticalTokenIds(rows); // [OCR 추가]
  final productStart = receiptProductStartBelowHeader(rows); // [OCR 추가]
  for (final row in rows) {
    // [OCR 추가]
    final tokens = // [OCR 추가]
        row // [OCR 추가]
            .tokens // [OCR 추가]
            .where(
              // [OCR 추가]
              (token) =>
                  token.bounds.isFinite && // [OCR 추가]
                  !token.bounds.isEmpty && // [OCR 추가]
                  !vertical.contains(token.id), // [OCR 수정]
            ) // [OCR 추가]
            .toList() // [OCR 추가]
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left)); // [OCR 추가]
    for (var index = 0; index < tokens.length; index++) {
      // [OCR 추가]
      final token = tokens[index]; // [OCR 추가]
      var value = _normalizedNumberText(token.text); // [OCR 수정]
      var bounds = token.bounds; // [OCR 추가]
      var last = token; // [OCR 추가]
      // [OCR 추가] 콤마와 음수 부호가 별도 단어이면 가까운 조각만 결합한다. 수량 1과 금액 12000은 합치지 않는다.
      while (index + 1 < tokens.length) {
        // [OCR 추가]
        final next = tokens[index + 1]; // [OCR 추가]
        final nextText = _normalizedNumberText(next.text); // [OCR 수정]
        final joinsPunctuation = // [OCR 추가]
            value.endsWith(',') || // [OCR 추가]
            value == '-' || // [OCR 추가]
            nextText.startsWith(','); // [OCR 추가]
        if (!joinsPunctuation || // [OCR 추가]
            !_touchingNumberParts(last.bounds, next.bounds) || // [OCR 추가]
            !RegExp(r'^[-\d,]+$').hasMatch(value + nextText)) {
          // [OCR 추가]
          break; // [OCR 추가]
        } // [OCR 추가]
        value += nextText; // [OCR 추가]
        bounds = bounds.expandToInclude(next.bounds); // [OCR 추가]
        last = next; // [OCR 추가]
        index++; // [OCR 추가]
      } // [OCR 추가]
      final match = _integer.firstMatch(value); // [OCR 추가]
      final number = // [OCR 추가]
          match == // [OCR 추가]
              null // [OCR 추가]
          ? null // [OCR 추가]
          : int.tryParse(match.group(1)!.replaceAll(',', '')); // [OCR 추가]
      final candidate = ReceiptOcrCandidate(
        // [OCR 추가]
        id: token.id, // [OCR 추가]
        text: value, // [OCR 추가]
        bounds: bounds, // [OCR 추가]
        number: number, // [OCR 추가]
      ); // [OCR 추가]
      if (number != null) {
        // [OCR 추가]
        numbers.add(candidate); // [OCR 추가]
      } else if (_letters.hasMatch(value) && // [OCR 수정]
          !receiptIsNumericCode(value) && // [OCR 추가]
          !receiptIsNumericCode(row.text) && // [OCR 수정]
          (productStart == null || bounds.top >= productStart)) {
        // [OCR 추가]
        // [OCR 추가] 숫자와 영문자가 분리된 코드 행도 이름으로 만들지 않는다.
        // [OCR 추가]
        products.add(candidate); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return ReceiptOcrResult(
    // [OCR 추가]
    text: text, // [OCR 추가]
    photoPath: photoPath, // [OCR 추가]
    photoBytes: photoBytes, // [OCR 추가]
    rows: rows, // [OCR 추가]
    products: products, // [OCR 추가]
    numbers: numbers, // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

// [OCR 수정] 사용자 지정: 숫자만인 천 단위 점 표기는 콤마로 통일한다. 원문·좌표와 날짜·용량은 유지한다.
String _normalizedNumberText(String text) {
  var value = text.trim(); // [OCR 수정]
  if (RegExp(r'^[₩￦]?[-−－–]?\d{1,3}(?:\.\d{3})+원?$').hasMatch(value)) {
    value = value.replaceAll('.', ','); // [OCR 추가]
  } // [OCR 추가]
  if (!RegExp(r'^[₩￦−－–\-\d，,\s]+원?$').hasMatch(value)) {
    return value; // [OCR 수정]
  } // [OCR 수정]
  return value
      .replaceAll('，', ',')
      .replaceAll(RegExp('[−－–]'), '-')
      .replaceAll(RegExp(r'\s*,\s*'), ','); // [OCR 수정]
}

bool _touchingNumberParts(Rect left, Rect right) {
  // [OCR 추가]
  final height = // [OCR 추가]
      left.height < // [OCR 추가]
          right // [OCR 추가]
              .height // [OCR 추가]
      ? left // [OCR 추가]
            .height // [OCR 추가]
      : right.height; // [OCR 추가]
  final overlap = // [OCR 추가]
      (left.bottom < right.bottom ? left.bottom : right.bottom) - // [OCR 추가]
      (left.top > right.top ? left.top : right.top); // [OCR 추가]
  final gap = right.left - left.right; // [OCR 추가]
  return overlap >= height * .5 && // [OCR 추가]
      gap >= -height * .5 && // [OCR 추가]
      gap <= height * .6; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 첫 상품명의 왼쪽 시작점을 기준으로 같은 열의 아래 상품명 후보를 반환한다.
List<ReceiptOcrCandidate> receiptProductsBelow(
  // [OCR 추가]
  List<ReceiptOcrCandidate> products, // [OCR 추가]
  ReceiptOcrCandidate first, // [OCR 추가]
) {
  // [OCR 추가]
  final tolerance = first.bounds.height * 1.5; // [OCR 추가]
  final result = products.where((candidate) {
    // [OCR 추가]
    if (candidate.id == first.id) return true; // [OCR 추가]
    return (candidate.bounds.left - first.bounds.left).abs() <=
            tolerance && // [OCR 추가]
        candidate.bounds.center.dy > // [OCR 추가]
            first.bounds.center.dy + first.bounds.height * .5; // [OCR 추가]
  }).toList(); // [OCR 추가]
  result.sort(
    // [OCR 추가]
    (left, right) => left.bounds.top.compareTo(right.bounds.top), // [OCR 추가]
  ); // [OCR 추가]
  return result; // [OCR 추가]
} // [OCR 추가]

/// [OCR 수정] 천 단위 콤마·점 표기를 정수 금액으로 받고 할인 음수는 결제금액으로 확정하지 않는다.
int? receiptSelectionAmount(String text) {
  // [OCR 추가]
  final value = _normalizedNumberText(
    text,
  ); // [OCR 수정] 부분 OCR도 전체 OCR과 같은 천 단위 표기를 사용한다.
  if (!RegExp(r'^(?:\d{1,3}(?:,\d{3})+|\d+)$').hasMatch(value)) {
    // [OCR 추가]
    return null; // [OCR 추가]
  } // [OCR 추가]
  final number = int.tryParse(value.replaceAll(',', '')); // [OCR 추가]
  if (number == null || number < 0 || number > 9999999) return null; // [OCR 추가]
  return number; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 같은 행과 아래 두 OCR 행의 숫자를 오른쪽 우선·행 가까움 순서로 반환한다.
List<ReceiptOcrCandidate> receiptPricesNear(
  // [OCR 추가]
  ReceiptOcrResult source, // [OCR 추가]
  ReceiptOcrCandidate product, // [OCR 추가]
) {
  // [OCR 추가]
  final heights = [
    // [OCR 추가]
    for (final row in source.rows) // [OCR 추가]
      for (final token in row.tokens) // [OCR 추가]
        if (token.bounds.isFinite && !token.bounds.isEmpty)
          token.bounds.height, // [OCR 추가]
  ]..sort(); // [OCR 추가]
  final height =
      heights
          .isEmpty // [OCR 추가]
      ? product
            .bounds
            .height // [OCR 추가]
      : heights[heights.length ~/ 2]; // [OCR 추가]
  final tolerance = height * .6; // [OCR 추가]
  final tokenBounds = [
    // [OCR 수정]
    for (final row in source.rows) // [OCR 수정]
      for (final token in row.tokens) // [OCR 수정]
        if (token.bounds.isFinite && !token.bounds.isEmpty)
          token.bounds, // [OCR 수정]
  ]..sort((a, b) => a.center.dy.compareTo(b.center.dy)); // [OCR 수정]
  final rows = <({double firstCenter, Rect bounds})>[]; // [OCR 수정]
  for (final bounds in tokenBounds) {
    // [OCR 수정]
    if (rows.isEmpty || bounds.center.dy - rows.last.firstCenter > tolerance) {
      // [OCR 수정]
      rows.add((firstCenter: bounds.center.dy, bounds: bounds)); // [OCR 수정]
    } else {
      // [OCR 수정]
      final previous = rows.last; // [OCR 추가]
      // [OCR 추가] 행 영역은 포함된 모든 글자의 가장 위쪽부터 가장 아래쪽까지 보존한다.
      rows[rows.length - 1] = (
        // [OCR 추가]
        firstCenter: previous.firstCenter, // [OCR 추가]
        bounds: previous.bounds.expandToInclude(bounds), // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 수정]
  } // [OCR 수정]
  var productRow = -1; // [OCR 추가]
  var closestDistance = double.infinity; // [OCR 추가]
  for (var index = 0; index < rows.length; index++) {
    // [OCR 추가]
    final distance = (rows[index].firstCenter - product.bounds.center.dy)
        .abs(); // [OCR 추가]
    if (distance < closestDistance) {
      // [OCR 추가]
      closestDistance = distance; // [OCR 추가]
      productRow = index; // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  // [OCR 수정] 이미 묶은 상품명 행의 다음 두 행을 사용한다. 별도 Y 경계로 실제 첫 행을 건너뛰지 않는다.
  final below = rows
      .skip(productRow + 1)
      .take(2)
      .map((row) => row.bounds)
      .toList(); // [OCR 수정]
  bool sameRow(ReceiptOcrCandidate candidate) => // [OCR 추가]
      (candidate.bounds.center.dy - product.bounds.center.dy)
          .abs() <= // [OCR 추가]
      tolerance; // [OCR 추가]
  final result = source.numbers.where((candidate) {
    // [OCR 추가]
    if (candidate.number == null || // [OCR 추가]
        candidate.number! < 0 || // [OCR 추가]
        candidate.number! > 9999999) {
      // [OCR 추가]
      return false; // [OCR 추가]
    } // [OCR 추가]
    if (sameRow(candidate)) return true; // [OCR 추가]
    return candidate.bounds.center.dy > product.bounds.center.dy && // [OCR 추가]
        below.any(
          // [OCR 추가]
          (bounds) => // [OCR 수정]
              candidate.bounds.center.dy >= bounds.top && // [OCR 수정]
              candidate.bounds.center.dy <= bounds.bottom, // [OCR 수정]
        ); // [OCR 추가]
  }).toList(); // [OCR 추가]
  result.sort((left, right) {
    // [OCR 추가]
    final leftPriority =
        left.bounds.left >=
            product
                .bounds
                .right // [OCR 추가]
        ? 0 // [OCR 추가]
        : 1; // [OCR 추가]
    final rightPriority =
        right.bounds.left >=
            product
                .bounds
                .right // [OCR 추가]
        ? 0 // [OCR 추가]
        : 1; // [OCR 추가]
    final byRight = leftPriority.compareTo(rightPriority); // [OCR 추가]
    if (byRight != 0) return byRight; // [OCR 추가]
    final byRow = (sameRow(left) ? 0 : 1).compareTo(
      // [OCR 추가]
      sameRow(right) ? 0 : 1, // [OCR 추가]
    ); // [OCR 추가]
    if (byRow != 0) return byRow; // [OCR 추가]
    final byDistance =
        (left.bounds.center.dy - product.bounds.center.dy) // [OCR 추가]
            .abs() // [OCR 추가]
            .compareTo(
              // [OCR 추가]
              (right.bounds.center.dy - product.bounds.center.dy)
                  .abs(), // [OCR 추가]
            ); // [OCR 추가]
    if (byDistance != 0) return byDistance; // [OCR 추가]
    return right.bounds.right.compareTo(left.bounds.right); // [OCR 추가]
  }); // [OCR 추가]
  return result; // [OCR 추가]
} // [OCR 추가]
