// [OCR 수정] 영수증 원문·좌표에서 상품명·숫자 후보를 만들고 같은 열·주변 행의 후보를 찾는다.
import 'dart:typed_data';
import 'dart:ui';

/// [OCR 추가] 원본 OCR 단어와 사진 픽셀 좌표를 보존한다.
class ReceiptOcrToken {
  const ReceiptOcrToken({
    required this.id,
    required this.text,
    required this.bounds,
    this.angle,
  });
  final double? angle;
  final String id;
  final String text;
  final Rect bounds;
}

/// [OCR 추가] OCR 줄의 원문과 단어를 보관하며, 다른 줄의 숫자는 합치지 않는다.
class ReceiptOcrRow {
  ReceiptOcrRow({
    required this.id,
    required this.text,
    required this.bounds,
    required List<ReceiptOcrToken> tokens,
  }) : tokens = List.unmodifiable(tokens);
  final String id;
  final String text;
  final Rect bounds;
  final List<ReceiptOcrToken> tokens;
}

/// [OCR 추가] 같은 값도 원본 위치별 ID로 구분한다. 수정은 이후 선택 단계의 사본에서 수행한다.
class ReceiptOcrCandidate {
  const ReceiptOcrCandidate({
    required this.id,
    required this.text,
    required this.bounds,
    this.number,
    this.isMergedName = false,
  });
  final String id;
  final String text;
  final Rect bounds;
  final bool isMergedName;
  final int? number;
}

/// [OCR 추가] 사진 경로는 이번 검토용 임시 파일이며 구매 기록이나 서버에 저장하지 않는다.
/// [OCR 수정] 좌표는 photoBytes가 있으면 최종 전처리 사진, 없으면 photoPath의 원본 사진 픽셀 좌표다.
class ReceiptOcrResult {
  ReceiptOcrResult({
    required this.text,
    required this.photoPath,
    this.photoBytes,
    required List<ReceiptOcrRow> rows,
    required List<ReceiptOcrCandidate> products,
    required List<ReceiptOcrCandidate> numbers,
  }) : rows = List.unmodifiable(rows),
       products = List.unmodifiable(products),
       numbers = List.unmodifiable(numbers);
  final String text;
  // [OCR 추가] 확대·회전한 전처리 사진은 검토 동안만 메모리에 보관한다. 원본 파일과 저장·서버 모델은 바꾸지 않는다.
  final Uint8List? photoBytes;
  final String photoPath;
  final List<ReceiptOcrRow> rows;
  final List<ReceiptOcrCandidate> products;
  final List<ReceiptOcrCandidate> numbers;
}

final _integer = RegExp(r'^[₩￦]?(-?(?:\d{1,3}(?:,\d{3})+|\d+))원?$');
final _letters = RegExp(r'[가-힣A-Za-z]');

/// [OCR 추가] 숫자 10자리 이상에 영문자 하나만 붙은 코드는 상품명에서 제외한다. 한글 이름은 유지한다.
bool receiptIsNumericCode(String text) {
  return RegExp(r'[0-9]').allMatches(text).length >= 10 &&
      RegExp(r'[A-Za-z]').allMatches(text).length == 1 &&
      !RegExp(r'[가-힣ㄱ-ㅎㅏ-ㅣ]').hasMatch(text);
}

// [OCR 추가] 머리글과 세금 경계가 같은 기준으로 열별 글줄을 한 사진 행으로 비교한다.
List<({String text, Rect bounds})> _receiptRowBands(List<ReceiptOcrRow> rows) {
  final validRows =
      rows.where((row) => row.bounds.isFinite && !row.bounds.isEmpty).toList()
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  final groups = <List<ReceiptOcrRow>>[];
  // ML Kit가 열별로 나눈 줄을 먼저 같은 사진 행으로 모은다.
  for (final row in validRows) {
    if (groups.isEmpty) {
      groups.add([row]);
      continue;
    }
    final anchor = groups.last.first.bounds;
    final height = row.bounds.height < anchor.height
        ? row.bounds.height
        : anchor.height;
    if ((row.bounds.center.dy - anchor.center.dy).abs() <= height * .65) {
      groups.last.add(row);
    } else {
      groups.add([row]);
    }
  }
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
  }).toList();
}

/// [OCR 수정] 수량과 상품명/단가/금액 중 하나가 한 행 또는 붙은 두 행에 있으면 마지막 행 하단을 반환한다.
double? receiptProductStartBelowHeader(List<ReceiptOcrRow> rows) {
  final bands = _receiptRowBands(rows);
  const labels = ['단가', '수량', '금액', '상품코드', '상품명'];
  bool hasHeaderPair(String text) =>
      text.contains('수량') && const ['상품명', '단가', '금액'].any(text.contains);
  for (var index = 0; index < bands.length; index++) {
    final first = bands[index];
    if (index + 1 < bands.length) {
      final second = bands[index + 1];
      final height = first.bounds.height < second.bounds.height
          ? first.bounds.height
          : second.bounds.height;
      final gap = second.bounds.top - first.bounds.bottom;
      // 바로 붙은 두 행만 묶는다. 첫 행에 쌍이 있어도 다음 머리글 행까지 제외해야 한다.
      if (gap <= height * .5 &&
          labels.any(first.text.contains) &&
          labels.any(second.text.contains) &&
          hasHeaderPair(first.text + second.text)) {
        return second.bounds.bottom;
      }
    }
    if (hasHeaderPair(first.text)) return first.bounds.bottom;
  }
  return null;
}

/// [OCR 수정] 세금 요약 또는 결제·대상·금액이 함께 있는 행 위에서 자동 탐색을 종료한다.
/// [OCR 수정] 떨어진 두 행을 합치지 않으며 비과세는 과세로 취급하지 않는다. 원문 후보는 변경하지 않는다.
double? receiptProductEndAboveTax(List<ReceiptOcrRow> rows) {
  final headerEnd = receiptProductStartBelowHeader(rows);
  for (final band in _receiptRowBands(rows)) {
    if (headerEnd != null && band.bounds.top < headerEnd) continue;
    final hasTax = RegExp(r'(?<!비)과세').hasMatch(band.text);
    final hasTaxSummary =
        hasTax && (band.text.contains('부가세') || band.text.contains('합계'));
    final hasTaxableGoodsValue = RegExp(r'(?<!비)과세물품가액').hasMatch(band.text);
    final hasPaymentTarget = const ['결제', '대상', '금액'].every(band.text.contains);
    if (hasTaxSummary || hasTaxableGoodsValue || hasPaymentTarget) {
      return band.bounds.top; // [OCR 수정] 요약 행 자체와 아래 안내는 자동 OCR에서 제외한다.
    }
  }
  return null; // [OCR 수정] 요약 정지 조건이 없으면 기존 수량 간격 종료를 유지한다.
}

// [OCR 추가] 이유: 세로 회전한 글씨와 세로로 쌓인 글자만 후보에서 제외한다. 좁은 수량 1이나 짧은 가로 상품명은 남긴다.
Set<String> _verticalTokenIds(List<ReceiptOcrRow> rows) {
  final tokens = [
    for (final row in rows)
      for (final token in row.tokens)
        if (token.bounds.isFinite && !token.bounds.isEmpty) token,
  ];
  final vertical = <String>{};
  for (final token in tokens) {
    final angle = token.angle;
    final degrees = angle == null || !angle.isFinite ? null : angle.abs() % 180;
    final letters = RegExp(r'[가-힣A-Za-z]').allMatches(token.text).length;
    final characters = RegExp(r'[가-힣A-Za-z0-9]').allMatches(token.text).length;
    if ((degrees != null && degrees > 45 && degrees < 135) ||
        (letters >= 2 && token.bounds.height > token.bounds.width * 1.5) ||
        (characters >= 2 && token.bounds.height > token.bounds.width * 2.5)) {
      vertical.add(token.id);
    }
  }
  final characters =
      tokens
          .where(
            (token) => RegExp(r'^[가-힣A-Za-z]$').hasMatch(token.text.trim()),
          )
          .toList()
        ..sort((a, b) => a.bounds.top.compareTo(b.bounds.top));
  for (final first in characters) {
    final group = [first];
    for (final next in characters) {
      final previous = group.last;
      final height = previous.bounds.height;
      final distance = next.bounds.center.dy - previous.bounds.center.dy;
      final sameColumn =
          (next.bounds.center.dx - first.bounds.center.dx).abs() <=
          first.bounds.width * .35;
      if (sameColumn && distance >= height * .75 && distance <= height * 1.35) {
        group.add(next);
      }
    }
    // [OCR 추가] 이유: 서로 다른 상품의 한 글자 이름을 없애지 않도록, 촘촘히 이어진 세 글자 이상인 열만 제외한다. 숫자 수량 열은 대상이 아니다.
    if (group.length >= 3) {
      vertical.addAll(group.map((token) => token.id));
    }
  }
  return vertical;
}

/// [OCR 추가] 부분 OCR의 세로 글씨를 빼고 가로 원문만 반환한다. 좌표가 없으면 방향을 추측하지 않는다.
String receiptHorizontalText(ReceiptOcrResult source) {
  if (source.rows.isEmpty) {
    return source.text;
  }
  final vertical = _verticalTokenIds(source.rows);
  return [
    for (final row in source.rows)
      row.tokens
          .where((token) => !vertical.contains(token.id))
          .map((token) => token.text)
          .join(' '),
  ].where((line) => line.trim().isNotEmpty).join('\n');
}

/// [OCR 추가] 전체 원문은 그대로 남기고, 숫자는 토큰 전체가 정수인 경우에만 후보로 만든다.
/// [OCR 추가] 후보는 아직 상품이나 결제금액으로 확정하지 않는다.
ReceiptOcrResult buildReceiptOcrResult({
  required String text,
  required String photoPath,
  Uint8List? photoBytes,
  required List<ReceiptOcrRow> rows,
}) {
  final products = <ReceiptOcrCandidate>[];
  final numbers = <ReceiptOcrCandidate>[];
  final vertical = _verticalTokenIds(rows);
  final productStart = receiptProductStartBelowHeader(rows);
  for (final row in rows) {
    final tokens =
        row.tokens
            .where(
              (token) =>
                  token.bounds.isFinite &&
                  !token.bounds.isEmpty &&
                  !vertical.contains(token.id),
            )
            .toList()
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
    for (var index = 0; index < tokens.length; index++) {
      final token = tokens[index];
      var value = _normalizedNumberText(token.text);
      var bounds = token.bounds;
      var last = token;
      // [OCR 추가] 콤마와 음수 부호가 별도 단어이면 가까운 조각만 결합한다. 수량 1과 금액 12000은 합치지 않는다.
      while (index + 1 < tokens.length) {
        final next = tokens[index + 1];
        final nextText = _normalizedNumberText(next.text);
        final joinsPunctuation =
            value.endsWith(',') || value == '-' || nextText.startsWith(',');
        if (!joinsPunctuation ||
            !_touchingNumberParts(last.bounds, next.bounds) ||
            !RegExp(r'^[-\d,]+$').hasMatch(value + nextText)) {
          break;
        }
        value += nextText;
        bounds = bounds.expandToInclude(next.bounds);
        last = next;
        index++;
      }
      final match = _integer.firstMatch(value);
      final number = match == null
          ? null
          : int.tryParse(match.group(1)!.replaceAll(',', ''));
      final candidate = ReceiptOcrCandidate(
        id: token.id,
        text: value,
        bounds: bounds,
        number: number,
      );
      if (number != null) {
        numbers.add(candidate);
      } else if (_letters.hasMatch(value) &&
          !receiptIsNumericCode(value) &&
          !receiptIsNumericCode(row.text) &&
          (productStart == null || bounds.top >= productStart)) {
        // [OCR 추가] 숫자와 영문자가 분리된 코드 행도 이름으로 만들지 않는다.
        products.add(candidate);
      }
    }
  }
  return ReceiptOcrResult(
    text: text,
    photoPath: photoPath,
    photoBytes: photoBytes,
    rows: rows,
    products: products,
    numbers: numbers,
  );
}

// [OCR 수정] 사용자 지정: 숫자만인 천 단위 점 표기는 콤마로 통일한다. 원문·좌표와 날짜·용량은 유지한다.
String _normalizedNumberText(String text) {
  var value = text.trim();
  if (RegExp(r'^[₩￦]?[-−－–]?\d{1,3}(?:\.\d{3})+원?$').hasMatch(value)) {
    value = value.replaceAll('.', ',');
  }
  if (!RegExp(r'^[₩￦−－–\-\d，,\s]+원?$').hasMatch(value)) {
    return value;
  }
  return value
      .replaceAll('，', ',')
      .replaceAll(RegExp('[−－–]'), '-')
      .replaceAll(RegExp(r'\s*,\s*'), ',');
}

bool _touchingNumberParts(Rect left, Rect right) {
  final height = left.height < right.height ? left.height : right.height;
  final overlap =
      (left.bottom < right.bottom ? left.bottom : right.bottom) -
      (left.top > right.top ? left.top : right.top);
  final gap = right.left - left.right;
  return overlap >= height * .5 && gap >= -height * .5 && gap <= height * .6;
}

/// [OCR 추가] 첫 상품명의 왼쪽 시작점을 기준으로 같은 열의 아래 상품명 후보를 반환한다.
List<ReceiptOcrCandidate> receiptProductsBelow(
  List<ReceiptOcrCandidate> products,
  ReceiptOcrCandidate first,
) {
  final tolerance = first.bounds.height * 1.5;
  final result = products.where((candidate) {
    if (candidate.id == first.id) return true;
    return (candidate.bounds.left - first.bounds.left).abs() <= tolerance &&
        candidate.bounds.center.dy >
            first.bounds.center.dy + first.bounds.height * .5;
  }).toList();
  result.sort((left, right) => left.bounds.top.compareTo(right.bounds.top));
  return result;
}

/// [OCR 수정] 천 단위 콤마·점 표기를 정수 금액으로 받고 할인 음수는 결제금액으로 확정하지 않는다.
int? receiptSelectionAmount(String text) {
  final value = _normalizedNumberText(
    text,
  ); // [OCR 수정] 부분 OCR도 전체 OCR과 같은 천 단위 표기를 사용한다.
  if (!RegExp(r'^(?:\d{1,3}(?:,\d{3})+|\d+)$').hasMatch(value)) {
    return null;
  }
  final number = int.tryParse(value.replaceAll(',', ''));
  if (number == null || number < 0 || number > 9999999) return null;
  return number;
}

/// [OCR 추가] 같은 행과 아래 두 OCR 행의 숫자를 오른쪽 우선·행 가까움 순서로 반환한다.
List<ReceiptOcrCandidate> receiptPricesNear(
  ReceiptOcrResult source,
  ReceiptOcrCandidate product,
) {
  final heights = [
    for (final row in source.rows)
      for (final token in row.tokens)
        if (token.bounds.isFinite && !token.bounds.isEmpty) token.bounds.height,
  ]..sort();
  final height = heights.isEmpty
      ? product.bounds.height
      : heights[heights.length ~/ 2];
  final tolerance = height * .6;
  final tokenBounds = [
    for (final row in source.rows)
      for (final token in row.tokens)
        if (token.bounds.isFinite && !token.bounds.isEmpty) token.bounds,
  ]..sort((a, b) => a.center.dy.compareTo(b.center.dy));
  final rows = <({double firstCenter, Rect bounds})>[];
  for (final bounds in tokenBounds) {
    if (rows.isEmpty || bounds.center.dy - rows.last.firstCenter > tolerance) {
      rows.add((firstCenter: bounds.center.dy, bounds: bounds));
    } else {
      final previous = rows.last;
      // [OCR 추가] 행 영역은 포함된 모든 글자의 가장 위쪽부터 가장 아래쪽까지 보존한다.
      rows[rows.length - 1] = (
        firstCenter: previous.firstCenter,
        bounds: previous.bounds.expandToInclude(bounds),
      );
    }
  }
  var productRow = -1;
  var closestDistance = double.infinity;
  for (var index = 0; index < rows.length; index++) {
    final distance = (rows[index].firstCenter - product.bounds.center.dy).abs();
    if (distance < closestDistance) {
      closestDistance = distance;
      productRow = index;
    }
  }
  // [OCR 수정] 이미 묶은 상품명 행의 다음 두 행을 사용한다. 별도 Y 경계로 실제 첫 행을 건너뛰지 않는다.
  final below = rows
      .skip(productRow + 1)
      .take(2)
      .map((row) => row.bounds)
      .toList();
  bool sameRow(ReceiptOcrCandidate candidate) =>
      (candidate.bounds.center.dy - product.bounds.center.dy).abs() <=
      tolerance;
  final result = source.numbers.where((candidate) {
    if (candidate.number == null ||
        candidate.number! < 0 ||
        candidate.number! > 9999999) {
      return false;
    }
    if (sameRow(candidate)) return true;
    return candidate.bounds.center.dy > product.bounds.center.dy &&
        below.any(
          (bounds) =>
              candidate.bounds.center.dy >= bounds.top &&
              candidate.bounds.center.dy <= bounds.bottom,
        );
  }).toList();
  result.sort((left, right) {
    final leftPriority = left.bounds.left >= product.bounds.right ? 0 : 1;
    final rightPriority = right.bounds.left >= product.bounds.right ? 0 : 1;
    final byRight = leftPriority.compareTo(rightPriority);
    if (byRight != 0) return byRight;
    final byRow = (sameRow(left) ? 0 : 1).compareTo(sameRow(right) ? 0 : 1);
    if (byRow != 0) return byRow;
    final byDistance = (left.bounds.center.dy - product.bounds.center.dy)
        .abs()
        .compareTo((right.bounds.center.dy - product.bounds.center.dy).abs());
    if (byDistance != 0) return byDistance;
    return right.bounds.right.compareTo(left.bounds.right);
  });
  return result;
}
