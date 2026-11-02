import 'package:flutter_test/flutter_test.dart';

import 'package:how_much/models.dart';

void main() {
  test('메모에서 상품명과 수량을 분리한다', () {
    final lines = parseMemoText('• 우유 2개\n- 사과 x3\n빵');

    expect(lines.map((line) => line.title), ['우유', '사과', '빵']);
    expect(lines.map((line) => line.quantity), [2, 3, 1]);
    expect(lines.every((line) => !line.selected), isTrue);
  });

  test('손글씨 오인식의 숫자와 기호를 상품으로 만들지 않는다', () {
    expect(parseMemoText('7}971\n7} 971\n- 971\n!!!'), isEmpty);
  });

  test('상품명에 붙은 숫자는 유지하고 명시한 수량만 분리한다', () {
    final lines = parseMemoText(
      '비타민 B12\n3M 테이프\n우유2개\n계란 x3\n두부 2\n사과 X2개\n바나나 × 4개\n양파 1971개',
    );

    expect(lines.map((line) => line.title), [
      '비타민 B12',
      '3M 테이프',
      '우유',
      '계란',
      '두부',
      '사과',
      '바나나',
      '양파 1971개',
    ]);
    expect(lines.map((line) => line.quantity), [1, 1, 2, 3, 2, 2, 4, 1]);
  });

  test('영수증에서 날짜와 상품 금액을 찾고 자동 선택하지 않는다', () {
    final draft = parseReceiptText(
      '행복마트\n2026-09-20\n우유 2,500원\n합계 2,500원',
      id: 'receipt-1',
    );

    expect(draft.store, '행복마트');
    expect(draft.purchasedOn, '2026-09-20');
    expect(draft.lines.single.title, '우유');
    expect(draft.lines.single.total, 2500);
    expect(draft.lines.single.selected, isFalse);
  });

  test('같은 제품 조건의 가격 차이와 변동률을 계산한다', () {
    const spec = ProductSpec(
      identity: '서울우유',
      volume: 1,
      unit: 'L',
      conditionKnown: true,
      allocated: true,
    );
    const base = PurchaseData(
      receiptId: 'a',
      itemId: '',
      store: 'A마트',
      purchasedOn: '2026-09-01',
      quantity: 1,
      total: 2500,
      spec: spec,
    );
    const other = PurchaseData(
      receiptId: 'b',
      itemId: '',
      store: 'B마트',
      purchasedOn: '2026-09-02',
      quantity: 1,
      total: 2300,
      spec: spec,
    );

    final result = comparePrices(base, other);
    expect(result.issue, isEmpty);
    expect(result.delta, -200);
    expect(result.percent, -8);
  });
}
