import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';

class _TestCloud extends CloudService {
  _TestCloud() : super(true);
  String? id = 'account-a';
  final changes = StreamController<String?>.broadcast();
  final server = <String, List<AppRow>>{};
  bool offline = false;
  int calls = 0;
  int publishCalls = 0;
  bool publishFails = false;
  Completer<void>? pause;

  @override
  String? get accountId => id;
  @override
  bool get canSync => id != null;
  @override
  Stream<String?> get authChanges => changes.stream;

  @override
  Future<SyncExchangeResult> exchange(List<AppRow> local) async {
    calls++;
    final account = id!;
    await pause?.future;
    if (offline) throw StateError('인터넷 연결을 확인해주세요. 기기 기록은 유지됩니다.');
    final result = reconcileRows(server[account] ?? [], local);
    server[account] = result.rows;
    return result;
  }

  @override
  Future<void> publishPrices(List<AppRow> rows) async {
    publishCalls++;
    if (publishFails) throw StateError('가격 공유를 다시 시도해주세요.');
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<AppStore> setup(_TestCloud cloud, {bool autoDispose = true}) async {
    final store = AppStore(cloud);
    addTearDown(() async {
      if (autoDispose) store.dispose();
      await cloud.changes.close();
    });
    await store.initialize();
    return store;
  }

  testWidgets('로컬 저장 이후 자동 전송하며 오프라인 실패는 재시도한다', (tester) async {
    final cloud = _TestCloud()..offline = true;
    final store = await setup(cloud, autoDispose: false);
    await store.addItem('우유');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('@wasprice/flutter/account/account-a/v1'),
      contains('우유'),
    );
    await tester.pump(const Duration(milliseconds: 701));
    expect(store.pendingCount, 1);
    expect(store.syncMessage, contains('기기 기록은 유지'));

    cloud.offline = false;
    await tester.pump(const Duration(seconds: 30));
    await tester.pump(const Duration(milliseconds: 701));
    expect(cloud.server['account-a']!.single.title, '우유');
    expect(store.pendingCount, 0);
    expect(store.lastSyncedAt, isNotNull);
    store.dispose();
  });

  test('중복 동기화와 전송 중 수정은 차단한다', () async {
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await store.addItem('우유');
    cloud.pause = Completer<void>();
    final syncing = store.sync();
    await store.sync();
    await expectLater(store.addItem('사과'), throwsFormatException);
    expect(cloud.calls, 1);
    cloud.pause!.complete();
    await syncing;
    expect(store.shoppingItems.single.title, '우유');
  });

  testWidgets('백그라운드에서 자동 전송을 멈추고 복귀하면 재개한다', (tester) async {
    final cloud = _TestCloud();
    final store = await setup(cloud, autoDispose: false);
    store.setActive(false);
    await store.addItem('우유');
    await tester.pump(const Duration(seconds: 31));
    expect(cloud.calls, 0);
    store.setActive(true);
    await tester.pump(const Duration(milliseconds: 701));
    expect(cloud.server['account-a']!.single.title, '우유');
    store.dispose();
  });

  test('이전 계정의 늦은 응답을 새 계정에 저장하지 않는다', () async {
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await store.addItem('A 계정 우유');
    cloud.pause = Completer<void>();
    final syncing = store.sync();
    cloud.id = 'account-b';
    await store.reloadForCurrentAccount();
    await store.addItem('B 계정 사과');
    cloud.pause!.complete();
    await syncing;

    expect(store.shoppingItems.single.title, 'B 계정 사과');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getString('@wasprice/flutter/account/account-b/v1'),
      isNot(contains('A 계정 우유')),
    );
    cloud.id = 'account-a';
    await store.reloadForCurrentAccount();
    expect(store.shoppingItems.single.title, 'A 계정 우유');
  });

  test('충돌의 두 값은 재실행 후에도 보관하고 선택한 값을 다시 전송한다', () async {
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await store.addItem('우유');
    await store.sync();
    final original = store.shoppingItems.single;
    cloud.server['account-a'] = [
      original.copyWith(title: '서버 우유', revision: '9999999999999999:server'),
    ];
    await store.updateItem(original, title: '기기 우유', quantity: 2, note: '저지방');
    await store.sync();
    expect(store.conflicts.single.entries.single.remote!.title, '서버 우유');

    final restored = AppStore(cloud);
    addTearDown(restored.dispose);
    await restored.initialize();
    expect(restored.conflicts.single.entries.single.local.note, '저지방');
    await restored.resolveConflict(
      restored.conflicts.single.group,
      useLocal: true,
    );
    await restored.sync();
    expect(restored.conflicts, isEmpty);
    expect(cloud.server['account-a']!.single.title, '기기 우유');
  });

  test('편집 중 도착한 서버 변경을 오래된 화면으로 덮어쓰지 않는다', () async {
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await store.addItem('우유');
    await store.sync();
    final before = store.shoppingItems.single;
    cloud.server['account-a'] = [
      before.copyWith(title: '서버 우유', revision: '9999999999999999:server'),
    ];
    await store.sync();
    await expectLater(
      store.updateItem(before, title: '오래된 수정', quantity: 1, note: ''),
      throwsFormatException,
    );
    expect(store.shoppingItems.single.title, '서버 우유');
    final current = store.shoppingItems.single;
    await store.deleteItem(current);
    await store.restoreItem(current);
    expect(store.shoppingItems.single.title, '서버 우유');
  });

  test('기기 기록은 가져온 뒤에도 원본을 보존하며 기존 계정에 자동 합치지 않는다', () async {
    final guest = AppStore(CloudService(false));
    addTearDown(guest.dispose);
    await guest.initialize();
    await guest.addItem('기기 기록');
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await store.importGuestData();
    expect(store.pendingCount, 1);
    await store.sync();
    expect(cloud.server['account-a']!.single.title, '기기 기록');
    await expectLater(store.importGuestData(), throwsFormatException);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('@wasprice/flutter/guest/v1'), contains('기기 기록'));
  });

  test('손상된 로컬 기록을 새 기록이나 서버 결과로 덮어쓰지 않는다', () async {
    const key = '@wasprice/flutter/account/account-a/v1';
    const corrupt = '{invalid json';
    SharedPreferences.setMockInitialValues({key: corrupt});
    final cloud = _TestCloud();
    final store = await setup(cloud);
    await expectLater(store.addItem('우유'), throwsFormatException);
    await store.sync();
    expect(cloud.calls, 0);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(key), corrupt);
    expect(() => jsonDecode(corrupt), throwsFormatException);
  });

  test('기기 기록 가져오기는 전송 대기 중인 삭제 기록을 보존한다', () async {
    final guest = AppStore(CloudService(false));
    addTearDown(guest.dispose);
    await guest.initialize();
    await guest.addItem('기기 기록');
    final store = await setup(_TestCloud());
    await store.addItem('삭제할 우유');
    await store.sync();
    await store.deleteItem(store.shoppingItems.single);

    await expectLater(store.importGuestData(), throwsFormatException);
    expect(store.rows.single.deleted, isTrue);
    expect(store.rows.single.pending, isTrue);
  });

  test('실패한 가격 공유는 재시도하고 성공한 같은 변경은 반복 전송하지 않는다', () async {
    final cloud = _TestCloud()..publishFails = true;
    final store = await setup(cloud);
    final draft = ReceiptDraft(
      id: 'price-share-check',
      store: '마트',
      purchasedOn: DateTime.now().toIso8601String().substring(0, 10),
      lines: [ReceiptLineDraft(id: 'milk', title: '우유', total: 3000)],
    );
    await store.saveReceipt(draft);
    await store.sync();
    expect(cloud.publishCalls, 1);
    expect(store.syncMessage, contains('가격 공유를 다시'));

    cloud.publishFails = false;
    await store.sync();
    await store.sync();
    expect(cloud.publishCalls, 2);
    final row = store.purchaseRows.single;
    await store.renamePurchase(row, '저지방 우유');
    await store.sync();
    expect(cloud.publishCalls, 3);
  });
}
