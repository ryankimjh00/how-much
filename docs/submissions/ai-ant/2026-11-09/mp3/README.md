# 얼마였지 — MP3 자체 서버 동기화

## 제출 범위와 지정 기술과의 차이

Firebase/Supabase 대신 기존 FastAPI/PostgreSQL 서버를 사용한 제출입니다.
사용자가 전달한 교수님의 “일단 제출해 보라”는 안내에 따라 현재 구현과 검증 자료를 제출합니다.
이는 자체 서버의 대체 인정 또는 통과 판정을 받았다는 뜻이 아닙니다.

- `app/`: Flutter 앱, `server/`: FastAPI·PostgreSQL 소스와 Swagger 계약.
- 기준 소스: develop의 PR #22 병합 커밋 `d9e9ce4ab4f0343616a5151e739cff20c244ecdb`와 제출 준비 중 메모 사진 정리·수정창 오류 보완.
- 이미 사용 중인 복구 코드 인증·로컬 우선 저장·충돌 처리를 유지하기 위해 자체 서버를 그대로 사용했습니다.
- Firebase/Supabase SDK와 관리 콘솔은 없습니다. 이번 자료에 백엔드 관리 콘솔 캡처는 포함하지 못했습니다.
- 실제 에뮬레이터는 한 대입니다. 앱의 보안 저장 영역과 로컬 저장 접두어를 A/B로 분리한 독립 클라이언트 두 개를 순서대로 실행했습니다. 두 에뮬레이터 동시 실행 요건을 확인한 자료로 설명하지 않습니다.

## 실제 HTTPS 동기화 검증

Android API 36.1 arm64 에뮬레이터, 실제 Flutter UI·SharedPreferences·Keystore·운영 HTTPS API를 사용했습니다. 시험 계정에는 가상 상품 두 개만 저장하며 기존 사용자의 계정과 기록에 접근하지 않았습니다.

1. A에서 `AI-ANT 검증 우유`를 추가하고 서버 전송 후 미전송 수 0 확인.
2. 초기 목록이 비어 있는 B에서 같은 복구 코드로 연결 후 서버 새로고침. 우유가 나타남.
3. A로 돌아와 호스트 adb로 비행기 모드를 켜고 Wi-Fi를 끔. `오프라인 검증 두부`를 로컬에 저장한 뒤 실제 동기화 요청 실패와 미전송 수 1을 확인.
4. 비행기 모드 해제·Wi-Fi 연결 후 A의 동기화를 다시 요청. 미전송 수 0과 `동기화 완료` 확인.
5. B가 서버를 다시 읽어 두부를 받는지 확인.

화면 5장과 `sync-report.json`은 이 실행에서 생성했습니다. 화면 자체에 네트워크·미전송 상태 배지를 추가하지 않았으며 해당 조건은 통합 시험의 검증문과 JSON에 기록했습니다.
재연결 시험은 명시적 동기화 호출로 수행했습니다. 자동 30초 재시도 시간은 이 시험에서 측정하지 않았습니다.

## 동기화와 충돌 방침

- 로컬 JSON 저장이 성공한 뒤 화면에 반영합니다. 서버 실패 시 미전송 변경을 남깁니다.
- 평상시 변경 후 700ms에 동기화를 예약하고 앱이 열려 있으면 30초마다 재시도합니다.
- 계정마다 로컬 기록을 분리합니다. 계정 변경 뒤 도착한 이전 요청의 결과는 새 계정에 쓰지 않습니다.
- 서버는 변경 그룹의 `baseRevision`과 현재 리비전을 비교하고 트랜잭션으로 처리합니다.
- 충돌 시 로컬·서버 값을 모두 보존하고 사용자에게 선택을 받습니다. 오래된 변경으로 서버 값을 조용히 덮어쓰지 않습니다.
- 토큰과 복구 코드는 Keychain/Keystore에 보관합니다. 보고서·스크린샷·.env에 넣지 않았습니다. 서버는 해시만 보관합니다.

## 설정과 실행

Flutter 3.47.5 / Dart 3.13.4, Android SDK 또는 Xcode가 필요합니다. 기존 Flutter 3.38.5는 dartcv4 의존성과 충돌합니다. CMake·Ninja를 PATH에 준비합니다.

```sh
cd app
flutter pub get --enforce-lockfile
flutter run --dart-define=API_BASE_URL=https://howmuch.monithub.org
```

앱이 `.env`를 자동으로 읽지는 않습니다. `.env.example`은 설정 키 목록이며 앱 주소는 `--dart-define`, 서버 DB 주소는 실행 환경 변수로 전달합니다. 공개 서버 주소는 인증 비밀이 아닙니다.
계정 메뉴에서 새 복구 코드를 만들고 다른 기기에 같은 코드를 입력하면 연결됩니다. 복구 코드는 공개하거나 ZIP에 넣지 않습니다.

자체 백엔드는 `server/README.md`의 PostgreSQL 로컬 실행·FastAPI 실행 절차를 따릅니다. `DATABASE_URL`이 필수이며 프록시 환경의 `ROOT_PATH`는 선택입니다. 서버 스키마·요청·응답 예제는 `server/schema.sql`, `server/models.py`, `server/openapi.json`에 있습니다.
[공개 Swagger UI](https://howmuch.monithub.org/docs)는 현재 브라우저에서 404로 열려 콘솔 증거를 확보하지 못했습니다. HTTPS 앱의 인증·동기화 시험과 `/health` 200 응답은 별도로 성공했습니다.

## 통합 시험 재현

`integration_test/ai_ant_sync_test.dart`와 `test_driver/ai_ant_submission.dart`를 사용합니다.

```sh
AI_ANT_EVIDENCE_DIR=<캡처-절대경로> ./scripts/app-local.sh flutter drive \
  --no-pub --keep-app-running \
  --driver=test_driver/ai_ant_submission.dart \
  --target=integration_test/ai_ant_sync_test.dart -d <시험용-에뮬레이터-ID>
```

시험 중 `Directory.systemTemp`의 `ai-ant-network-request`가 `offline` 또는 `online`이 되면 호스트가 adb로 비행기 모드와 Wi-Fi를 전환합니다. 실제 네트워크 상태를 확인한 뒤 같은 폴더의 `ai-ant-network-ack`에 해당 값을 씁니다. 이번 Android 경로는 앱의 `code_cache/`였습니다. 코드는 호스트 확인을 최대 180초 기다립니다. 실제 사용자 기기에서 실행하지 않습니다.

## 추가 제약

- 이번에 iOS 빌드·두 물리 기기·두 에뮬레이터 동시 실행을 검증하지 않았습니다.
- 빌드·캐시·실제 설정·개인 원본 사진을 제외했습니다. iOS RunnerTests의 원본 사진 기반 검사는 원본 저장소에서 별도로 실행해야 합니다.
- 공개 서버에서 시험용 계정과 가상 목록을 사용했습니다. 계정 삭제 기능이 없어 시험 목록은 서버에 남으며 시험 세션은 종료 시 폐기했습니다.
