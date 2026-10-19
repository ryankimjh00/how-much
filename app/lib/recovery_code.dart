/// 복구 코드 자체가 로그인 비밀이다. 기기 보안 저장소 외에는 보관하지 않는다.
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

  /// 검증한 코드를 네 자리씩 나눠 표시한다.
  static String format(String input) {
    final code = normalize(input);
    return [
      for (var offset = 0; offset < code.length; offset += 4)
        code.substring(offset, offset + 4),
    ].join('-');
  }
}
