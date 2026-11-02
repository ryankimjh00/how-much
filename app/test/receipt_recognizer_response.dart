/// [OCR 추가] 저장된 테스트 글자·영역을 ML Kit 플러그인이 반환하는 응답 구조로 바꾼다.
/// 사진이나 모델은 실행하지 않는다. 고정된 입력으로 앱의 좌표 처리·실패 복구를 검사할 때만 쓴다.
/// 영역의 실수 좌표는 유지하고 네 모서리 점은 플러그인 형식에 맞춰 정수로 반올림한다.
/// 실제 ML Kit가 이 글자를 읽었다는 뜻이나 인식 정확도 측정 결과로 사용하면 안 된다.
Map<String, dynamic> mlkitResponseFromRecorded(Map<String, dynamic> response) {
  Map<String, dynamic> value(Map<String, dynamic> token) {
    final bounds = (token['bounds'] as List).cast<num>();
    return {
      'text': token['text'],
      'rect': {
        'left': bounds[0].toDouble(),
        'top': bounds[1].toDouble(),
        'right': bounds[2].toDouble(),
        'bottom': bounds[3].toDouble(),
      },
      'points': [
        for (final point in token['points'] as List)
          {'x': (point[0] as num).round(), 'y': (point[1] as num).round()},
      ],
      'recognizedLanguages': <String>[],
      'confidence': (token['confidence'] as num?)?.toDouble(),
      'angle': (token['angle'] as num?)?.toDouble(),
    };
  }

  // [OCR 추가] 저장된 한 줄을 블록 하나·줄 하나로 감싸고 그 안의 단어 영역은 별도로 넣는다.
  // 실제 결과의 블록 나누기를 재현하는 것이 아니라 고정 글자·좌표를 앱에 전달하기 위한 변환이다.
  return {
    'text': response['text'],
    'blocks': [
      for (final raw in response['lines'] as List)
        {
          ...value(Map<String, dynamic>.from(raw)),
          'lines': [
            {
              ...value(Map<String, dynamic>.from(raw)),
              'elements': [
                for (final element in raw['elements'] as List)
                  {...value(Map<String, dynamic>.from(element)), 'symbols': []},
              ],
            },
          ],
        },
    ],
  };
}
