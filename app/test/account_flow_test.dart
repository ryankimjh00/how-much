import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';
import 'package:how_much/recovery_code.dart';

class _AccountCloud extends CloudService {
  _AccountCloud() : super(true);
  final issued = Completer<String>();
  String? id;
  String? savedCode;
  Completer<String?>? codeRead;
  List<AppRow> remote = [];
  @override
  String? get accountId => id;
  @override
  bool get canSync => id != null;
  @override
  Stream<String?> get authChanges => const Stream.empty();
  @override
  String get accountLabel => '복구 코드 계정';
  @override
  bool get usesRecoveryCode => true;
  @override
  Future<String> createRecoveryAccount() async {
    final code = await issued.future;
    id = 'recovery-account';
    savedCode = code;
    return code;
  }

  @override
  Future<String?> readRecoveryCode() async =>
      codeRead == null ? savedCode : await codeRead!.future;

  @override
  Future<void> restoreRecoveryAccount(
    String code, {
    String? expectedAccountId,
  }) async {
    expect(expectedAccountId, id);
    savedCode = RecoveryCode.format(code);
    id = 'recovery-account';
  }

  @override
  Future<void> signOut() async {
    id = null;
    savedCode = null;
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
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
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
    await tester.tap(find.text('복구 코드 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.text(cloud.savedCode!), findsOneWidget);
    await tester.tap(find.text('코드 복사'));
    await tester.pumpAndSettle();
    expect(copied, cloud.savedCode);
    await tester.tap(find.widgetWithText(FilledButton, '닫기'));
    await tester.pumpAndSettle();
    expect(find.text(cloud.savedCode!), findsNothing);
    await tester.ensureVisible(find.text('로그아웃'));
    await tester.tap(find.text('로그아웃'));
    await tester.pumpAndSettle();
    expect(cloud.savedCode, isNull);
    expect(find.text('복구 코드 다시 보기'), findsNothing);
    expect(
      tester
          .widget<TextField>(find.widgetWithText(TextField, '보관한 복구 코드'))
          .controller!
          .text,
      isEmpty,
    );
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

  testWidgets('작은 화면에서 기존 계정의 코드를 재입력하고 다시 확인한다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetViewInsets);
    SharedPreferences.setMockInitialValues({});
    final cloud = _AccountCloud()..id = 'recovery-account';
    final store = AppStore(cloud);
    await store.initialize();
    await store.addItem('기존 우유');
    await tester.pumpWidget(HowMuchApp(store: store));
    await tester.tap(find.byTooltip('계정 · 동기화'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('복구 코드 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('이 기기에 보관한 복구 코드가 없어요'), findsOneWidget);
    const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
    final input = find.widgetWithText(TextField, '보관한 복구 코드');
    await tester.ensureVisible(input);
    await tester.enterText(input, code.toLowerCase().replaceAll('-', ' '));
    tester.view.viewInsets = const FakeViewPadding(bottom: 260);
    await tester.pumpAndSettle();
    final reconnect = find.text('복구 코드로 다시 연결');
    await tester.ensureVisible(reconnect);
    await tester.tap(reconnect);
    await tester.pumpAndSettle();
    tester.view.resetViewInsets();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('복구 코드 다시 보기'));
    await tester.tap(find.text('복구 코드 다시 보기'));
    await tester.pumpAndSettle();
    expect(find.text(code), findsOneWidget);
    expect(store.shoppingItems.single.title, '기존 우유');
    expect(tester.takeException(), isNull);
    await tester.tap(find.widgetWithText(FilledButton, '닫기'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });

  testWidgets('코드 조회 중 중복 실행을 막고 실패하면 다시 조작할 수 있다', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final cloud = _AccountCloud()
      ..id = 'recovery-account'
      ..codeRead = Completer<String?>();
    final store = AppStore(cloud);
    await store.initialize();
    await tester.pumpWidget(HowMuchApp(store: store));
    await tester.tap(find.byTooltip('계정 · 동기화'));
    await tester.pumpAndSettle();
    store.syncing = true;
    await tester.tap(find.text('복구 코드 다시 보기'));
    await tester.pump();
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '복구 코드 다시 보기'),
          )
          .onPressed,
      isNull,
    );
    store.syncing = false;
    cloud.codeRead!.completeError(const FormatException('보안 저장소를 읽지 못했어요.'));
    await tester.pumpAndSettle();
    expect(find.text('보안 저장소를 읽지 못했어요.'), findsOneWidget);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, '복구 코드 다시 보기'),
          )
          .onPressed,
      isNotNull,
    );
    await tester.pumpWidget(const SizedBox());
    store.dispose();
  });
}
