# 얼마였지 Flutter

장보기 메모와 영수증을 기기에서 인식하고, 구매 가격을 기록·비교하는 Flutter 앱입니다.

원본은 [jhshin23/howmuch-shin](https://github.com/jhshin23/howmuch-shin)의 `chore/include-app` 브랜치(커밋 `411f1c3`)입니다.

## 포함 기능

- 장보기 항목 추가·수정·삭제·완료·필터와 기기 저장
- 메모 사진 OCR 검토 후 선택 항목 추가
- 영수증 촬영·앨범 OCR, 직접 수정, 목록 연결, 부분 구매 처리
- 구매 이력 검색, 규격별 단가·차액·변동률 비교
- 이메일 로그인, Firestore 동기화, 익명 가격 공유·해제

## 실행

Flutter 3.38.5 / Dart 3.10.4 기준입니다. Android 7.0(API 24), iOS 15.5 이상을 지원합니다.

```sh
cd app
flutter pub get
flutter run
```

Firebase 없이도 로컬 기능은 동작합니다. 로그인·동기화가 필요하면 [Firebase 설정](firebase/README.md) 후 공개 설정값을 전달합니다.

```sh
flutter run \
  --dart-define=FIREBASE_API_KEY=... \
  --dart-define=FIREBASE_APP_ID=... \
  --dart-define=FIREBASE_MESSAGING_SENDER_ID=... \
  --dart-define=FIREBASE_PROJECT_ID=... \
  --dart-define=FIREBASE_AUTH_DOMAIN=...
```

## 검사와 빌드

```sh
cd app
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Android 패키지명은 원본과 같은 `com.todayone.todo`입니다. React Native의 AsyncStorage와 Flutter의 SharedPreferences는 저장 형식이 달라 기존 기기 로컬 파일을 자동 변환하지 않습니다. 기존 이메일 계정의 Firestore 기록은 로그인 후 다시 동기화할 수 있습니다.

Release 빌드는 현재 Flutter 기본 debug 서명을 사용합니다. 배포 전 전용 키와 Firebase 실프로젝트 규칙을 확인해야 합니다.
