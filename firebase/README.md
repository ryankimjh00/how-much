# 이전 Firebase 설정

현재 앱은 [클러스터 API](../server/README.md)를 사용합니다. 이 폴더는 이전 Firebase 구현의 참고 자료이며 현재 앱과 연결되지 않습니다.

## 이전 버전 설정

1. Firebase Authentication에서 이메일/비밀번호 로그인을 활성화합니다.
2. Firestore를 생성하고 `firestore.rules`를 게시합니다.
3. 앱 실행 시 공개 Firebase 설정값을 `--dart-define`으로 전달합니다.

앱은 개인 데이터를 `accounts/{uid}/state/main`에 저장합니다. 공개를 선택한 비교 가격만 `sharedPrices`에 복사하며 UID, 이메일, 장보기 항목 ID, 원본 사진은 포함하지 않습니다.

## 복구 코드 계정

- 사용자가 `복구 코드 만들고 기록 연결`을 선택하면 32문자 복구 코드로 새 Firebase 비밀번호 계정을 만듭니다.
- `기존 기록 복원`은 같은 코드의 주소·비밀번호 해시로 기존 UID에 로그인합니다. 존재하지 않는 코드는 새 계정을 만들지 않습니다.
- 복구 코드 원문은 발급 화면에서 한 번만 표시합니다. 기기 설정과 Firestore에는 저장하지 않습니다.
- 내부 주소는 `64자리 SHA-256 해시@recovery.howmuch.invalid`이며 실제 수신 주소가 아닙니다. 해당 계정에 이메일 인증 필수 정책이나 비밀번호 재설정 메일을 적용하지 않습니다.
- 비밀번호는 대·소문자, 숫자, 기호가 포함된 70문자입니다. 운영 비밀번호 정책과 앱 설정의 호환성을 확인합니다.
- 기존 이메일/비밀번호 계정은 그대로 사용합니다. 기존 계정에 복구 코드를 추가하거나 코드를 교체하는 기능은 포함하지 않습니다.
- 상세 규칙과 예시는 [인증 v1 ADR](../docs/decisions/0001-recovery-code-auth.md)을 확인합니다.

## 저장 계약

```text
accounts/{Firebase UID}/state/main
version: 4
rows: { "항목 ID": { id, title, completed, deleted, revision, quantity?, note?, purchase? } }
```

앱의 로컬 `pending`, `baseRevision`, `group`, 충돌 보관 데이터는 서버에 전송하지 않습니다. 서버는 Firebase 비밀번호 인증과 문서 경로의 UID가 같은 사용자만 읽고 쓸 수 있습니다. 계정 확인만 한 경우 같은 문서를 다시 쓰지 않습니다.

## 로컬 에뮬레이터 검사

루트 README의 `demo-howmuch` 명령으로 `test_recovery.py`를 실행합니다. 동일 코드의 UID와 기록 복원, 잘못된 코드 거부, 다른 UID·비인증 접근 차단을 확인합니다. 실제 Firebase 프로젝트와 실제 두 기기의 동기화는 별도 확인이 필요합니다.

규칙에는 기존 React Native 앱 경로도 남겨 이전 버전과의 서버 호환성을 유지했습니다.
