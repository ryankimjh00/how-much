# 클러스터 인증·동기화

상태: 결정됨 · 2026-10-05 · #8·#9·#10

사용자가 Firebase 대신 자신의 클러스터와 PVC 약 2GB를 선택했다. [이전 Firebase 인증 설계](0001-recovery-code-auth.md)를 대체한다.

FastAPI의 Swagger 생성과 PostgreSQL의 트랜잭션·행 잠금을 사용한다. 별도 인증 서버·JWT·메시지 큐는 두지 않는다. 난수 복구 코드의 목적별 SHA-256 해시로 계정을 찾고, 난수 세션의 해시로 요청을 인증한다. 원문 코드는 저장하지 않는다. 세션만 Keychain/Keystore에 저장한다.

로컬 v4 데이터와 계정별 SharedPreferences 키, 변경 그룹·baseRevision 충돌 규칙은 유지한다. HTTPS 요청이 실패해도 기기 기록을 버리지 않는다. 세션 만료 때도 계정의 로컬 기록을 유지하며 코드를 다시 입력받는다.

PVC 2Gi·PostgreSQL 1개·Longhorn 복제 1개로 시작한다. API는 제한된 DB 역할과 네트워크 정책을 사용한다. 가용성과 자동 백업은 후속 작업이다. 별도 호스트 `howmuch.monithub.org`에는 전용 인증서와 Gateway를 추가해 공용 Argo 관리 Gateway를 변경하지 않는다.

실제 Firebase 프로젝트가 연결된 적 없는 설치본의 guest 기록은 그대로 가져온다. 과거 Firebase 이메일·복구 코드 계정과 UID는 이 서버에 자동 이관하지 않는다. 필요하면 별도 검증된 이관 작업으로 다룬다.
