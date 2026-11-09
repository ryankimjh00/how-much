# AI-ANT 단계별 제출

## 대상

- 프로그램: [한성대학교 모바일 앱 미니프로젝트](https://miniproject.ai-ant.ai/programs/cmutwei4r0001mk0119a95flb/dashboard)
- 선택 세트: 데이터 관리형 앱 확장 MP세트 — 할 일 앱 클라우드·AI 확장형
- 대시보드에 표시된 운영 기간: 2026-11-03~2026-12-31. 수업의 별도 마감은 담당자 공지를 따른다.
- 제출 대상은 기존 `how-much`의 장보기 목록이다. 별도 SNS 앱을 만들지 않는다.
- 기준 소스: `develop`의 PR #22 병합 커밋 `d9e9ce4ab4f0343616a5151e739cff20c244ecdb`. 긴 영수증 이어붙이기를 포함하며 Flutter 3.47.5 / Dart 3.13.4로 검증한다.

## 단계와 현재 차이

| 단계 | 요구 사항 | 현재 구현과 확인할 내용 |
| --- | --- | --- |
| MP1 | 추가·완료·빈 상태, 실행 설명, 화면 4종 | 기존 UI로 검증·캡처 |
| MP2 | 수정·삭제·전체/완료/미완료 필터, 재시작 보존, 저장 방식 비교 | 기존 SharedPreferences 저장과 UI로 검증·캡처 |
| MP3 | Firebase/Supabase, 두 기기 동기화, 오프라인 복귀, 충돌 방침, 설정 예제 | 자체 FastAPI/PostgreSQL 구현으로 우선 제출. 독립 A/B 클라이언트·실제 오프라인 복귀 검증. 두 에뮬레이터 동시 실행·관리 콘솔 캡처는 미확보이며 대체 인정은 미확정. |
| MP4 | 기기 내 OCR, 선택·수정 저장, 비행기 모드, 사진 비보관, 권한 거부, 처리 시간 | 앱이 만든 임시 메모 사진을 성공·실패 모두 삭제하도록 보완. 저장소의 종이 메모 회귀 사진으로 실제 네이티브 OCR·선택 저장을 검증. 다른 손글씨 실패 해결과 구분한다. |

MP1·MP2의 prompts_log는 과제 화면에서 선택, MP3·MP4에서는 필수다. 모든 단계에 이번 대화의 실제 요청과 판단을 기록한다. 과거 개발 프롬프트나 학습 시간을 재구성하지 않는다.

## 실행 검증

`app/integration_test/ai_ant_submission_test.dart`는 가상 상품만 사용한다. SharedPreferences의 접두어를 분리하고 서버를 끈다. 기존 앱의 기록과 계정에 접근하지 않는다.

```sh
AI_ANT_EVIDENCE_DIR=<캡처-절대경로> ./scripts/app-local.sh flutter drive \
  --no-pub --keep-app-running \
  --driver=test_driver/ai_ant_submission.dart \
  --target=integration_test/ai_ant_submission_test.dart \
  --dart-define=API_BASE_URL= --dart-define=AI_ANT_PHASE=capture -d <기기-ID>
```

첫 실행 후 프로세스를 종료하고 `AI_ANT_PHASE=restore`로 다시 실행해 네이티브 저장 복원을 검증한다. OCR은 네트워크가 차단된 시험 기기에서 `AI_ANT_PHASE=ocr`, `AI_ANT_OFFLINE=true`로 실행한다. **`--keep-app-running`은 생략하지 않는다.** 기본 종료 정리의 앱 삭제를 막기 위한 옵션이다.

OCR 시험은 기본적으로 코드로 만든 1200×1000px 인쇄체 가상 메모를 사용한다. 이번 제출 검증에는 `AI_ANT_MEMO_PHOTO_BASE64`를 담은 비공개 JSON을 `--dart-define-from-file`로 전달해 저장소의 720×1280px 종이 장보기 메모 회귀 사진을 사용했다. 사진과 JSON은 제출 ZIP에 포함하지 않는다. 출제자가 배포한 픽스처라고 설명하지 않으며, 이 한 표본의 결과를 기존 다른 손글씨 실패 해결로 일반화하지 않는다.

실제 네이티브 OCR·파싱·임시 파일 삭제까지 214ms·78ms·58ms를 측정했다. 비행기 모드 켜짐·Wi-Fi 꺼짐 조건이며 `장보기` 머리글과 `양파 → 망파` 오인식도 원래 후보에 남겼다. 우유·두부만 선택하고 우유의 이름·수량을 고친 뒤 저장했다. 카메라 화면 캡처는 에뮬레이터의 선택 UI이며 물리 카메라 촬영 검증과 구분한다.

## 산출물

[제출 자료](../submissions/ai-ant/2026-11-09/README.md)에 실제 제출한 단계별 ZIP, 화면, 검증 결과와 제출 상태를 보관한다. 작업 중 원본은 로컬 `output/ai-ant/2026-11-09/`에 있다. ZIP 맨 위에 `app/`, `README.md`, `screenshots/`, `prompts_log.md`를 배치하고 MP3에는 `.env.example`을 추가한다. 각 ZIP은 20MB 이하로 확인한다.

현재 기능을 포함한 같은 소스 스냅샷을 단계별 요구사항에 맞춰 설명한다. 과거 단계별 개발 이력을 새로 만든 것처럼 표현하지 않는다. 빌드 산출물·캐시·로컬 설정·인증 정보·개인 사진·이전 내부 보고서는 제출본에서 제외한다.

## 2026-11-09 제출 결과

- MP1·MP2·MP4에 이어 사용자에게 전달된 교수님의 우선 제출 안내에 따라 MP3도 제출했다. 마이페이지의 제출 4건 모두 `검토 대기`를 확인했다. 대체 서버 인정·통과 판정은 아직 받지 않았다.
- 실제 제출한 네 ZIP을 다시 생성하지 않고 보관한다. SHA-256과 바이트 크기는 [manifest.json](../submissions/ai-ant/2026-11-09/manifest.json)에 있다. MP1·MP2·MP4의 앱 스냅샷은 같고 MP3에는 추가 동기화 통합 시험·서버 소스를 포함한다.
- Flutter 3.47.5/Dart 3.13.4, 정적 분석 이상 없음, Flutter 테스트 338개 통과·기존 1개 건너뜀. Android에서 UI·실제 네이티브 저장·프로세스 재시작·오프라인 OCR·실제 HTTPS 동기화와 오프라인 복귀를 확인했다. iOS 빌드와 물리 기기 검사는 이번에 실행하지 않았다.
- MP3는 한 에뮬레이터에서 Keystore·로컬 저장을 분리한 두 클라이언트를 순차 실행했다. 두 기기 동시 실행 검증과 다르며 관리 콘솔 캡처도 없다. 이 제약과 Firebase/Supabase 대신 자체 서버를 사용한 이유를 제출 README에 명시했다.
- 실습노트는 사용자가 알려준 시작 시각 13:30과 최초 검증·제출 준비가 끝난 14:08을 기록해 38분으로 저장했다. 이후 MP3 후속 검증은 이 시간에 포함하지 않았다.
- 제출 중 보완한 메모 사진 정리·수정창 수명 처리와 재현용 통합 시험도 함께 보관한다. 기존 사용자 변경은 PR에서 제외하고 원래 체크아웃에 보존했다.

## MP3 네트워크 전환 시험

`app/integration_test/ai_ant_sync_test.dart`는 실제 서버에 가상 목록을 만들고 A/B 보안 저장 영역을 분리한다. 시험용 에뮬레이터에서만 실행한다. 복구 코드·토큰은 로그나 보고서에 남기지 않는다.

```sh
AI_ANT_EVIDENCE_DIR=<캡처-절대경로> ./scripts/app-local.sh flutter drive \
  --no-pub --keep-app-running \
  --driver=test_driver/ai_ant_submission.dart \
  --target=integration_test/ai_ant_sync_test.dart -d <시험용-에뮬레이터-ID>
```

시험은 `Directory.systemTemp`의 `ai-ant-network-request` 파일로 호스트의 실제 네트워크 전환을 요청한다. 이번 Android 경로는 `code_cache/`였다. 요청이 `offline`이면 adb로 비행기 모드 켜기·Wi-Fi 끄기 후 상태를 확인하고 `ai-ant-network-ack`에 `offline`을 쓴다. 이후 `online` 요청에는 반대로 복구하고 연결을 기다린 뒤 같은 방식으로 확인한다. 입력·출력 파일에는 인증 정보가 없다. 시험이 끝나면 에뮬레이터의 네트워크를 복구한다.
