import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:how_much/app.dart';
import 'package:how_much/app_store.dart';
import 'package:how_much/cloud_service.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('자체 서버의 독립 클라이언트와 실제 오프라인 복귀를 검증한다', (tester) async {
    // 두 보안 저장 영역을 사용하되, 물리적으로는 한 에뮬레이터에서 순차 실행한다.
    const storageA = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'ai-ant-sync-a'),
      iOptions: IOSOptions(accountName: 'ai-ant-sync-a'),
    );
    const storageB = FlutterSecureStorage(
      aOptions: AndroidOptions(storageNamespace: 'ai-ant-sync-b'),
      iOptions: IOSOptions(accountName: 'ai-ant-sync-b'),
    );
    final clientA = CloudService(true, storage: storageA);
    final clientB = CloudService(true, storage: storageB);
    // 복구 코드와 토큰은 메모리·플랫폼 보안 저장소에만 두고 보고서에는 남기지 않는다.
    final recoveryCode = await clientA.createRecoveryAccount();
    await clientB.restoreRecoveryAccount(recoveryCode);
    AppStore? current;
    addTearDown(() async {
      current?.dispose();
      await clientA.signOut();
      await clientB.signOut();
    });

    Future<void> render(AppStore store) async {
      await tester.pumpWidget(HowMuchApp(key: UniqueKey(), store: store));
      await tester.pumpAndSettle();
    }

    Future<AppStore> open(String label, CloudService cloud) async {
      await tester.pumpWidget(const SizedBox.shrink());
      current?.dispose();
      // 전환 전에 이전 저장소를 종료해 시험용 기기 기록을 서로 섞지 않는다.
      SharedPreferences.resetStatic();
      SharedPreferences.setPrefix('ai_ant_sync_20261109.$label.');
      final store = AppStore(cloud);
      current = store;
      await store.initialize();
      store.setActive(false);
      await render(store);
      return store;
    }

    Future<void> capture(String name) async {
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await binding.takeScreenshot(name);
    }

    final a = await open('a', clientA);
    await binding.convertFlutterSurfaceToImage();
    await a.addItem('AI-ANT 검증 우유');
    await a.sync();
    expect(a.pendingCount, 0);
    await capture('mp3_01_client_a_added');
    final b = await open('b', clientB);
    expect(b.shoppingItems, isEmpty);
    await b.sync();
    expect(b.shoppingItems.single.title, 'AI-ANT 검증 우유');
    await capture('mp3_02_client_b_synced');

    final offline = await open('a', clientA);
    await _requestNetwork('offline');
    await offline.addItem('오프라인 검증 두부');
    await offline.sync();
    expect(offline.pendingCount, 1);
    expect(
      offline.shoppingItems.map((row) => row.title),
      contains('오프라인 검증 두부'),
    );
    await capture('mp3_03_offline_pending');
    await _requestNetwork('online');
    await offline.sync();
    expect(offline.pendingCount, 0);
    expect(offline.syncMessage, '동기화 완료');
    await capture('mp3_04_online_uploaded');
    final refreshed = await open('b', clientB);
    await refreshed.sync();
    expect(
      refreshed.shoppingItems.map((row) => row.title),
      contains('오프라인 검증 두부'),
    );
    await capture('mp3_05_client_b_refreshed');
    binding.reportData = {
      ...?binding.reportData,
      'phase': 'sync',
      'backend': 'FastAPI/PostgreSQL over HTTPS',
      'physicalEmulators': 1,
      'independentClients': 2,
      'nativeSecureStorage': true,
      'nativeLocalStorage': true,
      'clientBInitiallyEmpty': true,
      'clientAAdditionReflectedOnB': true,
      'offlinePendingPreserved': true,
      'onlinePendingCleared': true,
      'offlineAdditionReflectedOnB': true,
      'networkControl': 'host adb airplane mode and Wi-Fi',
      'twoDeviceRequirementVerified': false,
    };
  }, timeout: const Timeout(Duration(minutes: 5)));
}

Future<void> _requestNetwork(String state) async {
  final request = File('${Directory.systemTemp.path}/ai-ant-network-request');
  final acknowledgment = File(
    '${Directory.systemTemp.path}/ai-ant-network-ack',
  );
  if (await acknowledgment.exists()) await acknowledgment.delete();
  await request.writeAsString(state, flush: true);
  for (var attempt = 0; attempt < 180; attempt++) {
    if (await acknowledgment.exists() &&
        (await acknowledgment.readAsString()).trim() == state) {
      return;
    }
    await Future<void>.delayed(const Duration(seconds: 1));
  }
  throw StateError('호스트에서 $state 네트워크 전환을 확인하지 못했습니다.');
}
