import 'dart:math' as math; // [OCR 추가]
import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'receipt_ocr.dart'; // [OCR 추가]

/// [OCR 추가] 실제 성공한 값과 그 사진 좌표, 같은 값이 읽힌 횟수다.
class ReceiptRegionCandidate {
  // [OCR 추가]
  ReceiptRegionCandidate(this.text, this.bounds); // [OCR 추가]
  final String text; // [OCR 추가]
  final Rect bounds; // [OCR 추가]
  int hits = 1; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 한 번 누른 재인식의 실제 시도/성공 횟수와 중복을 합친 후보다.
class ReceiptRegionRead {
  // [OCR 추가]
  ReceiptRegionRead(this.candidates, this.attempts, this.successes); // [OCR 추가]
  final List<ReceiptRegionCandidate> candidates; // [OCR 추가]
  final int attempts; // [OCR 추가]
  final int successes; // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 영수증 날짜를 yyyy-MM-dd로 정규화하며 없는 날짜와 미래 날짜는 거절한다.
String? receiptRegionDate(String input) {
  // [OCR 추가] 날짜 뒤의 시간은 제외하되 월/일 넘침을 Dart의 자동 보정으로 확정하지 않는다.
  final match = RegExp(
    r'(?<!\d)(20\d{2})\s*[-./]\s*(\d{1,2})\s*[-./]\s*(\d{1,2})(?!\d)',
  ).firstMatch(input); // [OCR 추가]
  if (match == null) return null; // [OCR 추가]
  final year = int.parse(match.group(1)!); // [OCR 추가]
  final month = int.parse(match.group(2)!); // [OCR 추가]
  final day = int.parse(match.group(3)!); // [OCR 추가]
  final date = DateTime(year, month, day); // [OCR 추가]
  final now = DateTime.now(); // [OCR 추가]
  if (date.year != year ||
      date.month != month ||
      date.day != day ||
      date.isAfter(DateTime(now.year, now.month, now.day))) {
    return null; // [OCR 추가]
  } // [OCR 추가]
  return date.toIso8601String().substring(0, 10); // [OCR 추가]
}

/// [OCR 추가] 화면의 직접 입력과 반복 인식에서 같은 필드 범위를 검사한다.
String? receiptRegionValueError(
  String input, {
  bool numeric = false,
  bool quantity = false,
  bool date = false, // [OCR 추가]
}) {
  // [OCR 추가]
  final text = input.trim(); // [OCR 추가]
  if (date) {
    return receiptRegionDate(text) == null
        ? '구매일은 오늘까지의 실제 날짜로 입력해주세요.'
        : null; // [OCR 추가]
  } // [OCR 추가]
  if (!numeric) {
    // [OCR 추가]
    return text.isEmpty || text.length > 50
        ? '상품명을 1~50자로 입력해주세요.'
        : null; // [OCR 추가]
  } // [OCR 추가]
  final value = receiptSelectionAmount(text); // [OCR 추가]
  if (value == null || (quantity && (value < 1 || value > 999))) {
    // [OCR 추가]
    return quantity
        ? '수량은 1~999개로 입력해주세요.'
        : '금액은 0~9,999,999원으로 입력해주세요.'; // [OCR 추가]
  } // [OCR 추가]
  return null; // [OCR 추가]
} // [OCR 추가]

const _horizontalExpansion =
    6.0; // [OCR 추가] 작은 숫자 앞뒤가 잘리지 않도록 가로 확대를 더 크게 허용한다.
const _verticalExpansion = 3.0; // [OCR 추가]
const _maximumBoundaryStep = 4; // [OCR 추가]

/// [OCR 추가] 반복 인식이 확장할 수 있는 최대 경계다. 자동 인식은 이 경계와 해당 상품 행을 함께 제한한다.
Rect receiptRegionRetryEnvelope(Rect bounds) => Rect.fromLTRB(
  // [OCR 추가]
  bounds.left - _horizontalExpansion * _maximumBoundaryStep, // [OCR 추가]
  bounds.top - _verticalExpansion * _maximumBoundaryStep, // [OCR 추가]
  bounds.right + _horizontalExpansion * _maximumBoundaryStep, // [OCR 추가]
  bounds.bottom + _verticalExpansion * _maximumBoundaryStep, // [OCR 추가]
); // [OCR 추가]

// [OCR 수정] 시작 박스보다 줄이지 않고 가로 6px/세로 3px씩 확대하며 사진/해당 상품 행 밖으로 확장하지 않는다.
Rect _attemptBounds(
  Rect base,
  Rect allowed,
  int attempt,
  double minimumHeight,
) {
  // [OCR 수정]
  // [OCR 추가]
  const edges = <(int, int, int, int)>[
    // [OCR 추가]
    // [OCR 추가]
    (0, 0, 0, 0), (-1, -1, 1, 1), (-1, 0, 1, 0), // [OCR 수정]
    (0, -1, 0, 1), (-1, 0, 0, 0), (0, 0, 1, 0), // [OCR 수정]
    (0, -1, 0, 0), (0, 0, 0, 1), (-1, -1, 0, 0), // [OCR 수정]
    (0, 0, 1, 1), (-1, 0, 0, 1), (0, -1, 1, 0), // [OCR 수정]
    (-1, -1, 1, 0), (-1, 0, 1, 1), (-1, -1, 0, 1), // [OCR 수정]
    (0, -1, 1, 1), (-1, -1, 1, 1), (-1, 0, 1, 0), // [OCR 수정]
    (0, -1, 0, 1), (-1, -1, 1, 0), // [OCR 수정]
  ]; // [OCR 추가]

  final edge = edges[attempt % edges.length]; // [OCR 추가]
  final step = math.min(
    _maximumBoundaryStep,
    1 + attempt ~/ edges.length,
  ); // [OCR 추가]
  // [OCR 수정] 왼쪽/위쪽은 음수가 확대이고 오른쪽/아래쪽은 양수가 확대다.
  // [OCR 수정] 방향표는 바깥 이동만 포함해 시작 글자 영역을 잘라내지 않는다.
  final left = edge.$1 * _horizontalExpansion * step; // [OCR 수정]
  final top = edge.$2 * _verticalExpansion * step; // [OCR 수정]
  final right = edge.$3 * _horizontalExpansion * step; // [OCR 수정]
  final bottom = edge.$4 * _verticalExpansion * step; // [OCR 수정]
  final width = (base.width + right - left)
      .clamp(2.0, allowed.width)
      .toDouble(); // [OCR 추가]
  final height = (base.height + bottom - top)
      .clamp(math.max(2.0, minimumHeight), allowed.height)
      .toDouble(); // [OCR 추가]
  return Rect.fromLTWH(
    // [OCR 추가]
    (base.left + left)
        .clamp(allowed.left, allowed.right - width)
        .toDouble(), // [OCR 추가]
    (base.top + top)
        .clamp(allowed.top, allowed.bottom - height)
        .toDouble(), // [OCR 추가]
    width,
    height, // [OCR 추가]
  ); // [OCR 추가]
} // [OCR 추가]

/// [OCR 추가] 최대 5회 순차 인식하고 첫 유효 결과에서 즉시 중단한다.
/// 화면/기준이 바뀌면 null을 반환한다. initialRead의 실제 열 인식 횟수를 합산하고 firstAttempt는 경계 조합을 이어간다. // [OCR 수정]
Future<ReceiptRegionRead?> readReceiptRegionRepeatedly({
  // [OCR 추가]
  required Uint8List photoBytes, // [OCR 추가]
  required Size photoSize, // [OCR 추가]
  required Rect bounds, // [OCR 추가]
  required Future<String> Function(Uint8List, Rect) recognize, // [OCR 추가]
  required bool Function() isCurrent, // [OCR 추가]
  bool numeric = false, // [OCR 추가]
  bool quantity = false, // [OCR 추가]
  bool date = false, // [OCR 추가]
  ReceiptRegionRead?
  initialRead, // [OCR 추가] 같은 상품 행의 열 OCR 결과를 포함해 총 5회 시도와 첫 성공을 센다.
  int firstAttempt = 0, // [OCR 추가]
  double minimumHeight = 0, // [OCR 추가] 자동 선택은 사용자가 정한 높이 아래로 축소하지 않는다.
  Rect? allowedBounds, // [OCR 추가]
  void Function(Rect bounds, int attempts, int successes)?
  onAttempt, // [OCR 추가]
}) async {
  // [OCR 추가]
  if (!isCurrent()) return null; // [OCR 추가] 열에서 한 번 읽혀 부분 호출을 건너뛰어도 취소는 반영한다.
  final photo = Offset.zero & photoSize; // [OCR 추가]
  final allowed = photo.intersect(allowedBounds ?? photo); // [OCR 추가]
  if (!bounds.isFinite ||
      !allowed.isFinite ||
      allowed.width < 2 ||
      allowed.height <
          math.max(
            2.0,
            minimumHeight,
          ) || // [OCR 수정] 기준 높이가 들어갈 수 없는 행은 다른 행까지 넓히지 않고 미확정으로 남긴다.
      bounds.intersect(allowed).isEmpty) {
    // [OCR 추가]
    return ReceiptRegionRead([], 0, 0); // [OCR 추가]
  } // [OCR 추가]
  final candidates = <String, ReceiptRegionCandidate>{}; // [OCR 추가]
  // [OCR 추가] 다른 항목과 후보 객체를 공유하지 않고 복제해 횟수 변경이 전파되지 않게 한다.
  for (final candidate
      in initialRead?.candidates ?? <ReceiptRegionCandidate>[]) {
    // [OCR 추가]
    final copy = ReceiptRegionCandidate(
      candidate.text,
      candidate.bounds,
    ); // [OCR 추가]
    copy.hits = candidate.hits; // [OCR 추가]
    final key = numeric
        ? receiptSelectionAmount(copy.text).toString()
        : copy.text; // [OCR 추가]
    candidates[key] = copy; // [OCR 추가]
  } // [OCR 추가]
  var attempts = initialRead?.attempts ?? 0; // [OCR 수정]
  var successes = initialRead?.successes ?? 0; // [OCR 수정]
  for (var i = 0; attempts < 5 && successes < 1; i++) {
    // [OCR 수정]
    // [OCR 추가]
    if (!isCurrent()) return null; // [OCR 추가]
    final region = _attemptBounds(
      bounds,
      allowed,
      firstAttempt + i,
      minimumHeight, // [OCR 추가]
    ); // [OCR 추가]
    attempts++; // [OCR 추가]
    onAttempt?.call(region, attempts, successes); // [OCR 추가]
    String value; // [OCR 추가]
    try {
      // [OCR 추가]
      value = (await recognize(photoBytes, region)).trim(); // [OCR 추가]
    } catch (_) {
      // [OCR 추가]
      if (!isCurrent()) return null; // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    if (!isCurrent()) return null; // [OCR 추가]
    if (date) {
      value =
          receiptRegionDate(value) ??
          ''; // [OCR 추가] 날짜가 없는 응답은 실패로 처리하고 다시 시도한다.
    } // [OCR 추가]
    if (numeric) value = value.replaceAll(RegExp(r'[\s₩￦원]'), ''); // [OCR 추가]
    if (receiptRegionValueError(
          value,
          numeric: numeric,
          quantity: quantity,
          date: date,
        ) !=
        null) {
      // [OCR 추가]
      continue; // [OCR 추가]
    } // [OCR 추가]
    successes++; // [OCR 추가]
    final key = numeric
        ? receiptSelectionAmount(value).toString()
        : value.replaceAll(RegExp(r'\s+'), ' '); // [OCR 추가]
    final existing = candidates[key]; // [OCR 추가]
    if (existing == null) {
      // [OCR 추가]
      candidates[key] = ReceiptRegionCandidate(value, region); // [OCR 추가]
    } else {
      // [OCR 추가]
      existing.hits++; // [OCR 추가]
    } // [OCR 추가]
    if (successes >= 1) break; // [OCR 수정] 첫 성공값 이후에는 추가 호출하지 않는다.
  } // [OCR 추가]
  final ranked = candidates.values.toList(); // [OCR 추가]
  final order = {
    for (var i = 0; i < ranked.length; i++) ranked[i]: i,
  }; // [OCR 추가]
  ranked.sort((a, b) {
    // [OCR 추가]
    final frequency = b.hits.compareTo(a.hits); // [OCR 추가]
    return frequency != 0
        ? frequency
        : order[a]!.compareTo(order[b]!); // [OCR 추가]
  }); // [OCR 추가]
  return isCurrent()
      ? ReceiptRegionRead(ranked, attempts, successes)
      : null; // [OCR 수정] // [OCR 추가]
} // [OCR 추가]
