import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/recovery_code.dart';

class _RealNetwork extends HttpOverrides {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('복구 코드의 소문자·공백을 정규화하고 잘못된 입력을 거부한다', () {
    const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
    expect(
      RecoveryCode.normalize(code.toLowerCase().replaceAll('-', ' ')),
      '23456789ABCDEFGHJKLMNPQRSTUVWXYZ',
    );
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

  test('보안 저장소에는 세션만 남기고 재시작·만료·재연결·로그아웃을 처리한다', () async {
    await HttpOverrides.runWithHttpOverrides(() async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(() => server.close(force: true));
      final url = 'http://127.0.0.1:${server.port}';
      const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
      var token = 'first-token';
      var unauthorized = false;
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
          request.response.write(
            jsonEncode({
              'accountId': 'account-one',
              'token': token,
              'expiresAt': '2099-10-05T00:00:00+00:00',
              'recoveryCode': code,
            }),
          );
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
      expect(await cloud.createRecoveryAccount(), code);
      final saved = await const FlutterSecureStorage().readAll();
      expect(saved.values.single, contains('first-token'));
      expect(saved.values.single, isNot(contains('2345-6789')));
      final restarted = CloudService(true, apiUrl: url);
      await restarted.initialize();
      expect(restarted.accountId, 'account-one');
      await restarted.exchange([]);
      unauthorized = true;
      await expectLater(restarted.exchange([]), throwsA(isA<ApiException>()));
      expect(restarted.accountId, 'account-one');
      expect(restarted.sessionExpired, isTrue);
      token = 'second-token';
      await restarted.restoreRecoveryAccount(
        code.toLowerCase().replaceAll('-', ' '),
      );
      expect(restored, RecoveryCode.normalize(code));
      expect(restarted.canSync, isTrue);
      final before = calls;
      await expectLater(
        restarted.restoreRecoveryAccount('bad'),
        throwsFormatException,
      );
      expect(calls, before);
      final otherServer = CloudService(true, apiUrl: '$url/other');
      await otherServer.initialize();
      expect(otherServer.accountId, isNull);
      await restarted.signOut();
      expect(restarted.accountId, isNull);
      expect(await const FlutterSecureStorage().readAll(), isEmpty);
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
