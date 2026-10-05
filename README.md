# 얼마였지 Flutter

장보기 메모와 영수증을 기기에서 인식하고, 구매 가격을 기록·비교하는 Flutter 앱입니다.

원본은 [jhshin23/howmuch-shin](https://github.com/jhshin23/howmuch-shin)의 `chore/include-app` 브랜치(커밋 `411f1c3`)입니다.

## 포함 기능

- 장보기 항목 추가·수정·삭제·완료·필터와 기기 저장
- 메모 사진 OCR 검토 후 선택 항목 추가
- 영수증 촬영·앨범 OCR, 직접 수정, 목록 연결, 부분 구매 처리
- 구매 이력 검색, 규격별 단가·차액·변동률 비교
- 복구 코드 발급·복원, 기존 이메일 로그인, 로컬 우선 자동 Firestore 동기화
- 충돌 선택과 계정별 기록 분리, 익명 가격 공유·해제
- Figma 기반 크림·오렌지 UI, 장보기·구매 기록 탭과 최근 30일 가격 비교

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

홈 우측 계정 버튼에서 **복구 코드 만들고 기록 연결**을 누르면 기기 기록을 새 계정으로 복사합니다. 발급된 코드는 한 번만 표시됩니다. 다른 기기에서는 **기존 기록 복원**에 코드를 입력합니다. 코드를 아는 사람은 기록에 접근할 수 있으므로 안전하게 보관해주세요.

기기에 저장한 뒤 700ms 후 서버에 반영하며, 앱 활성 상태에서 30초마다 서버 변경과 실패한 전송을 다시 확인합니다. 오프라인 기록과 충돌은 기기에 보존합니다. 복원한 계정에는 기기 기록을 자동으로 합치지 않습니다.

## 검사와 빌드

```sh
cd app
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --debug --no-codesign
```

Firebase 에뮬레이터 검증은 저장소 루트에서 실행합니다(Node.js와 Java 21 이상 필요).

```sh
npx --yes --package firebase-tools firebase emulators:exec \
  --project demo-howmuch --only auth,firestore \
  'python3 firebase/test_recovery.py'
```

기능과 남은 검증 범위는 [저장·복구 코드](docs/features/sync-recovery.md), [Figma UI](docs/features/figma-ui.md), 개발·한국어 주석 기준은 [AGENTS.md](AGENTS.md)에 있습니다.

Android 패키지명은 원본과 같은 `com.todayone.todo`입니다. React Native의 AsyncStorage와 Flutter의 SharedPreferences는 저장 형식이 달라 기존 기기 로컬 파일을 자동 변환하지 않습니다. 기존 이메일 계정의 Firestore 기록은 로그인 후 다시 동기화할 수 있습니다.

Release 빌드는 현재 Flutter 기본 debug 서명을 사용합니다. 배포 전 전용 키와 Firebase 실프로젝트 규칙을 확인해야 합니다.
