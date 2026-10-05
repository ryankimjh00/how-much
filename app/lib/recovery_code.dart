/// 복구 코드 자체가 로그인 비밀이다. 원문은 저장하거나 로그에 남기지 않는다.
abstract final class RecoveryCode {
  static const _alphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

  static String normalize(String input) {
    final code = input.toUpperCase().replaceAll(RegExp(r'[\s-]'), '');
    if (code.length != 32 ||
        code.split('').any((character) => !_alphabet.contains(character))) {
      throw const FormatException('복구 코드 32자리를 확인해주세요.');
    }
    return code;
  }
}
