import 'dart:math' as math; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]

/// [OCR 추가] 자동 탐색의 좌우 여백이다. 작은 글자도 각4px 이상, 큰 글자는 높이의15%를 확보한다.
double receiptAutomaticHorizontalPadding(double height) =>
    math.max(4.0, height * .15); // [OCR 추가]

/// [OCR 추가] 수량 행의 중앙값 간격보다3배 이상 빈 구간이 있으면 마지막 수량 행 아래까지만 반환한다.
/// 세 행 이상 비어 있는 사진 끝도 같은 기준을 쓴다. 수량이3행 미만이면 경계를 추측하지 않는다.
/// [OCR 수정] 공백 안에 알려진 상품 행이 있으면 수량 인식 누락이므로 종료하지 않는다.
double? receiptQuantityGapEnd(
  List<ReceiptOcrCandidate> rows,
  double photoBottom, {
  List<Rect> productRows =
      const [], // [OCR 추가] 상품명 후보는 종료 판단에만 쓰며 수량 값으로 대체하지 않는다.
}) {
  final quantities =
      rows.where((row) {
        final value =
            row.number ?? receiptSelectionAmount(row.text.trim()); // [OCR 추가]
        return value != null &&
            value >= 1 &&
            value <= 999 &&
            row.bounds.isFinite &&
            !row.bounds.isEmpty;
      }).toList()..sort(
        (a, b) => a.bounds.center.dy.compareTo(b.bounds.center.dy),
      ); // [OCR 추가]
  final bands = <Rect>[]; // [OCR 추가]
  for (final row in quantities) {
    if (bands.isNotEmpty &&
        (bands.last.center.dy - row.bounds.center.dy).abs() <=
            math.min(bands.last.height, row.bounds.height) * .65) {
      bands[bands.length - 1] = bands.last.expandToInclude(
        row.bounds,
      ); // [OCR 추가] 겹친 OCR 중복은 행 간격으로 세지 않는다.
    } else {
      bands.add(row.bounds); // [OCR 추가]
    }
  }
  if (bands.length < 3) return null; // [OCR 추가]
  final gaps = [
    for (var i = 1; i < bands.length; i++)
      bands[i].center.dy - bands[i - 1].center.dy,
  ]..sort(); // [OCR 추가]
  final spacing =
      gaps[(gaps.length - 1) ~/
          2]; // [OCR 추가] 큰 공백 자체가 정상 간격을 부풀리지 않도록 짝수 중앙값은 작은 쪽을 쓴다.
  if (spacing <= 0) return null; // [OCR 추가]
  double endOf(Rect row) => math.min(
    photoBottom,
    row.bottom + spacing * .25,
  ); // [OCR 추가] 같은 행의 이름·금액이 조금 더 높아도 마지막 상품은 남긴다.
  // [OCR 추가] 수량이 없어도 읽힌 상품명 행을 공백으로 취급해 버리지 않는다.
  bool hasProductBetween(double top, double bottom) => productRows.any(
    (row) =>
        row.isFinite &&
        !row.isEmpty &&
        row.center.dy > top &&
        row.center.dy < bottom,
  );
  for (var i = 1; i < bands.length; i++) {
    if (bands[i].center.dy - bands[i - 1].center.dy >= spacing * 3 &&
        !hasProductBetween(bands[i - 1].bottom, bands[i].top)) {
      return endOf(bands[i - 1]); // [OCR 추가] 세 행 이상 끊긴 뒤의 숫자는 다음 상품으로 탐색하지 않는다.
    }
  }
  if (photoBottom.isFinite &&
      photoBottom - bands.last.bottom >= spacing * 3 &&
      !hasProductBetween(bands.last.bottom, photoBottom)) {
    return endOf(bands.last); // [OCR 추가] 하단에 수량이 더 없어도 세 행 공백을 확인하면 멈춘다.
  }
  return null; // [OCR 추가]
}

/// [OCR 추가] 열 탐색의 행 위치는 이번 자동 선택에서만 보관하며 저장 모델에 쓰지 않는다.
class ReceiptColumnScan {
  // [OCR 추가]
  const ReceiptColumnScan(
    this.products,
    this.quantities,
    this.amounts, { // [OCR 수정]
    this.quantityBounds, // [OCR 추가]
    this.endBefore, // [OCR 추가] 수량 열이 확인한 탐색 종료 위치다.
  }); // [OCR 추가]
  final List<ReceiptOcrCandidate> products; // [OCR 추가]
  final List<ReceiptOcrCandidate> quantities; // [OCR 추가]
  final double? endBefore; // [OCR 추가]
  final Rect? quantityBounds; // [OCR 추가] 이번 수량 열 탐색의 원본 사진 크롭 좌표다.
  final List<ReceiptOcrCandidate> amounts; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 크롭 내부의 가로 글자 행을 표시 사진 좌표로 옮긴다. 좌표는 실제 정수 크롭 경계와 맞춘다.
List<ReceiptOcrCandidate> receiptCropRowsInPhoto(
  // [OCR 추가]
  ReceiptOcrResult cropped, // [OCR 추가]
  Rect crop, // [OCR 추가]
) {
  // [OCR 추가]
  final candidates = [...cropped.products, ...cropped.numbers]; // [OCR 추가]
  final rows = <ReceiptOcrCandidate>[]; // [OCR 추가]
  for (final row in cropped.rows) {
    // [OCR 추가]
    final ids = row.tokens.map((token) => token.id).toSet(); // [OCR 추가]
    final words =
        candidates
            .where((word) => ids.contains(word.id))
            .toList() // [OCR 추가]
          ..sort((a, b) => a.bounds.left.compareTo(b.bounds.left)); // [OCR 추가]
    if (words.isEmpty) continue; // [OCR 추가]
    final bounds = words
        .map((word) => word.bounds)
        .reduce((a, b) => a.expandToInclude(b)); // [OCR 추가]
    rows.add(
      ReceiptOcrCandidate(
        // [OCR 추가]
        id: row.id, // [OCR 추가]
        text: words.map((word) => word.text).join(' '), // [OCR 추가]
        bounds: bounds.shift(crop.topLeft), // [OCR 추가]
      ),
    ); // [OCR 추가]
  } // [OCR 추가]
  return rows; // [OCR 추가]
} // [OCR 추가]

/// [OCR 수정] 이름 열을 보완하고 필요한 숫자 열만 한 번씩 읽는다. 취소 시 다음 열 호출과 늦은 결과를 버린다.
Future<ReceiptColumnScan?> scanReceiptColumns({
  // [OCR 추가]
  required ReceiptOcrCandidate product, // [OCR 추가]
  required ReceiptOcrCandidate amount, // [OCR 추가]
  ReceiptOcrCandidate? quantity, // [OCR 추가]
  required Uint8List photoBytes, // [OCR 추가]
  required Size photoSize, // [OCR 추가]
  required Future<List<ReceiptOcrCandidate>> Function(Uint8List, Rect)
  recognize, // [OCR 추가]
  required bool Function() isCurrent, // [OCR 추가]
  double? startBelow, // [OCR 추가]
  double? endBefore, // [OCR 추가] 수량 열에서 큰 행 간격을 찾았으면 그 위까지만 읽는다.
  List<Rect> knownProductRows =
      const [], // [OCR 추가] 열 재검사도 기존 상품명 행을 공백으로 오인하지 않는다.
  bool Function(String field, List<ReceiptOcrCandidate> productRows)?
  shouldScan, // [OCR 추가] 이름 보완 이후에도 숫자가 부족한 열만 읽는다.
  void Function(String field, Rect bounds)? onScan, // [OCR 추가]
}) async {
  // [OCR 추가]
  final anchors = <String, ReceiptOcrCandidate>{
    // [OCR 추가]
    '상품명': product, // [OCR 추가]
  }; // [OCR 추가]
  if (quantity != null) anchors['수량'] = quantity; // [OCR 추가]
  anchors['금액'] = amount; // [OCR 추가]
  Rect? quantityBounds; // [OCR 추가]
  var activeEnd = endBefore; // [OCR 추가]
  final found = <String, List<ReceiptOcrCandidate>>{}; // [OCR 추가]
  for (final entry in anchors.entries) {
    // [OCR 추가]
    if (!isCurrent()) return null; // [OCR 추가]
    if (shouldScan != null && !shouldScan(entry.key, found['상품명'] ?? [])) {
      continue; // [OCR 추가]
    } // [OCR 추가]
    final anchor = entry.value.bounds; // [OCR 추가]
    // [OCR 수정] 수량 열은 첫 박스 폭에 작은 좌우 여백만 추가하고 이웃 열 경계를 유지한다.
    final padding = entry.key == '수량'
        ? receiptAutomaticHorizontalPadding(anchor.height)
        : math.max(4.0, anchor.height * .5); // [OCR 수정]
    var left = anchor.left - padding; // [OCR 추가]
    var right = anchor.right + padding; // [OCR 추가]
    // 이웃 열 사이의 중간선을 넘지 않게 해 수량 열에 단가/금액을 같이 넣지 않는다.
    for (final other in anchors.values) {
      // [OCR 추가]
      if (other.id == entry.value.id) continue; // [OCR 추가]
      if (other.bounds.right <= anchor.left) {
        // [OCR 추가]
        left = math.max(
          left,
          (other.bounds.right + anchor.left) / 2,
        ); // [OCR 추가]
      } // [OCR 추가]
      if (other.bounds.left >= anchor.right) {
        // [OCR 추가]
        right = math.min(
          right,
          (anchor.right + other.bounds.left) / 2,
        ); // [OCR 추가]
      } // [OCR 추가]
    } // [OCR 추가]
    final bounds = Rect.fromLTRB(
      // [OCR 추가]
      math.max(0, left).floorToDouble(), // [OCR 추가]
      // [OCR 수정] 머리글이 있으면 그 하단부터 읽어 머리글과 매장 안내를 상품명에 섞지 않는다.
      startBelow == null
          ? math.max(0, product.bounds.top - padding).floorToDouble()
          : math.max(0, startBelow).ceilToDouble(), // [OCR 수정]
      math.min(photoSize.width, right).ceilToDouble(), // [OCR 추가]
      math.min(photoSize.height, activeEnd ?? photoSize.height), // [OCR 수정]
    ); // [OCR 추가]
    if (bounds.isEmpty) {
      // [OCR 추가]
      found[entry.key] = []; // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    if (entry.key == '수량') quantityBounds = bounds; // [OCR 추가]
    onScan?.call(entry.key, bounds); // [OCR 추가]
    try {
      // [OCR 추가]
      final rows = await recognize(photoBytes, bounds); // [OCR 추가]
      if (!isCurrent()) return null; // [OCR 추가]
      found[entry.key] = List.unmodifiable(
        rows.where(
          (row) => // [OCR 추가]
              row.text.trim().isNotEmpty &&
              row.bounds.isFinite &&
              !row.bounds.isEmpty && // [OCR 추가]
              bounds.contains(row.bounds.center) && // [OCR 수정]
              (startBelow == null ||
                  row.bounds.top >= startBelow) && // [OCR 수정]
              (activeEnd == null || row.bounds.bottom <= activeEnd), // [OCR 추가]
        ),
      ); // [OCR 추가]
      if (entry.key == '수량') {
        final quantityEnd = receiptQuantityGapEnd(
          found[entry.key]!,
          photoSize.height,
          productRows: knownProductRows, // [OCR 추가]
        ); // [OCR 추가]
        if (quantityEnd != null) {
          activeEnd = math.min(
            activeEnd ?? photoSize.height,
            quantityEnd,
          ); // [OCR 추가] 금액 열은 수량의 끊긴 위치 아래를 읽지 않는다.
        }
      }
    } catch (_) {
      // [OCR 추가]
      if (!isCurrent()) return null; // [OCR 추가]
      // 열 탐색 실패는 기존 이름 기준의 부분 OCR을 막지 않는다.
      found[entry.key] = []; // [OCR 추가]
    } // [OCR 추가]
  } // [OCR 추가]
  return ReceiptColumnScan(
    found['상품명'] ?? [],
    found['수량'] ?? [],
    found['금액'] ?? [],
    quantityBounds: quantityBounds, // [OCR 추가]
    endBefore: activeEnd, // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 상대 위치와 가까운 행이 하나일 때만 그 크롭 탐색 위치를 사용한다. 다른 상품 행은 제외한다.
ReceiptOcrCandidate? receiptColumnRowNear(
  // [OCR 추가]
  List<ReceiptOcrCandidate> rows, // [OCR 추가]
  Rect expected, // [OCR 추가]
  Rect allowed, { // [OCR 추가]
  required bool quantity, // [OCR 추가]
  bool verifiedColumn =
      false, // [OCR 추가] 열 크롭 경계를 이미 통과한 행은 가로 이동을 다시 제한하지 않는다.
}) {
  // [OCR 추가]
  final expectedX = quantity ? expected.center.dx : expected.right; // [OCR 추가]
  final nearby = receiptCandidatesWithoutDuplicateNumbers(rows).where((row) {
    // [OCR 수정] 같은 글자의 중복 응답 때문에 유일한 수량 행을 버리지 않는다.
    // [OCR 추가]
    final rowX = quantity ? row.bounds.center.dx : row.bounds.right; // [OCR 추가]
    return (verifiedColumn ||
            (rowX - expectedX).abs() <= expected.height * 1.5) && // [OCR 수정]
        // [OCR 추가] 상품 행의 세로 관계와 이웃 상품 경계는 열 결과에도 반드시 적용한다.
        (row.bounds.center.dy - expected.center.dy).abs() <=
            expected.height * .65 && // [OCR 추가]
        row.bounds.top >= allowed.top &&
        row.bounds.bottom <= allowed.bottom; // [OCR 추가]
  }).toList(); // [OCR 추가]
  return nearby.length == 1 ? nearby.single : null; // [OCR 추가]
} // [OCR 추가]

// [OCR 수정] 다른 행 배치에서는 이름 열의 행 좌표로 조각을 묶고 문자열 일치를 요구하지 않는다.
void _mergeColumnNameFragments(
  List<ReceiptOcrCandidate> products,
  ReceiptOcrCandidate row,
  ReceiptOcrCandidate first,
) {
  final covered = products.where((name) {
    final height = math.min(name.bounds.height, row.bounds.height);
    return row.bounds.contains(name.bounds.center) &&
        (name.bounds.top - row.bounds.top).abs() <= height * .35 &&
        (name.bounds.center.dy - row.bounds.center.dy).abs() <= height * .4 &&
        name.bounds.right <= row.bounds.right + height;
  }).toList()..sort((a, b) => a.bounds.left.compareTo(b.bounds.left));
  if (covered.length < 2) return;
  final anchor = covered.first;
  // [OCR 추가] 첫 상품이 병합 행의 오른쪽 조각이어도 ID·확정 이름·선택 박스를 바꾸지 않는다.
  final containsSeed = covered.any((name) => name.id == first.id);
  final tolerance = math.max(first.bounds.height, anchor.bounds.height);
  if ((anchor.bounds.left - first.bounds.left).abs() > tolerance) return;
  // [OCR 수정] 문자열 비교는 표시할 이름을 고르는 데만 쓴다. 다르게 읽혀도 병합은 진행하고 기존 조각을 보존한다.
  String compact(String text) => text.replaceAll(RegExp(r'\s+'), '');
  final fullText = compact(row.text);
  final text = covered.every((name) => fullText.contains(compact(name.text)))
      ? row.text
      : covered.map((name) => name.text).join(' ');
  final bounds = covered
      .map((name) => name.bounds)
      .reduce((a, b) => a.expandToInclude(b));
  final merged = containsSeed
      ? first
      : ReceiptOcrCandidate(
          id: anchor.id,
          text: text, // [OCR 수정]
          bounds: bounds,
          isMergedName: true,
        );
  final position = products.indexOf(anchor);
  products.removeWhere(covered.contains);
  products.insert(math.min(position, products.length), merged);
}

/// [OCR 추가] 전체 OCR의 기존 이름 행으로 조각만 병합하며 새 이름 후보나 OCR 호출은 만들지 않는다.
List<ReceiptOcrCandidate> receiptProductsWithExistingRows(
  List<ReceiptOcrCandidate> products,
  List<ReceiptOcrRow> rows,
  ReceiptOcrCandidate first,
) {
  final result = List<ReceiptOcrCandidate>.of(products);
  for (final row in rows) {
    if (!RegExp(r'[가-힣A-Za-z]').hasMatch(row.text) ||
        row.text.length > 50 ||
        receiptIsNumericCode(row.text)) {
      continue; // [OCR 추가] 숫자 코드는 이름 병합에 사용하지 않는다.
    }
    _mergeColumnNameFragments(
      result,
      ReceiptOcrCandidate(id: row.id, text: row.text, bounds: row.bounds),
      first,
    );
  }
  return result;
}

/// [OCR 추가] 열에서 새로 읽은 이름 행을 보완한다. 첫 상품과 기존 이름은 누락 때문에 버리지 않는다.
List<ReceiptOcrCandidate> receiptProductsWithColumnRows(
  // [OCR 추가]
  List<ReceiptOcrCandidate> products, // [OCR 추가]
  List<ReceiptOcrCandidate> rows, // [OCR 추가]
  ReceiptOcrCandidate first, { // [OCR 수정]
  double? startBelow, // [OCR 추가]
  bool mergeNameRows = false, // [OCR 추가] 같은 행의 숫자를 이름에 섞지 않도록 기본값은 보수적으로 유지한다.
}) {
  // [OCR 추가]
  final result = List<ReceiptOcrCandidate>.of(products); // [OCR 추가]
  for (final row in rows) {
    // [OCR 추가]
    if (!RegExp(r'[가-힣A-Za-z]').hasMatch(row.text) || // [OCR 수정]
        row.text.length > 50 ||
        receiptIsNumericCode(row.text)) {
      // [OCR 추가]
      // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    // [OCR 수정] 같은 상품명 행의 좌표로 조각을 먼저 합쳐 뒷조각의 상대 위치 오차를 막는다.
    if (mergeNameRows) {
      _mergeColumnNameFragments(result, row, first); // [OCR 수정]
    }
    if (result.any(
      (name) => // [OCR 추가]
          (name.bounds.center.dy - row.bounds.center.dy).abs() <= // [OCR 추가]
              math.min(name.bounds.height, row.bounds.height) *
                  .65 && // [OCR 추가]
          name.bounds.overlaps(row.bounds),
    )) {
      // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    if (row.bounds.top < (startBelow ?? first.bounds.top)) continue; // [OCR 수정]
    result.add(
      ReceiptOcrCandidate(
        id: 'column-name-${row.id}',
        text: row.text,
        bounds: row.bounds,
      ),
    ); // [OCR 추가]
  } // [OCR 추가]
  return result; // [OCR 추가]
} // [OCR 추가]

// [OCR 추가] 후보 표시와 누적이 같은 숫자 판별 기준을 사용한다. 용량·글자가 섞인 원문은 그대로 둔다.
int? _receiptCandidateNumber(ReceiptOcrCandidate candidate) =>
    candidate.number ??
    receiptSelectionAmount(candidate.text.replaceAll(RegExp(r'[\s₩￦원]'), ''));

// [OCR 추가] 표시 여백으로 겹친 한 자리 숫자는 짧은 글자 높이의 20% 이내 가로 틈만 허용한다.
// [OCR 수정] 세로 중심 조건은 유지하고 표시·자동 연결·열 재사용 모두 같은 글자 중복을 판별한다.
bool _sameReceiptNumberBounds(
  Rect first,
  Rect second, {
  bool allowNarrowGap = false,
}) {
  final height = math.min(first.height, second.height); // [OCR 추가]
  if ((first.center.dy - second.center.dy).abs() > height * .65) {
    return false; // [OCR 추가]
  }
  if (first.overlaps(second)) return true; // [OCR 추가]
  if (!allowNarrowGap ||
      first.bottom <= second.top ||
      second.bottom <= first.top) {
    return false; // [OCR 추가]
  }
  final gap =
      math.max(first.left, second.left) - math.min(first.right, second.right);
  // [OCR 수정] 한 글자 중복의 작은 좌표 차이(스윗츠: 높이32px·틈5px)를 허용한다.
  return gap <= height * .20; // [OCR 수정] 다른 행·멀리 떨어진 열·다른 값은 합치지 않는다.
}

/// [OCR 추가] 숫자의 위치 중복만 숨기고 원래 후보 객체·순서·숫자가 아닌 글자는 유지한다.
List<ReceiptOcrCandidate> receiptCandidatesWithoutDuplicateNumbers(
  List<ReceiptOcrCandidate> candidates, {
  String? selectedId, // [OCR 추가] 다시 수정할 때 이미 선택한 ID와 사용자 영역을 숨기지 않는다.
}) {
  final ordered = selectedId == null
      ? candidates
      : [
          ...candidates.where((candidate) => candidate.id == selectedId),
          ...candidates.where((candidate) => candidate.id != selectedId),
        ]; // [OCR 추가] 중복 대표만 선택 후보로 정하고 표시 순서는 바꾸지 않는다.
  final kept = <ReceiptOcrCandidate>[]; // [OCR 수정]
  for (final candidate in ordered) {
    final value = _receiptCandidateNumber(candidate); // [OCR 추가]
    if (value != null &&
        kept.any(
          (other) =>
              _receiptCandidateNumber(other) == value &&
              _sameReceiptNumberBounds(
                other.bounds,
                candidate.bounds,
                allowNarrowGap:
                    other.text.trim().runes.length == 1 &&
                    candidate.text.trim().runes.length == 1,
              ),
        )) {
      continue; // [OCR 추가]
    }
    kept.add(candidate); // [OCR 추가]
  }
  final keptCandidates = kept.toSet(); // [OCR 추가] ID가 아닌 원래 객체로 표시 대표를 구분한다.
  return candidates
      .where(keptCandidates.contains)
      .toList(); // [OCR 수정] 원문·순서를 유지한다.
}

/// [OCR 수정] 기존 숫자에 새 결과를 누적한다. 표시와 같은 작은 가로 틈을 허용하되 다른 행·열·값은 유지한다.
List<ReceiptOcrCandidate> receiptNumbersWithCandidates(
  List<ReceiptOcrCandidate> existing,
  List<ReceiptOcrCandidate> additions,
) {
  final result = <ReceiptOcrCandidate>[]; // [OCR 수정]
  // [OCR 수정] 전체 OCR 안에서도 같은 글자를 여러 블록이 반환할 수 있어 기존 후보부터 중복 제거한다.
  for (final candidate in [...existing, ...additions]) {
    final value = _receiptCandidateNumber(candidate); // [OCR 수정]
    if (value == null) continue; // [OCR 추가] 실패한 응답을 숫자로 채우지 않는다.
    if (result.any(
      (other) =>
          other.number == value &&
          _sameReceiptNumberBounds(
            other.bounds,
            candidate.bounds,
            allowNarrowGap:
                other.text.trim().runes.length == 1 &&
                candidate.text.trim().runes.length == 1, // [OCR 추가]
          ), // [OCR 수정] 표시에서 하나인 글자는 자동 연결에서도 하나로 센다.
    )) {
      continue; // [OCR 추가]
    } // [OCR 추가]
    result.add(
      ReceiptOcrCandidate(
        id: candidate.id,
        text: candidate.text,
        number: value,
        bounds: candidate.bounds,
      ),
    ); // [OCR 추가]
  }
  return result; // [OCR 추가]
}
