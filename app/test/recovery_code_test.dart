import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/recovery_code.dart';

class _RealNetwork extends HttpOverrides {}

class _ControlledStorage extends FlutterSecureStorage {
  bool failWrites = false;
  Completer<void>? readStarted;
  Completer<void>? readPause;

  @override
  Future<void> write({
    required String key,
    required String? value,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (failWrites) throw StateError('보안 저장 실패');
    await super.write(key: key, value: value);
  }

  @override
  Future<String?> read({
    required String key,
    AppleOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    AppleOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    final value = await super.read(key: key);
    readStarted?.complete();
    await readPause?.future;
    return value;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('복구 코드의 소문자·공백을 정규화하고 잘못된 입력을 거부한다', () {
    const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
    expect(
      RecoveryCode.normalize(code.toLowerCase().replaceAll('-', ' ')),
      '23456789ABCDEFGHJKLMNPQRSTUVWXYZ',
    );
    expect(RecoveryCode.format(RecoveryCode.normalize(code)), code);
    for (final code in [
      '',
      'admin1234',
      '0' * 32,
      'I' * 32,
      'A' * 31,
      'A' * 33,
    ]) {
      expect(() => RecoveryCode.normalize(code), throwsFormatException);
    }
    expect(
      () => CloudService(true, apiUrl: 'http://example.com'),
      throwsArgumentError,
    );
  });

  test('보안 저장한 코드는 재시작·만료 후 조회하고 로그아웃하면 제거한다', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final url = 'http://127.0.0.1:${server.port}';
      const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
      var token = 'first-token';
      var unauthorized = false;
      var rejectRestore = false;
      var accountId = 'account-one';
      var calls = 0;
      String? restored;
      server.listen((request) async {
        calls++;
        final body = await request
            .cast<List<int>>()
            .transform(utf8.decoder)
            .join();
        request.response.headers.contentType = ContentType.json;
        if (request.uri.path == '/v1/accounts' ||
            request.uri.path == '/v1/sessions') {
          if (body.isNotEmpty) {
            restored = (jsonDecode(body) as Map)['recoveryCode'] as String;
          }
          if (rejectRestore) {
            request.response.statusCode = 401;
            request.response.write('{"detail":"invalid code"}');
          } else {
            request.response.write(
              jsonEncode({
                'accountId': accountId,
                'token': token,
                'expiresAt': '2099-10-05T00:00:00+00:00',
                if (request.uri.path == '/v1/accounts') 'recoveryCode': code,
              }),
            );
          }
        } else if (unauthorized) {
          request.response.statusCode = 401;
          request.response.write('{"detail":"expired"}');
        } else {
          expect(request.headers.value('Authorization'), 'Bearer $token');
          request.response.write('{"rows":[],"conflicts":[]}');
        }
        await request.response.close();
      });
      final cloud = CloudService(true, apiUrl: url);
      expect(await cloud.readRecoveryCode(), isNull);
      expect(await cloud.createRecoveryAccount(), code);
      final saved = await const FlutterSecureStorage().readAll();
      expect(saved.values.single, contains('first-token'));
      expect(saved.values.single, contains(code));
      expect(await cloud.readRecoveryCode(), code);
      final restarted = CloudService(true, apiUrl: url);
      await restarted.initialize();
      expect(restarted.accountId, 'account-one');
      final beforeRead = calls;
      expect(await restarted.readRecoveryCode(), code);
      expect(calls, beforeRead);
      await restarted.exchange([]);
      unauthorized = true;
      await expectLater(restarted.exchange([]), throwsA(isA<ApiException>()));
      expect(restarted.accountId, 'account-one');
      expect(restarted.sessionExpired, isTrue);
      expect(await restarted.readRecoveryCode(), code);
      token = 'second-token';
      await restarted.restoreRecoveryAccount(
        code.toLowerCase().replaceAll('-', ' '),
      );
      expect(restored, RecoveryCode.normalize(code));
      expect(restarted.canSync, isTrue);
      expect(await restarted.readRecoveryCode(), code);
      final before = calls;
      await expectLater(
        restarted.restoreRecoveryAccount('bad'),
        throwsFormatException,
      );
      expect(calls, before);
      rejectRestore = true;
      await expectLater(
        restarted.restoreRecoveryAccount('B' * 32),
        throwsA(isA<ApiException>()),
      );
      expect(restarted.accountId, 'account-one');
      expect(await restarted.readRecoveryCode(), code);
      rejectRestore = false;

      final storage = const FlutterSecureStorage();
      final stored = await storage.readAll();
      final legacy = Map<String, Object?>.from(
        jsonDecode(stored.values.single) as Map,
      )..remove('recoveryCode');
      await storage.write(key: stored.keys.single, value: jsonEncode(legacy));
      final legacyCloud = CloudService(true, apiUrl: url);
      await legacyCloud.initialize();
      expect(legacyCloud.accountId, 'account-one');
      expect(await legacyCloud.readRecoveryCode(), isNull);
      await legacyCloud.restoreRecoveryAccount(
        code,
        expectedAccountId: 'account-one',
      );
      expect(await legacyCloud.readRecoveryCode(), code);

      accountId = 'account-two';
      await expectLater(
        legacyCloud.restoreRecoveryAccount(
          'B' * 32,
          expectedAccountId: 'account-one',
        ),
        throwsFormatException,
      );
      expect(legacyCloud.accountId, 'account-one');
      expect(await legacyCloud.readRecoveryCode(), code);
      await legacyCloud.restoreRecoveryAccount('B' * 32);
      expect(legacyCloud.accountId, 'account-two');
      expect(
        await legacyCloud.readRecoveryCode(),
        RecoveryCode.format('B' * 32),
      );
      expect((await storage.readAll()).values.single, isNot(contains(code)));
      final otherServer = CloudService(true, apiUrl: '$url/other');
      await otherServer.initialize();
      expect(otherServer.accountId, isNull);
      expect(await otherServer.readRecoveryCode(), isNull);
      await legacyCloud.signOut();
      expect(legacyCloud.accountId, isNull);
      expect(await legacyCloud.readRecoveryCode(), isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
    }, _RealNetwork());
  });

  test('보안 저장 실패는 기존 계정과 코드를 유지하고 로그아웃 중 늦은 조회는 차단한다', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      var account = 'account-one';
      server.listen((request) async {
        await request.drain<void>();
        request.response.write(
          jsonEncode({
            'accountId': account,
            'token': '$account-token',
            'expiresAt': '2099-10-05T00:00:00+00:00',
          }),
        );
        await request.response.close();
      });
      final storage = _ControlledStorage();
      final cloud = CloudService(
        true,
        apiUrl: 'http://127.0.0.1:${server.port}',
        storage: storage,
      );
      await cloud.restoreRecoveryAccount('A' * 32);
      final saved = await storage.readAll();
      storage.failWrites = true;
      account = 'account-two';
      await expectLater(
        cloud.restoreRecoveryAccount('B' * 32),
        throwsStateError,
      );
      expect(cloud.accountId, 'account-one');
      expect(await storage.readAll(), saved);
      expect(await cloud.readRecoveryCode(), RecoveryCode.format('A' * 32));

      storage.readStarted = Completer<void>();
      storage.readPause = Completer<void>();
      final reading = expectLater(
        cloud.readRecoveryCode(),
        throwsFormatException,
      );
      await storage.readStarted!.future;
      await cloud.signOut();
      storage.readPause!.complete();
      await reading;
      expect(await cloud.readRecoveryCode(), isNull);
      expect(await storage.readAll(), isEmpty);
    }, _RealNetwork());
  });

  test('이전 세션의 늦은 401은 새 세션을 만료시키지 않는다', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final waiting = Completer<HttpRequest>();
      var token = 'old-token';
      server.listen((request) async {
        await request.drain<void>();
        if (request.uri.path == '/v1/sync') {
          waiting.complete(request);
          return;
        }
        request.response.write(
          jsonEncode({
            'accountId': 'account-one',
            'token': token,
            'expiresAt': '2099-10-05T00:00:00+00:00',
          }),
        );
        await request.response.close();
      });
      final cloud = CloudService(
        true,
        apiUrl: 'http://127.0.0.1:${server.port}',
      );
      await cloud.restoreRecoveryAccount('A' * 32);
      final failed = expectLater(
        cloud.exchange([]),
        throwsA(isA<ApiException>()),
      );
      final request = await waiting.future;
      token = 'new-token';
      await cloud.restoreRecoveryAccount('A' * 32);
      request.response.statusCode = 401;
      request.response.write('{"detail":"expired"}');
      await request.response.close();
      await failed;
      expect(cloud.canSync, isTrue);
    }, _RealNetwork());
  });
}
