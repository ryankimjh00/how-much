import 'package:flutter_test/flutter_test.dart';
import 'package:how_much/cloud_service.dart';
import 'package:how_much/recovery_code.dart';

class _AuthCloud extends CloudService {
  _AuthCloud() : super(true);
  String? email;
  String? password;
  bool? create;

  @override
  Future<void> signIn(
    String email,
    String password, {
    required bool create,
  }) async {
    this.email = email;
    this.password = password;
    this.create = create;
  }
}

void main() {
  test('이미 발급한 코드의 인증 규칙을 유지한다', () {
    const code = '2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ';
    expect(
      RecoveryCode.email(code),
      'e9bdf7fdae4d297c15e04b5f81e1a93e02b9f1acd779e6af396e9993db07f48a@recovery.howmuch.invalid',
    );
    expect(
      RecoveryCode.password(code),
      'Hmc!9a01018f9d80e6ed1820f2c003442b221073ba208763c771ba3d1b7113f64a6bb9',
    );
  });
  test('발급 코드와 소문자·공백 입력이 같은 인증 정보를 만든다', () async {
    final cloud = _AuthCloud();
    final code = await cloud.createRecoveryAccount();
    expect(code.split('-'), hasLength(8));
    expect(RecoveryCode.normalize(code), hasLength(32));
    expect(cloud.create, isTrue);
    final email = cloud.email;
    final password = cloud.password;

    await cloud.restoreRecoveryAccount(
      ' ${code.toLowerCase().replaceAll('-', ' ')} ',
    );

    expect(cloud.create, isFalse);
    expect(cloud.email, email);
    expect(cloud.password, password);
    expect(email, isNot(contains(RecoveryCode.normalize(code))));
    expect(password, isNot(contains(email!.split('@').first)));
    expect(RecoveryCode.email(RecoveryCode.generate()), isNot(email));
  });

  test('잘못된 코드는 서버 인증 전에 거부한다', () async {
    final cloud = _AuthCloud();
    for (final code in [
      '',
      'admin1234',
      '0' * 32,
      'I' * 32,
      'A' * 31,
      'A' * 33,
      'A' * 31 + '!',
    ]) {
      expect(() => cloud.restoreRecoveryAccount(code), throwsFormatException);
    }
    expect(cloud.email, isNull);
  });
}
