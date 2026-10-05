# 얼마였지 Flutter

장보기 메모와 영수증을 기기에서 인식하고, 구매 가격을 기록·비교하는 Flutter 앱입니다.

원본은 [jhshin23/howmuch-shin](https://github.com/jhshin23/howmuch-shin)의 `chore/include-app` 브랜치(커밋 `411f1c3`)입니다.

## 포함 기능

- 장보기·구매 기록 기기 저장, 메모·영수증 OCR 검토
- 규격별 단가·차액·변동률 비교와 익명 가격 공유·해제
- 복구 코드 발급·복원, 로컬 우선 자동 동기화, 충돌 선택
- Figma 기반 크림·오렌지 UI와 최근 30일 가격 비교
- Kubernetes FastAPI·PostgreSQL 서버, DB PVC 2Gi

## 실행

Flutter 3.38.5 / Dart 3.10.4 기준입니다. Android 7.0(API 24), iOS 15.5 이상을 지원합니다.

```sh
cd app
flutter pub get
flutter run
```

기본 서버는 `https://howmuch.monithub.org`입니다. 다른 서버는 `--dart-define=API_BASE_URL=https://...`로 지정합니다. 로컬 기능만 사용할 때는 `--dart-define=API_BASE_URL=`로 실행합니다. HTTP는 localhost 테스트만 허용합니다.

홈 우측 계정 버튼에서 **복구 코드 만들고 기록 연결**을 누르면 기기 기록을 새 계정으로 복사합니다. 코드는 한 번만 표시하므로 안전하게 보관해주세요. 다른 기기에서는 **기존 기록 복원**에 코드를 입력합니다. 코드를 아는 사람은 기록에 접근할 수 있습니다.

기기에 저장한 뒤 700ms 후 서버에 반영하고, 앱 활성 상태에서 30초마다 변경·실패한 전송을 확인합니다. 오프라인 기록과 충돌은 기기에 보존합니다. 복원한 계정에는 guest 기록을 자동으로 합치지 않습니다. 인증 세션은 Keychain/Keystore에만 저장합니다. 세션이 만료돼도 계정의 기기 기록은 유지합니다.

## 검사와 빌드

```sh
cd app
flutter analyze
flutter test
flutter build apk --debug
flutter build ios --release
# USB로 연결한 실제 기기 Keychain·HTTPS 테스트. 일반 앱 기록과 분리된 저장 영역을 사용합니다.
flutter drive --driver=test_driver/integration_test.dart \
  --target=integration_test/cluster_sync_test.dart -d <기기-ID>
```

[서버·Swagger·테스트](server/README.md), [배포·백업·재시작 검증](deploy/README.md), [기능 상태](docs/features/cluster-sync.md), [Figma UI](docs/features/figma-ui.md), [개발·한국어 주석 기준](AGENTS.md)을 확인합니다.

기존 Flutter guest 기록 저장 키와 v4 형식은 유지합니다. Firebase SDK·이메일 로그인은 클러스터의 복구 코드 인증으로 교체했습니다. 이전 Firebase 계정과 Firestore 기록의 자동 이관은 포함하지 않으며 `firebase/`는 이전 구현 참고 자료입니다. React Native AsyncStorage도 자동 변환하지 않습니다.

패키지명은 기존과 같은 `com.todayone.todo`, 버전은 1.5.1(18)입니다. Android release는 아직 debug 서명을 사용하므로 스토어 배포 전 운영 키가 필요합니다. 클러스터는 단일 DB·단일 볼륨 복제이며 자동 백업은 후속 작업입니다.
