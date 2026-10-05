import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/models.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('실기기 Keychain과 HTTPS 복구·동기화·충돌을 검증한다', (tester) async {
    // 실제 앱의 세션·기기 기록을 건드리지 않는 별도 보안 저장 영역이다.
    const storage = FlutterSecureStorage(
      iOptions: IOSOptions(accountName: 'howmuch-integration-tests'),
      aOptions: AndroidOptions(storageNamespace: 'howmuch-integration-tests'),
    );
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('동기화 검증 중'))),
    );
    final first = CloudService(true, storage: storage);
    final code = await first.createRecoveryAccount();
    final account = first.accountId;
    final restarted = CloudService(true, storage: storage);
    await restarted.initialize();
    expect(restarted.accountId, account);
    const row = AppRow(
      id: 'integration-shopping',
      title: '실기기 검증 우유',
      completed: false,
      revision: '1791154800000000:integration',
      pending: true,
      group: '1791154800000000:integration',
    );
    expect((await first.exchange([row])).rows.single.title, row.title);
    await restarted.restoreRecoveryAccount(
      code.toLowerCase().replaceAll('-', ' '),
    );
    expect(restarted.accountId, account);
    final fetched = (await restarted.exchange([])).rows.single;
    final edited = fetched
        .copyWith(title: '두 번째 기기 수정', revision: '1791154800000001:integration')
        .withSync(
          pending: true,
          baseRevision: fetched.revision,
          group: 'change',
        );
    await restarted.exchange([edited]);
    final stale = fetched
        .copyWith(title: '첫 번째 기기 수정', revision: '1791154800000002:integration')
        .withSync(
          pending: true,
          baseRevision: fetched.revision,
          group: 'change',
        );
    final conflicted = await first.exchange([stale]);
    expect(conflicted.conflicts.single.entries.single.local.title, stale.title);
    expect(
      conflicted.conflicts.single.entries.single.remote!.title,
      edited.title,
    );
    await expectLater(
      restarted.restoreRecoveryAccount('A' * 32),
      throwsA(isA<ApiException>()),
    );
    expect(restarted.accountId, account);
    await restarted.signOut();
    final signedOut = CloudService(true, storage: storage);
    await signedOut.initialize();
    expect(signedOut.accountId, isNull);
    await first.signOut();
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('동기화 검증 완료'))),
    );
  });
}
