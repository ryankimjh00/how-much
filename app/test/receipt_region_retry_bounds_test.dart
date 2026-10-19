import 'dart:typed_data'; // [OCR 추가]
import 'dart:ui'; // [OCR 추가]
import 'package:flutter_test/flutter_test.dart'; // [OCR 추가]
import 'package:how_much/receipt_region_retry.dart'; // [OCR 추가]

void main() {
  // [OCR 추가]
  for (final firstAttempt in [0, 20]) {
    // [OCR 추가]
    test(
      '첫 박스를 보존하고 시작 크기를 줄이지 않는 가로6·세로3 확대로 앞 두 실패 후 첫 성공 시 멈춘다: $firstAttempt',
      () async {
        // [OCR 추가]
        const base = Rect.fromLTWH(100, 100, 20, 20); // [OCR 추가]
        final reads = <Rect>[]; // [OCR 추가]
        final result = await readReceiptRegionRepeatedly(
          photoBytes: Uint8List(0),
          photoSize: const Size(300, 300), // [OCR 추가]
          bounds: base,
          numeric: true,
          quantity: true,
          firstAttempt: firstAttempt,
          isCurrent: () => true, // [OCR 추가]
          recognize: (_, bounds) async {
            reads.add(bounds);
            return reads.length < 3 ? '' : '1'; // [OCR 수정]
          },
        ); // [OCR 추가]
        final step = firstAttempt == 0 ? 1 : 2; // [OCR 추가]
        expect(reads, [
          base,
          Rect.fromLTRB(
            100 - 6.0 * step,
            100 - 3.0 * step,
            120 + 6.0 * step,
            120 + 3.0 * step,
          ), // [OCR 추가]
          Rect.fromLTRB(100 - 6.0 * step, 100, 120 + 6.0 * step, 120),
        ]); // [OCR 추가]
        expect(result!.attempts, 3); // [OCR 추가]
        expect(result.successes, 1); // [OCR 추가]
      },
    ); // [OCR 추가]
  } // [OCR 추가]
  test('자동 기준 높이는 5회 경계 확대·사진 경계 이동에서도 줄이지 않는다', () async {
    // [OCR 추가] 수동 영역의 기존 축소 동작과 구분해 자동 선택만 최소 높이를 지정한다.
    final reads = <Rect>[];
    await readReceiptRegionRepeatedly(
      photoBytes: Uint8List(0),
      photoSize: const Size(300, 300),
      bounds: const Rect.fromLTWH(100, 0, 20, 40),
      minimumHeight: 40,
      numeric: true,
      isCurrent: () => true,
      recognize: (_, bounds) async {
        reads.add(bounds);
        return '';
      },
    ); // [OCR 추가]
    expect(reads, hasLength(5));
    expect(
      reads.every((bounds) => bounds.height >= 40 && bounds.top >= 0),
      isTrue,
    ); // [OCR 추가]
  }); // [OCR 추가]
  test('행이 기준 높이보다 좁으면 박스를 줄이거나 다음 행을 침범하지 않는다', () async {
    var calls = 0; // [OCR 추가]
    final result = await readReceiptRegionRepeatedly(
      photoBytes: Uint8List(0),
      photoSize: const Size(300, 300),
      bounds: const Rect.fromLTWH(100, 50, 20, 40),
      allowedBounds: const Rect.fromLTWH(0, 50, 300, 30),
      minimumHeight: 40,
      numeric: true,
      isCurrent: () => true,
      recognize: (_, bounds) async {
        calls++;
        return '1';
      },
    ); // [OCR 추가]
    expect(calls, 0);
    expect(result!.successes, 0); // [OCR 추가]
  }); // [OCR 추가]
  test('큰 가로 확대도 사진·현재 상품 행 경계를 넘지 않고 실패 시 5회에서 멈춘다', () async {
    // [OCR 추가]
    const base = Rect.fromLTWH(0, 45, 8, 12); // [OCR 추가]
    const allowed = Rect.fromLTRB(0, 40, 50, 70); // [OCR 추가]
    final reads = <Rect>[]; // [OCR 추가]
    final result = await readReceiptRegionRepeatedly(
      photoBytes: Uint8List(0),
      photoSize: const Size(50, 100), // [OCR 추가]
      bounds: base,
      allowedBounds: allowed,
      numeric: true,
      firstAttempt: 60,
      isCurrent: () => true, // [OCR 추가]
      recognize: (_, bounds) async {
        reads.add(bounds);
        return '';
      },
    ); // [OCR 추가]
    expect(reads, hasLength(5)); // [OCR 추가]
    expect(result!.successes, 0); // [OCR 추가]
    expect(
      reads.every(
        (bounds) =>
            bounds.left >= allowed.left &&
            bounds.right <= allowed.right && // [OCR 추가]
            bounds.top >= allowed.top &&
            bounds.bottom <= allowed.bottom &&
            bounds.width >= base.width &&
            bounds.height >= base.height,
      ),
      isTrue,
    ); // [OCR 추가]
    expect(
      receiptRegionRetryEnvelope(base),
      const Rect.fromLTRB(-24, 33, 32, 69),
    ); // [OCR 추가]
  }); // [OCR 추가]
} // [OCR 추가]
