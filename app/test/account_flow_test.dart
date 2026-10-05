import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';

class _AccountCloud extends CloudService {
  _AccountCloud() : super(true);
  final issued = Completer<String>();
  String? id;
  List<AppRow> remote = [];
  @override
  String? get accountId => id;
  @override
  bool get canSync => id != null;
  @override
  Stream<User?> get authChanges => const Stream.empty();
  @override
  String get accountLabel => '복구 코드 계정';
  @override
  bool get usesRecoveryCode => true;
  @override
  Future<String> createRecoveryAccount() async {
    final code = await issued.future;
    id = 'recovery-account';
    return code;
  }

  @override
  Future<SyncExchangeResult> exchange(List<AppRow> local) async {
    final result = reconcileRows(remote, local);
    remote = result.rows;
    return result;
  }

  @override
  Future<void> publishPrices(List<AppRow> rows) async {}
}

void main() {
  testWidgets('코드 발급 중 화면 닫기를 막고 보관 확인 후 기기 기록을 연결한다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = _AccountCloud();
    final store = AppStore(cloud);
    await store.initialize();
    await store.addItem('우유');
    await tester.pumpWidget(HowMuchApp(store: store));
    await tester.tap(find.byTooltip('계정 · 동기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복구 코드 만들고 기록 연결'));
    await tester.pumpAndSettle();
    final close = tester.widget<IconButton>(
      find.byWidgetPredicate(
        (widget) => widget is IconButton && widget.tooltip == '닫기',
      ),
    );
    expect(close.onPressed, isNull);
    cloud.issued.complete('2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ');
    await tester.pumpAndSettle();
    expect(find.text('복구 코드를 보관해주세요'), findsOneWidget);
    await tester.tap(find.text('코드를 보관했어요'));
    await tester.pumpAndSettle();
    expect(cloud.remote.single.title, '우유');
    final prefs = await SharedPreferences.getInstance();
    expect(
      prefs.getKeys().any(
        (key) => prefs.get(key).toString().contains('2345-6789'),
      ),
      isFalse,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
