# Firebase 설정

1. Firebase Authentication에서 이메일/비밀번호 로그인을 활성화합니다.
2. Firestore를 생성하고 `firestore.rules`를 게시합니다.
3. 앱 실행 시 공개 Firebase 설정값을 `--dart-define`으로 전달합니다.

앱은 개인 데이터를 `accounts/{uid}/state/main`에 저장합니다. 공개를 선택한 비교 가격만 `sharedPrices`에 복사하며 UID, 이메일, 장보기 항목 ID, 원본 사진은 포함하지 않습니다.

규칙에는 기존 React Native 앱 경로도 남겨 이전 버전과의 서버 호환성을 유지했습니다.
