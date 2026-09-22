import 'package:flutter_test/flutter_test.dart';

import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';

AppRow row(
  String title,
  String revision, {
  bool pending = false,
  String? baseRevision,
  String group = '',
  String id = 'item-1',
}) => AppRow(
  id: id,
  title: title,
  completed: false,
  revision: revision,
  pending: pending,
  baseRevision: baseRevision,
  group: group,
);

void main() {
  test('서버 기준 버전이 같으면 로컬 변경을 반영한다', () {
    final result = reconcileRows(
      [row('우유 1개', '0000000000000010:a')],
      [
        row(
          '우유 2개',
          '0000000000000020:b',
          pending: true,
          baseRevision: '0000000000000010:a',
          group: 'change-1',
        ),
      ],
    );

    expect(result.conflicts, isEmpty);
    expect(result.rows.single.title, '우유 2개');
    expect(result.rows.single.pending, isFalse);
  });

  test('양쪽이 같은 항목을 바꾸면 두 값을 충돌로 보관한다', () {
    final result = reconcileRows(
      [row('서버 우유', '0000000000000015:c')],
      [
        row(
          '이 기기 우유',
          '0000000000000020:b',
          pending: true,
          baseRevision: '0000000000000010:a',
          group: 'change-1',
        ),
      ],
    );

    expect(result.rows.single.title, '서버 우유');
    expect(result.conflicts.single.entries.single.local.title, '이 기기 우유');
    expect(result.conflicts.single.entries.single.remote!.title, '서버 우유');
  });

  test('한 구매 그룹에 충돌이 있으면 관련 변경을 함께 보류한다', () {
    final result = reconcileRows(
      [
        row('서버 우유', '0000000000000015:c'),
        row('사과 1개', '0000000000000010:a', id: 'item-2'),
      ],
      [
        row(
          '이 기기 우유',
          '0000000000000020:b',
          pending: true,
          baseRevision: '0000000000000010:a',
          group: 'purchase-1',
        ),
        row(
          '사과 2개',
          '0000000000000020:b',
          pending: true,
          baseRevision: '0000000000000010:a',
          group: 'purchase-1',
          id: 'item-2',
        ),
      ],
    );

    expect(result.conflicts.single.entries, hasLength(2));
    expect(
      result.rows.singleWhere((item) => item.id == 'item-2').title,
      '사과 1개',
    );
  });
}
