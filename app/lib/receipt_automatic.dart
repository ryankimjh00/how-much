import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'receipt_region_retry.dart'; // [OCR 추가]
import 'dart:math' as math; // [OCR 추가]
import 'models.dart'; // [OCR 추가]
import 'receipt_amount.dart'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]
import 'receipt_column_scan.dart'; // [OCR 추가]

/// [OCR 추가] 첫 상품의 이름 앞부분과 금액 뒷부분, 필요한 수량 위치를 자동 입력 기준으로 사용한다.
class ReceiptAutomaticSeed {
  // [OCR 추가]
  // [OCR 추가]
  const ReceiptAutomaticSeed({
    // [OCR 추가]
    required this.product, // [OCR 추가]
    required this.amount, // [OCR 추가]
    required this.isUnitPrice, // [OCR 추가]
    this.quantity, // [OCR 추가]
    this.includeQuantity = false, // [OCR 추가]
  }); // [OCR 추가]
  final ReceiptOcrCandidate product; // [OCR 추가]
  final ReceiptOcrCandidate amount; // [OCR 추가]
  final ReceiptOcrCandidate? quantity; // [OCR 추가]
  final bool isUnitPrice; // [OCR 추가]
  final bool includeQuantity; // [OCR 추가]
  bool get needsQuantity => !isUnitPrice || includeQuantity; // [OCR 추가]
} // [OCR 추가]

/// [OCR 수정] 첫 상품 주변의 오른쪽 금액을 제시한다. 선택한 수량의 세로 위치로 금액을 숨기지 않는다.
List<ReceiptOcrCandidate> receiptAutomaticAmountsNear(
  // [OCR 수정]
  // [OCR 추가]
  ReceiptOcrResult source, // [OCR 추가]
  ReceiptOcrCandidate product, { // [OCR 추가]
  ReceiptOcrCandidate? quantity, // [OCR 추가]
  List<ReceiptOcrCandidate>? amounts, // [OCR 추가]
}) {
  // [OCR 수정]
  // [OCR 추가]
  final candidates = (amounts ?? receiptPricesNear(source, product)).where((
    // [OCR 수정]
    candidate, // [OCR 수정]
  ) {
    // [OCR 수정]
    // [OCR 수정]
    if (candidate.id == quantity?.id || // [OCR 수정]
        candidate.number == null || // [OCR 수정]
        candidate.number! < 0) {
      // [OCR 수정]
      // [OCR 수정]
      return false; // [OCR 수정]
    } // [OCR 수정]
    return candidate.bounds.left >= product.bounds.right; // [OCR 수정]
  }).toList(); // [OCR 수정]
  final nextProductTop = _nextReceiptProductTop(
    source.products,
    product,
  ); // [OCR 추가]
  return candidates
      .where((candidate) => candidate.bounds.center.dy < nextProductTop)
      .toList(); // [OCR 수정]
} // [OCR 수정]

// [OCR 추가] 같은 행의 이름 조각은 건너뛰고 다음 상품 시작점 전까지만 첫 상품 영역으로 취급한다.
double _nextReceiptProductTop(
  List<ReceiptOcrCandidate> products,
  ReceiptOcrCandidate product,
) {
  var nextTop = double.infinity; // [OCR 추가]
  for (final other in products) {
    if (other.id == product.id) continue;
    final rowTolerance =
        math.min(product.bounds.height, other.bounds.height) * .65;
    if (other.bounds.top <= product.bounds.center.dy + rowTolerance) continue;
    nextTop = math.min(nextTop, other.bounds.top);
  }
  return nextTop; // [OCR 추가]
} // [OCR 추가]

// [OCR 수정] 머리글/첫 상품 아래의 이름 시작 열을 비교하고 한 글자 정도의 좌표 오차를 허용한다.
List<ReceiptOcrCandidate> _automaticProducts(
  List<ReceiptOcrCandidate> products,
  ReceiptAutomaticSeed seed, {
  double? startBelow, // [OCR 추가]
  double? endBefore, // [OCR 추가]
  List<ReceiptOcrCandidate> columnRows = const [], // [OCR 추가]
}) {
  // [OCR 수정]
  // [OCR 수정] 원문은 보존한다. 자동 입력은 이름 길이가 아니라 왼쪽 시작점으로 상품명 열을 좁힌다.
  final names = products.where((name) {
    if (name.id == seed.product.id) {
      return true; // [OCR 수정] 사용자가 확정한 기준은 자동 경계로 제외하지 않는다.
    }
    if (endBefore != null && name.bounds.bottom > endBefore) {
      return false; // [OCR 추가]
    }
    // [OCR 수정] 원근·인식 오차로 글자 크기가 달라지므로 두 박스 중 큰 높이를 한 글자 폭의 근사값으로 쓴다.
    final characterTolerance = math.max(
      seed.product.bounds.height,
      name.bounds.height,
    ); // [OCR 추가]
    // [OCR 추가] 같은 상품명 열에서 읽힌 행과 겹치면 원근으로 시작점이 조금 밀린 원본 이름도 유지한다.
    final verifiedInColumn = columnRows.any(
      (row) =>
          !receiptIsNumericCode(row.text) &&
          RegExp(r'[가-힣A-Za-z]').hasMatch(row.text) &&
          row.bounds.overlaps(name.bounds) &&
          // [OCR 수정] 같은 긴 행에 걸친 오른쪽 조각은 독립 상품의 시작점으로 인정하지 않는다.
          name.bounds.left - row.bounds.left <=
              math.max(row.bounds.height, name.bounds.height) &&
          (row.bounds.center.dy - name.bounds.center.dy).abs() <=
              math.min(row.bounds.height, name.bounds.height) * .65,
    );
    return name.id == seed.product.id ||
        verifiedInColumn || // [OCR 수정]
        (name.bounds.left - seed.product.bounds.left).abs() <=
            characterTolerance; // [OCR 수정]
  }).toList(); // [OCR 수정]
  // [OCR 추가] 후보 병합·필터 결과와 무관하게 첫 상품의 수정된 이름·좌표를 그대로 보존한다.
  names.removeWhere((name) => name.id == seed.product.id);
  names.add(seed.product);
  names.sort((a, b) {
    // [OCR 수정]
    final row = a.bounds.top.compareTo(b.bounds.top); // [OCR 수정]
    return row != 0 ? row : a.bounds.left.compareTo(b.bounds.left); // [OCR 수정]
  }); // [OCR 수정]
  if (startBelow != null) {
    // [OCR 추가] 선택한 상품은 위치 관계의 기준이며, 머리글 아래의 앞선 상품도 누락하지 않는다.
    return names
        .where(
          (name) => name.id == seed.product.id || name.bounds.top >= startBelow,
        ) // [OCR 수정]
        .toList(); // [OCR 추가]
  } // [OCR 추가]
  final first = names.indexWhere(
    (name) => name.id == seed.product.id,
  ); // [OCR 수정]
  if (first >= 0) return names.skip(first).toList(); // [OCR 수정]
  return [
    seed.product,
    ...names.where((name) => name.bounds.top >= seed.product.bounds.top),
  ]; // [OCR 수정]
} // [OCR 수정]

// [OCR 수정] 이름 길이와 무관하게 각 상품명의 왼쪽 시작점/위쪽을 기준으로 수량 중심·금액 우측 끝을 예상한다.
Offset _automaticAnchor(
  ReceiptOcrCandidate name,
  ReceiptAutomaticSeed seed, {
  bool quantity = false,
}) {
  // [OCR 수정]
  final number = quantity ? seed.quantity! : seed.amount; // [OCR 수정]
  final numberX = quantity
      ? number.bounds.center.dx
      : number.bounds.right; // [OCR 수정]
  return Offset(
    // [OCR 수정]
    name.bounds.left + numberX - seed.product.bounds.left, // [OCR 수정]
    name.bounds.top +
        number.bounds.center.dy -
        seed.product.bounds.top, // [OCR 수정]
  ); // [OCR 수정]
} // [OCR 수정]

Rect _automaticExpectedBounds(
  ReceiptOcrCandidate name,
  ReceiptAutomaticSeed seed, {
  bool quantity = false,
}) {
  // [OCR 수정]
  final number = quantity ? seed.quantity! : seed.amount; // [OCR 수정]
  final anchor = _automaticAnchor(name, seed, quantity: quantity); // [OCR 수정]
  final left = quantity
      ? anchor.dx - number.bounds.width / 2
      : anchor.dx - number.bounds.width; // [OCR 수정]
  return Rect.fromLTWH(
    left,
    anchor.dy - number.bounds.height / 2, // [OCR 수정]
    number.bounds.width,
    number.bounds.height,
  ); // [OCR 수정]
} // [OCR 수정]

// [OCR 수정] 금액 후보의 행에 의존하지 않고 이웃 상품명에서 예상한 행의 중간선을 넘는지 확인한다.
bool _belongsToAutomaticProduct(
  ReceiptOcrCandidate candidate,
  ReceiptOcrCandidate name, // [OCR 수정]
  List<ReceiptOcrCandidate> names,
  ReceiptAutomaticSeed seed,
) {
  // [OCR 수정]
  final row = _automaticAnchor(name, seed).dy; // [OCR 수정]
  for (final other in names) {
    // [OCR 수정]
    if (other.id == name.id) continue; // [OCR 수정]
    final otherRow = _automaticAnchor(other, seed).dy; // [OCR 수정]
    final middle = (row + otherRow) / 2; // [OCR 수정]
    if (otherRow < row && candidate.bounds.center.dy <= middle) {
      // [OCR 수정]
      return false; // [OCR 수정]
    } // [OCR 수정]
    if (otherRow > row && candidate.bounds.center.dy >= middle) {
      // [OCR 수정]
      return false; // [OCR 수정]
    } // [OCR 수정]
  } // [OCR 수정]
  return true; // [OCR 수정]
} // [OCR 수정]

// [OCR 추가] 상품명 열의 알려진 구매 후보로 수량 누락 구간을 보호한다.
// 결제·할인·숫자 코드와 세금 요약 아래는 빈 구간을 메우는 근거로 쓰지 않는다.
List<Rect> _knownAutomaticProductRows(
  ReceiptOcrResult source,
  ReceiptAutomaticSeed seed,
) {
  final taxEnd = receiptProductEndAboveTax(source.rows);
  return _automaticProducts(
        source.products,
        seed,
        startBelow: receiptProductStartBelowHeader(source.rows),
        endBefore: taxEnd,
      )
      .where(
        (name) =>
            !_receiptMetadata.hasMatch(name.text) &&
            !receiptIsNumericCode(name.text) &&
            RegExp(r'[가-힣A-Za-z]').hasMatch(name.text) &&
            name.text.trim().length <= 50,
      )
      .map((name) => name.bounds)
      .toList();
}

// [OCR 추가] 전체 OCR의 수량 열만 재사용해 간격을 잰다. 상품 코드나 금액 열의 숫자는 섞지 않는다.
double? _quantityGapEnd(
  ReceiptOcrResult source,
  ReceiptAutomaticSeed seed,
  double photoBottom,
) {
  if (!seed.needsQuantity) return null; // [OCR 추가]
  final column = seed.quantity!.bounds.inflate(
    receiptAutomaticHorizontalPadding(seed.quantity!.bounds.height),
  ); // [OCR 추가]
  final top =
      receiptProductStartBelowHeader(source.rows) ??
      seed.product.bounds.top; // [OCR 추가]
  return receiptQuantityGapEnd(
    source.numbers
        .where(
          (number) =>
              number.bounds.top >= top &&
              number.bounds.center.dx >= column.left &&
              number.bounds.center.dx <= column.right,
        )
        .toList(),
    photoBottom,
    productRows: _knownAutomaticProductRows(source, seed), // [OCR 추가]
  ); // [OCR 추가]
}

// [OCR 추가] 수량 공백·세금 행·전달된 경계 중 가장 위의 위치를 모든 자동 탐색에 적용한다.
double? _automaticProductEnd(
  ReceiptOcrResult source,
  ReceiptAutomaticSeed seed,
  double photoBottom, {
  double? endBefore,
}) {
  final ends = [
    _quantityGapEnd(source, seed, photoBottom),
    receiptProductEndAboveTax(source.rows),
    endBefore,
  ].whereType<double>().toList(); // [OCR 추가]
  return ends.isEmpty ? null : ends.reduce(math.min); // [OCR 추가]
}

// [OCR 수정] 표시 여백으로 커진 선택 박스보다 원문 글자 높이의 중앙값으로 행을 비교한다.
double _receiptTextHeight(ReceiptOcrResult source, ReceiptAutomaticSeed seed) {
  final heights = [
    for (final row in source.rows)
      for (final token in row.tokens)
        if (token.bounds.isFinite && !token.bounds.isEmpty) token.bounds.height,
  ]..sort();
  return heights.isEmpty
      ? seed.amount.bounds.height
      : heights[heights.length ~/ 2];
}

// [OCR 추가] 사람이 확정한 첫 상품은 다른 후보의 행·경계·중복·구매 판정과 분리한다.
ReceiptLineDraft _confirmedReceiptSeedLine(ReceiptAutomaticSeed seed) {
  final amountValue = seed.amount.number; // [OCR 추가]
  if (amountValue == null || amountValue < 0 || amountValue > 9999999) {
    // [OCR 추가]
    throw const FormatException('첫 금액 영역을 확인해주세요.'); // [OCR 추가]
  } // [OCR 추가]
  if (seed.needsQuantity && // [OCR 추가]
      (seed.quantity?.number == null || // [OCR 추가]
          seed.quantity!.number! < 1 || // [OCR 추가]
          seed.quantity!.number! > 999)) {
    // [OCR 추가]
    throw const FormatException('첫 수량 영역을 선택해주세요.'); // [OCR 추가]
  } // [OCR 추가]
  if (seed.needsQuantity && seed.quantity!.id == seed.amount.id) {
    // [OCR 추가]
    // [OCR 추가]
    throw const FormatException('수량과 금액은 서로 다른 영역을 선택해주세요.'); // [OCR 추가]
  } // [OCR 추가]
  final line = receiptLineFromAmount(
    id: 'automatic-seed-${seed.product.id}',
    title: seed.product.text,
    amount: amountValue,
    isUnitPrice: seed.isUnitPrice,
    quantity: seed.needsQuantity ? seed.quantity!.number : 1,
  );
  line.ocrProduct = seed.product;
  line.ocrAmount = seed.amount;
  line.ocrQuantity = seed.quantity;
  line.ocrAmountIsUnitPrice = seed.isUnitPrice;
  line.ocrInputAmount = amountValue;
  return line;
}

/// [OCR 수정] 상품명부터 얻고 각 이름에서 수량·금액의 상대 위치를 직접 확인한다. 누락·모호한 항목은 체크 해제로 남긴다.
List<ReceiptLineDraft> automaticReceiptLines(
  // [OCR 추가]
  ReceiptOcrResult source, // [OCR 추가]
  ReceiptAutomaticSeed seed, { // [OCR 추가]
  double? endBefore, // [OCR 추가] 수량 열의 공백으로 확인한 마지막 상품 행이다.
  List<ReceiptOcrCandidate>? products, // [OCR 추가]
  List<ReceiptOcrCandidate> productColumnRows =
      const [], // [OCR 추가] 실제 이름 열에서 확인한 행이다.
}) {
  // [OCR 추가]
  // [OCR 추가]
  final confirmedSeed = _confirmedReceiptSeedLine(seed); // [OCR 수정]
  final height = _receiptTextHeight(source, seed);
  final rowTolerance = height * .65;
  final names = _automaticProducts(
    products ?? source.products,
    seed,
    startBelow: receiptProductStartBelowHeader(source.rows), // [OCR 추가]
    columnRows: productColumnRows, // [OCR 추가]
    endBefore: _automaticProductEnd(
      source,
      seed,
      double.infinity,
      endBefore: endBefore,
    ), // [OCR 추가]
  ); // [OCR 수정]
  final numbers = receiptNumbersWithCandidates(
    [],
    source.numbers,
  ); // [OCR 추가] 원본은 유지하고 연결 시 겹친 중복 숫자만 한 후보로 본다.
  final matches = <String, ReceiptOcrCandidate>{
    seed.product.id: seed.amount,
  }; // [OCR 수정]
  for (final name in names.where((name) => name.id != seed.product.id)) {
    // [OCR 수정]
    final expected = _automaticAnchor(name, seed); // [OCR 수정]
    // [OCR 수정] 아래쪽 글자가 커지는 원근 오차를 첫 금액 높이만으로 제한하면 읽힌 금액을 버린다.
    final rightTolerance = math.max(
      // [OCR 수정]
      math.max(seed.amount.bounds.height, name.bounds.height) * 1.5, // [OCR 수정]
      seed.amount.bounds.width * .25, // [OCR 수정]
    ); // [OCR 수정] 행 소속·유일 후보 검증은 그대로 유지한다.
    final candidates = numbers.where((candidate) {
      // [OCR 수정]
      if (candidate.number == null ||
          candidate.number! < 0 ||
          candidate.number! > 9999999) {
        // [OCR 수정]
        return false; // [OCR 수정]
      } // [OCR 수정]
      if ((candidate.bounds.right - expected.dx).abs() >
              rightTolerance || // [OCR 수정]
          (candidate.bounds.center.dy - expected.dy).abs() >
              rowTolerance || // [OCR 수정]
          candidate.bounds.left < name.bounds.left + height) {
        // [OCR 수정]
        return false; // [OCR 수정]
      } // [OCR 수정]
      return _belongsToAutomaticProduct(
        candidate,
        name,
        names,
        seed,
      ); // [OCR 수정]
    }).toList(); // [OCR 수정]
    // [OCR 수정] 같은 예상 영역에 여러 숫자가 있으면 임의로 하나를 확정하지 않는다.
    if (candidates.length == 1) {
      // [OCR 수정]
      matches[name.id] = candidates.single; // [OCR 수정]
    } // [OCR 수정]
  } // [OCR 수정]
  final assigned = <String, int>{}; // [OCR 추가]
  for (final amount in matches.values) {
    // [OCR 추가]
    assigned.update(
      amount.id,
      (count) => count + 1,
      ifAbsent: () => 1,
    ); // [OCR 추가]
  } // [OCR 추가]
  final lines = <ReceiptLineDraft>[]; // [OCR 추가]
  for (final name in names) {
    // [OCR 추가]
    // [OCR 추가]
    if (name.id == seed.product.id) {
      lines.add(confirmedSeed); // [OCR 수정] 자동 판정이나 재인식으로 첫 항목을 다시 만들지 않는다.
      continue;
    }
    final amount = matches[name.id]; // [OCR 추가]
    ReceiptOcrCandidate? quantity; // [OCR 추가]
    var notice = ''; // [OCR 추가]
    if (amount == null) {
      // [OCR 추가]
      notice = '금액을 확인해주세요.'; // [OCR 추가]
    } // [OCR 추가]
    else if (assigned[amount.id]! > 1) {
      // [OCR 추가]
      notice = '여러 상품이 같은 금액 행에 있어 확인이 필요해요.'; // [OCR 추가]
    } // [OCR 추가]
    if (seed.needsQuantity) {
      // [OCR 수정]
      final expected = _automaticAnchor(name, seed, quantity: true); // [OCR 수정]
      final candidates = numbers.where((number) {
        // [OCR 수정]
        if (number.id == amount?.id ||
            number.number == null || // [OCR 수정]
            number.number! < 1 ||
            number.number! > 999) {
          // [OCR 수정]
          return false; // [OCR 수정]
        } // [OCR 수정]
        // [OCR 수정] 수량도 해당 상품명과의 가로/세로 상대 거리를 직접 검사한다.
        if ((number.bounds.center.dx - expected.dx).abs() >
                height * 1.5 || // [OCR 수정]
            (number.bounds.center.dy - expected.dy).abs() > rowTolerance) {
          // [OCR 수정]
          return false; // [OCR 수정]
        } // [OCR 수정]
        if (!_belongsToAutomaticProduct(number, name, names, seed)) {
          // [OCR 수정]
          return false; // [OCR 수정]
        } // [OCR 수정]
        if (amount != null) {
          // [OCR 수정]
          // [OCR 수정] 이름과 각각 맞아도 수량·금액끼리 다른 행/열이면 연결하지 않는다.
          final expectedX =
              seed.quantity!.bounds.center.dx -
              seed.amount.bounds.right; // [OCR 수정]
          final expectedY =
              seed.quantity!.bounds.center.dy -
              seed.amount.bounds.center.dy; // [OCR 수정]
          if ((number.bounds.center.dx - amount.bounds.right - expectedX)
                      .abs() >
                  height * 1.25 || // [OCR 수정]
              (number.bounds.center.dy - amount.bounds.center.dy - expectedY)
                      .abs() >
                  rowTolerance || // [OCR 수정]
              (number.bounds.center.dy - amount.bounds.center.dy).abs() >
                  rowTolerance) {
            // [OCR 수정]
            return false; // [OCR 수정]
          } // [OCR 수정]
        } // [OCR 수정]
        return true; // [OCR 수정]
      }).toList(); // [OCR 수정]
      if (candidates.length == 1) quantity = candidates.single; // [OCR 수정]
      if (quantity == null) notice = '같은 상품 행의 수량을 확인해주세요.'; // [OCR 수정]
    } // [OCR 수정]
    if (_receiptMetadata.hasMatch(name.text) || // [OCR 수정]
        name.text.trim().isEmpty || // [OCR 추가]
        name.text.trim().length > 50) {
      // [OCR 추가]
      notice = '구매 상품인지 확인해주세요.'; // [OCR 추가]
    } // [OCR 추가]
    final count = seed.needsQuantity ? quantity?.number ?? 0 : 1; // [OCR 추가]
    final value = amount?.number ?? 0; // [OCR 추가]
    ReceiptLineDraft line; // [OCR 추가]
    if (count > 0 && amount != null) {
      // [OCR 추가]
      // [OCR 추가]
      try {
        // [OCR 추가]
        line = receiptLineFromAmount(
          // [OCR 추가]
          id: 'automatic-${lines.length}', // [OCR 추가]
          title: name.text, // [OCR 추가]
          amount: value, // [OCR 추가]
          isUnitPrice: seed.isUnitPrice, // [OCR 추가]
          quantity: count, // [OCR 추가]
        ); // [OCR 추가]
      } // [OCR 추가]
      on FormatException {
        // [OCR 추가]
        line = ReceiptLineDraft(
          // [OCR 추가]
          id: 'automatic-${lines.length}', // [OCR 추가]
          title: name.text, // [OCR 추가]
          quantity: count, // [OCR 추가]
          total: seed.isUnitPrice ? 0 : value, // [OCR 수정]
          selected: false, // [OCR 추가]
        ); // [OCR 추가]
        notice = '수량·금액 범위를 확인해주세요.'; // [OCR 추가]
      } // [OCR 추가]
    } else {
      // [OCR 추가]
      line = ReceiptLineDraft(
        // [OCR 추가]
        id: 'automatic-${lines.length}', // [OCR 추가]
        title: name.text, // [OCR 추가]
        quantity: count, // [OCR 추가]
        total: seed.isUnitPrice ? 0 : value, // [OCR 수정]
        selected: false, // [OCR 추가]
      ); // [OCR 추가]
    } // [OCR 추가]
    line.selected = notice.isEmpty && count > 0 && amount != null; // [OCR 추가]
    line.ocrProduct = name; // [OCR 추가]
    line.ocrAmount = amount; // [OCR 추가]
    line.ocrQuantity = quantity; // [OCR 추가]
    line.ocrAmountIsUnitPrice = seed.isUnitPrice; // [OCR 추가]
    line.ocrInputAmount = amount?.number; // [OCR 추가]
    line.ocrNotice = notice; // [OCR 추가]
    lines.add(line); // [OCR 추가]
  } // [OCR 추가]
  return lines; // [OCR 추가]
} // [OCR 추가]

final _receiptMetadata = RegExp(
  // [OCR 추가]
  r'(포인트|카드|결제|합계|총액|승인|영수증|사업자|과세|면세|부가세|안내|거스름|고객센터|전화)', // [OCR 추가]
); // [OCR 추가]

// [OCR 수정] 이웃 상품명에서 예상한 행 중간까지만 허용해 다음 상품의 숫자를 읽지 않는다.
Rect _automaticRowBounds(
  List<ReceiptLineDraft> lines,
  int index,
  ReceiptAutomaticSeed seed,
  Size size,
) {
  // [OCR 추가]
  double rowY(ReceiptLineDraft line) =>
      _automaticAnchor(line.ocrProduct!, seed).dy; // [OCR 수정]
  final center = rowY(lines[index]); // [OCR 추가]
  var top = 0.0; // [OCR 추가]
  var bottom = size.height; // [OCR 추가]
  for (var i = 0; i < lines.length; i++) {
    // [OCR 추가]
    if (i == index) continue; // [OCR 추가]
    final other = rowY(lines[i]); // [OCR 추가]
    if (other < center) {
      // [OCR 추가]
      top = math.max(top, (other + center) / 2); // [OCR 추가]
    } // [OCR 추가]
    if (other > center) {
      // [OCR 추가]
      bottom = math.min(bottom, (other + center) / 2); // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return Rect.fromLTRB(0, top, size.width, bottom); // [OCR 추가]
} // [OCR 추가]

bool _unconfirmedRegion(ReceiptRegionRead result) {
  // [OCR 추가]
  if (result.successes < 1 || result.candidates.isEmpty) {
    // [OCR 추가]
    return true; // [OCR 추가]
  } // [OCR 추가]
  final candidates = result.candidates; // [OCR 추가]
  return candidates.length > 1 &&
      candidates[0].hits == candidates[1].hits; // [OCR 추가]
} // [OCR 추가]

// [OCR 추가] 실제 읽힌 숫자만 반환한다. 실패한 영역에는 전체 OCR의 옛 값을 다시 채우지 않는다.
ReceiptOcrCandidate? _automaticReadCandidate(
  ReceiptRegionRead? result,
  String id,
) {
  // [OCR 추가]
  if (result == null || result.candidates.isEmpty) return null; // [OCR 추가]
  final candidate = result.candidates.first; // [OCR 추가]
  return ReceiptOcrCandidate(
    // [OCR 추가]
    id: id,
    text: candidate.text,
    bounds: candidate.bounds, // [OCR 추가]
    number: receiptSelectionAmount(candidate.text), // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

// [OCR 추가] 열에서 읽힌 순수 숫자만 재사용한다. 글자와 섞인 행은 기존 부분 OCR로 확인한다.
ReceiptOcrCandidate? _columnNumber(ReceiptOcrCandidate? row) {
  if (row == null) return null; // [OCR 추가]
  final value =
      row.number ??
      receiptSelectionAmount(
        row.text.replaceAll(RegExp(r'[\s₩￦원]'), ''),
      ); // [OCR 추가]
  if (value == null) return null; // [OCR 추가]
  return ReceiptOcrCandidate(
    id: row.id,
    text: row.text,
    number: value,
    bounds: row.bounds,
  ); // [OCR 추가]
}

// [OCR 추가] 이미 위치가 연결된 유효 후보는 한 번 읽힌 결과로 재사용하며 다시 OCR하지 않는다.
ReceiptRegionRead? _existingRegionRead(
  ReceiptOcrCandidate? candidate,
  Rect bounds, {
  bool quantity = false,
}) {
  if (candidate == null || candidate.number == null) {
    return null; // [OCR 추가]
  } // [OCR 추가]
  final value = candidate.number
      .toString(); // [OCR 추가] 원문 통화 기호보다 이미 파싱한 정수 값을 재사용한다.
  if (receiptRegionValueError(value, numeric: true, quantity: quantity) !=
      null) {
    return null; // [OCR 추가]
  } // [OCR 추가]
  return ReceiptRegionRead(
    [ReceiptRegionCandidate(value, bounds)],
    0,
    1,
  ); // [OCR 추가]
}

/// [OCR 수정] 전체 후보를 우선 재사용하고 열·부분 결과를 누적한다. 누락 영역만 최대5회/첫 성공까지 읽는다.
/// 값이 없으면 각 상품명에서 첫 기준의 상대 위치 관계로 영역을 추정한다. 중단은 null, 실패/모호함은 체크 해제한 검토 항목이다.
Future<List<ReceiptLineDraft>?> readAutomaticReceiptLines({
  // [OCR 추가]
  required ReceiptOcrResult source, // [OCR 추가]
  required ReceiptAutomaticSeed seed, // [OCR 추가]
  required Uint8List photoBytes, // [OCR 추가]
  required Size photoSize, // [OCR 추가]
  required Future<String> Function(Uint8List, Rect) recognize, // [OCR 추가]
  required bool Function() isCurrent, // [OCR 추가]
  Future<String> Function(Uint8List, Rect)?
  recognizeQuantity, // [OCR 추가] 별도 인식기를 지정한 경우에만 수량·금액을 동시에 읽는다.
  List<ReceiptOcrCandidate>? products, // [OCR 추가]
  Future<List<ReceiptOcrCandidate>> Function(Uint8List, Rect)?
  scanRegion, // [OCR 추가]
  void Function(ReceiptOcrResult result)?
  onCandidates, // [OCR 추가] 완료된 누적 후보만 검토에 전달한다.
  Future<void> Function()? onProductShown, // [OCR 추가]
  void Function(
    int item,
    int total,
    String field,
    int attempts,
    int successes,
    Rect bounds,
  )? // [OCR 수정] 실제 재인식에 전달하는 미세 조정 좌표도 함께 알린다.
  onProgress, // [OCR 추가]
}) async {
  // [OCR 추가]
  // [OCR 수정] 기존 이름을 보완하고 숫자가 부족한 열만 읽어 상대 위치로 누적 후보를 연결한다.
  final productStart = receiptProductStartBelowHeader(source.rows); // [OCR 추가]
  final initialEnd = _automaticProductEnd(
    source,
    seed,
    photoSize.height,
  ); // [OCR 추가]
  // [OCR 추가] 상품명과 필수 숫자가 모두 다른 행일 때만 전체 상품명 행을 병합한다.
  // 한 숫자라도 같은 행이면 기존 숫자 장벽을 유지해 가격·수량을 이름에 섞지 않는다.
  final rowTolerance = _receiptTextHeight(source, seed) * .65;
  final mergeNameRows =
      [
        seed.amount,
        if (seed.needsQuantity && seed.quantity != null) seed.quantity!,
      ].every(
        (field) =>
            field.bounds.center.dy - seed.product.bounds.center.dy >
            rowTolerance,
      );
  // [OCR 수정] 상품명·금액 열은 다시 읽지 않는다. 이름 조각은 전체 OCR에 보관된 행으로만 병합한다.
  final scanProducts = mergeNameRows
      ? receiptProductsWithExistingRows(
          products ?? source.products,
          source.rows,
          seed.product,
        )
      : products;
  bool shouldScan(String field, List<ReceiptOcrCandidate> productRows) {
    if (field != '수량') return false; // [OCR 수정] 재검사할 열은 수량뿐이다.
    final known = automaticReceiptLines(
      source,
      seed,
      products: scanProducts,
      endBefore: initialEnd,
    );
    return known.any(
      (line) =>
          line.ocrProduct!.id != seed.product.id &&
          !_receiptMetadata.hasMatch(line.title) &&
          line.ocrQuantity == null,
    );
  }

  final scan = scanRegion == null
      ? null
      : await scanReceiptColumns(
          product: seed.product,
          amount: seed.amount,
          quantity: seed.quantity, // [OCR 추가]
          photoBytes: photoBytes,
          photoSize: photoSize, // [OCR 추가]
          recognize: scanRegion,
          isCurrent: isCurrent, // [OCR 추가]
          startBelow: productStart, // [OCR 추가]
          endBefore: initialEnd, // [OCR 추가]
          knownProductRows: _knownAutomaticProductRows(
            source,
            seed,
          ), // [OCR 추가]
          shouldScan: shouldScan, // [OCR 추가]
          onScan: (field, bounds) =>
              onProgress?.call(0, 0, '$field 열 탐색', 1, 0, bounds), // [OCR 추가]
        ); // [OCR 추가]
  if (!isCurrent()) return null; // [OCR 추가]
  var accumulatedNumbers = receiptNumbersWithCandidates(source.numbers, [
    for (final row in scan?.quantities ?? <ReceiptOcrCandidate>[])
      ReceiptOcrCandidate(
        id: 'column-quantity-${row.id}-${row.bounds.left}-${row.bounds.top}-${row.text}',
        text: row.text,
        bounds: row.bounds,
      ), // [OCR 수정] 열이 달라도 같은 ML Kit 줄 ID를 공유하지 않는다.
    for (final row in scan?.amounts ?? <ReceiptOcrCandidate>[])
      ReceiptOcrCandidate(
        id: 'column-amount-${row.id}-${row.bounds.left}-${row.bounds.top}-${row.text}',
        text: row.text,
        bounds: row.bounds,
      ), // [OCR 수정]
  ]); // [OCR 추가]
  ReceiptOcrResult accumulatedSource() {
    // [OCR 추가] 새 좌표도 OCR 행으로 남겨 검토에서 다시 선택할 때 후보 필터가 누락시키지 않게 한다.
    final knownIds = source.rows
        .expand((row) => row.tokens)
        .map((token) => token.id)
        .toSet(); // [OCR 추가]
    final names = scanProducts ?? source.products; // [OCR 추가]
    final addedRows = [
      for (final candidate in [...names, ...accumulatedNumbers])
        if (!knownIds.contains(candidate.id))
          ReceiptOcrRow(
            id: 'accumulated-row-${candidate.id}',
            text: candidate.text,
            bounds: candidate.bounds,
            tokens: [
              ReceiptOcrToken(
                id: candidate.id,
                text: candidate.text,
                bounds: candidate.bounds,
              ),
            ],
          ), // [OCR 추가]
    ]; // [OCR 추가]
    return ReceiptOcrResult(
      text: source.text,
      photoPath: source.photoPath,
      photoBytes: source.photoBytes,
      rows: [...source.rows, ...addedRows],
      products: names,
      numbers: accumulatedNumbers,
    ); // [OCR 추가] 기존 원문·사진·행을 덮어쓰지 않는다.
  }

  final productEnd = scan?.endBefore ?? initialEnd; // [OCR 추가]
  final lines = automaticReceiptLines(
    accumulatedSource(),
    seed,
    products: scanProducts,
    productColumnRows: scan?.products ?? [], // [OCR 추가]
    endBefore: productEnd, // [OCR 추가]
  ); // [OCR 수정]

  final reread = <ReceiptLineDraft>[]; // [OCR 추가]
  for (var index = 0; index < lines.length; index++) {
    // [OCR 추가]
    if (!isCurrent()) return null; // [OCR 추가]
    final original = lines[index]; // [OCR 추가]
    final name = original.ocrProduct!; // [OCR 추가]
    // [OCR 추가] 사용자가 확인한 첫 기준과 결제 안내/할인 행은 자동 재인식으로 덮어쓰지 않는다.
    if (name.id == seed.product.id ||
        _receiptMetadata.hasMatch(name.text) ||
        name.text.trim().isEmpty ||
        name.text.trim().length > 50) {
      // [OCR 추가]
      reread.add(original); // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    // [OCR 추가] 숫자 OCR 전에 현재 기준 상품명 위치가 실제로 그려질 시간을 확보한다.
    onProgress?.call(
      index + 1,
      lines.length,
      '상품명 확인',
      0,
      0,
      name.bounds,
    ); // [OCR 추가]
    if (onProductShown != null) {
      // [OCR 수정] 화면 표시 대기가 있는 호출만 기다려 기존 부분 OCR 시작 시점을 유지한다.
      await onProductShown(); // [OCR 수정]
    } // [OCR 추가]
    if (!isCurrent()) return null; // [OCR 추가]
    final rowBounds = _automaticRowBounds(
      lines,
      index,
      seed,
      photoSize,
    ); // [OCR 추가]
    final allowed = productEnd == null
        ? rowBounds
        : rowBounds.intersect(
            Rect.fromLTRB(0, 0, photoSize.width, productEnd),
          ); // [OCR 추가] 재시도 확대도 종료 행을 넘기지 않는다.
    final expectedAmount =
        original.ocrAmount?.bounds ??
        _automaticExpectedBounds(name, seed); // [OCR 수정]
    final scannedAmount = receiptColumnRowNear(
      scan?.amounts ?? [],
      _automaticExpectedBounds(name, seed),
      allowed, // [OCR 추가]
      quantity: false, // [OCR 추가]
      verifiedColumn: true, // [OCR 추가] 실제 금액 열 안의 행이므로 상품명 시작점 이동으로 버리지 않는다.
    ); // [OCR 추가]
    // [OCR 수정] 열/후보의 작은 숫자 박스는 위치만 참고하고 금액 높이는 첫 기준보다 작아지지 않게 한다.
    final amountBounds = scannedAmount?.bounds ?? expectedAmount; // [OCR 추가]
    final searchAmountBounds = Rect.fromCenter(
      center: amountBounds.center,
      width:
          amountBounds.width +
          2 *
              receiptAutomaticHorizontalPadding(
                math.max(amountBounds.height, seed.amount.bounds.height),
              ), // [OCR 수정] 좌우 여백을 주고 중심과 높이는 유지한다.
      height: math.max(amountBounds.height, seed.amount.bounds.height),
    ); // [OCR 추가]
    Future<ReceiptRegionRead?> read(
      Rect bounds,
      String field, {
      bool quantity = false,
      ReceiptRegionRead? initialRead, // [OCR 추가]
      Rect? scanBounds, // [OCR 추가]
    }) async {
      if (!isCurrent()) return null; // [OCR 추가]
      // [OCR 수정] 같은 상품 행으로 검증한 기존 값은 크롭 높이 제한으로 버리지 않는다.
      // 높이 제한은 새 OCR 영역이 이웃 행을 침범하지 않게 하는 조건이며 이미 읽힌 값에는 필요 없다.
      if (initialRead != null &&
          initialRead.successes >= 1 &&
          initialRead.candidates.isNotEmpty) {
        return initialRead; // [OCR 추가] 사용자 박스 크기는 유지하고 숫자 값만 재사용한다.
      }
      return await readReceiptRegionRepeatedly(
        // [OCR 추가]
        photoBytes: photoBytes,
        photoSize: photoSize,
        bounds: bounds, // [OCR 추가]
        // [OCR 수정] 탐색 행을 고르면 실패해도 다른 위치로 넘어가지 않고 같은 영역 주변에서만 반복한다.
        allowedBounds: scanBounds == null
            ? allowed
            : allowed.intersect(
                receiptRegionRetryEnvelope(scanBounds),
              ), // [OCR 수정]
        recognize: quantity
            ? (recognizeQuantity ?? recognize)
            : recognize, // [OCR 수정]
        isCurrent: isCurrent, // [OCR 추가]
        initialRead: initialRead, // [OCR 추가]
        numeric: true,
        quantity: quantity, // [OCR 추가]
        minimumHeight: quantity
            ? seed.quantity!.bounds.height
            : seed.amount.bounds.height, // [OCR 추가]
        onAttempt: (region, attempts, successes) => onProgress?.call(
          // [OCR 수정]
          index + 1,
          lines.length,
          field,
          attempts,
          successes,
          region, // [OCR 추가]
        ), // [OCR 추가]
      ); // [OCR 추가]
    }

    Future<ReceiptRegionRead?> readAmount() => read(
      searchAmountBounds,
      seed.isUnitPrice ? '단가' : '금액',
      scanBounds: scannedAmount == null ? null : searchAmountBounds,
      initialRead: _existingRegionRead(
        original.ocrAmount ??
            _columnNumber(
              scannedAmount,
            ), // [OCR 수정] 열에서 이미 읽은 금액을 잘린 예상 영역으로 재인식하지 않는다.
        searchAmountBounds,
      ), // [OCR 추가]
    ); // [OCR 수정]
    ReceiptRegionRead? amountRead; // [OCR 추가]
    ReceiptRegionRead? quantityRead; // [OCR 추가]
    ReceiptOcrCandidate? quantity; // [OCR 추가]
    Future<void> readQuantity() async {
      // [OCR 추가]
      if (!seed.needsQuantity) return; // [OCR 추가]
      // [OCR 추가]
      // [OCR 수정] 수량 후보가 없어도 금액 위치에 종속시키지 않고 해당 상품명에서 직접 계산한다.
      final scannedQuantity = receiptColumnRowNear(
        scan?.quantities ?? [],
        _automaticExpectedBounds(name, seed, quantity: true),
        allowed, // [OCR 추가]
        quantity: true, // [OCR 추가]
        verifiedColumn: true, // [OCR 추가]
      ); // [OCR 추가]
      final quantityBounds =
          scannedQuantity?.bounds ?? // [OCR 수정]
          original.ocrQuantity?.bounds ??
          _automaticExpectedBounds(name, seed, quantity: true); // [OCR 수정]
      // [OCR 수정] 첫 수량 박스 높이를 유지하고 폭에만 여백을 더한다. 크롭 결과는 중심 위치만 참고한다.
      final searchQuantityBounds = Rect.fromCenter(
        center: quantityBounds.center, // [OCR 수정]
        width:
            seed.quantity!.bounds.width +
            2 *
                receiptAutomaticHorizontalPadding(
                  seed.quantity!.bounds.height,
                ), // [OCR 수정] 첫 폭에 작은 좌우 여백을 더한다.
        height: seed.quantity!.bounds.height, // [OCR 수정]
      ); // [OCR 수정]
      final currentQuantityRead = await read(
        searchQuantityBounds, // [OCR 수정]
        '수량',
        initialRead: _existingRegionRead(
          original.ocrQuantity ??
              _columnNumber(
                scannedQuantity,
              ), // [OCR 수정] 열에서 읽힌 수량도 성공 결과로 재사용한다.
          searchQuantityBounds,
          quantity: true,
        ), // [OCR 수정]
        quantity: true,
        scanBounds: scannedQuantity == null
            ? null
            : searchQuantityBounds, // [OCR 추가]
      ); // [OCR 추가]
      quantityRead = currentQuantityRead; // [OCR 수정]
      if (!isCurrent() || currentQuantityRead == null) return; // [OCR 수정]
      quantity = _automaticReadCandidate(
        currentQuantityRead,
        '${original.id}-quantity-read',
      ); // [OCR 수정]
    } // [OCR 추가]

    if (recognizeQuantity == null) {
      // [OCR 추가] 동일 인식기를 주입한 기존 호출은 순차 실행한다.
      amountRead = await readAmount();
      if (!isCurrent() || amountRead == null) return null;
      await readQuantity();
    } else {
      // [OCR 추가] 상품 간 순서는 유지하고 현재 상품의 두 필드만 병렬 실행한다. 한쪽 실패에도 다른 작업 종료를 기다린다.
      await Future.wait<void>([
        () async {
          amountRead = await readAmount();
        }(),
        readQuantity(),
      ]);
    } // [OCR 추가]
    final confirmedAmountRead = amountRead;
    final confirmedQuantityRead = quantityRead; // [OCR 추가] // [OCR 추가]
    if (!isCurrent() ||
        confirmedAmountRead == null ||
        (seed.needsQuantity && confirmedQuantityRead == null)) {
      return null;
    } // [OCR 추가]
    final amount = _automaticReadCandidate(
      confirmedAmountRead,
      '${original.id}-amount-read',
    ); // [OCR 수정]
    final count = seed.needsQuantity ? quantity?.number ?? 0 : 1; // [OCR 추가]
    final value = amount?.number ?? 0; // [OCR 추가]
    var notice = ''; // [OCR 추가]
    if (_unconfirmedRegion(confirmedAmountRead)) {
      // [OCR 추가]
      notice = '다시 읽은 금액을 확인해주세요.'; // [OCR 추가]
    } // [OCR 추가]
    if (confirmedQuantityRead != null &&
        _unconfirmedRegion(confirmedQuantityRead)) {
      // [OCR 추가]
      notice = '다시 읽은 수량을 확인해주세요.'; // [OCR 추가]
    } // [OCR 추가]
    if (original.ocrNotice == '여러 상품이 같은 금액 행에 있어 확인이 필요해요.') {
      // [OCR 추가]
      notice = original.ocrNotice; // [OCR 추가]
    } // [OCR 추가]
    ReceiptLineDraft line; // [OCR 추가]
    try {
      // [OCR 추가]
      line = receiptLineFromAmount(
        // [OCR 추가]
        id: original.id,
        title: original.title,
        amount: value, // [OCR 추가]
        isUnitPrice: seed.isUnitPrice,
        quantity: count, // [OCR 추가]
      ); // [OCR 추가]
    } on FormatException {
      // [OCR 추가]
      line = ReceiptLineDraft(
        // [OCR 추가]
        id: original.id,
        title: original.title,
        quantity: count, // [OCR 추가]
        total: seed.isUnitPrice ? 0 : value,
        selected: false, // [OCR 추가]
      ); // [OCR 추가]
      if (notice.isEmpty) notice = '수량·금액 범위를 확인해주세요.'; // [OCR 추가]
    } // [OCR 추가]
    line.ocrProduct = name; // [OCR 추가]
    line.ocrAmount = amount; // [OCR 추가]
    line.ocrQuantity = quantity; // [OCR 추가]
    line.ocrAmountIsUnitPrice = seed.isUnitPrice; // [OCR 추가]
    line.ocrInputAmount = amount?.number; // [OCR 추가]
    line.ocrNotice = notice; // [OCR 추가]
    line.selected = notice.isEmpty && amount != null && count > 0; // [OCR 추가]
    accumulatedNumbers = receiptNumbersWithCandidates(
      accumulatedNumbers,
      [amount, quantity].whereType<ReceiptOcrCandidate>().toList(),
    ); // [OCR 추가]
    reread.add(line); // [OCR 추가]
  } // [OCR 추가]
  if (!isCurrent()) return null; // [OCR 수정]
  onCandidates?.call(
    accumulatedSource(),
  ); // [OCR 추가] 취소·실패한 작업은 누적 후보를 외부에 쓰지 않는다.
  return reread; // [OCR 수정]
} // [OCR 추가]
