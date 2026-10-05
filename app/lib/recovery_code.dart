import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// 복구 코드 자체가 로그인 비밀이다. 원문은 저장하거나 로그에 남기지 않는다.
abstract final class RecoveryCode {
  // 혼동하기 쉬운 0/O, 1/I를 빼고 32개 문자로 160비트 난수를 만든다.
  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';
  static const emailDomain = 'recovery.howmuch.invalid';

  static String generate() {
    final random = Random.secure();
    final code = List.generate(
      32,
      (_) => _alphabet[random.nextInt(_alphabet.length)],
    ).join();
    return List.generate(
      8,
      (index) => code.substring(index * 4, index * 4 + 4),
    ).join('-');
  }

  static String normalize(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != 32 ||
        code.split('').any((character) => !_alphabet.contains(character))) {
      throw const FormatException('복구 코드 32자리를 확인해주세요.');
    }
    return code;
  }

  // 코드에서 서로 다른 해시를 만들어 Firebase의 기존 비밀번호 인증을 사용한다.
  // 주소는 식별자일 뿐이며, 주소만으로 로그인 비밀을 알아낼 수 없다.
  static String email(String input) =>
      '${_digest('identity', normalize(input))}@$emailDomain';

  static String password(String input) =>
      'Hmc!9a${_digest('password', normalize(input))}';

  static String _digest(String purpose, String code) => sha256
      .convert(utf8.encode('howmuch:recovery:v1:$purpose:$code'))
      .toString();
}
