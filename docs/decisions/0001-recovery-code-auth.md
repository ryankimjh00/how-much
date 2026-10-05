# 복구 코드 인증 v1

상태: 결정됨 · 2026-10-05 · Issue #5

Firebase 이메일 계정을 사용하는 현재 앱에서, 별도 서버 배포 없이 복구 코드로 같은 UID와 기록에 접근해야 한다.

32문자(160비트) 난수 코드를 만들고 대문자·공백/하이픈 정규화 후 서로 다른 용도의 SHA-256 해시를 계산한다.

```text
코드: 2345-6789-ABCD-EFGH-JKLM-NPQR-STUV-WXYZ (테스트 예시)
정규화: 23456789ABCDEFGHJKLMNPQRSTUVWXYZ
주소: SHA256("howmuch:recovery:v1:identity:" + 코드) + "@recovery.howmuch.invalid"
비밀번호: "Hmc!9a" + SHA256("howmuch:recovery:v1:password:" + 코드)
```

발급은 Firebase `createUserWithEmailAndPassword`, 복원은 `signInWithEmailAndPassword`로 처리한다. 코드 원문은 보관하지 않는다. 주소 해시만 알아도 비밀번호 해시를 계산할 수는 없다. 데이터 접근은 코드 문자열 비교 대신 Firebase UID와 기존 Firestore 규칙으로 제한한다.

기존 이메일 계정의 인증 정보는 바꾸지 않는다. 코드 계정의 메일 수신·비밀번호 재설정·코드 교체는 지원하지 않는다. 교체·폐기와 기존 이메일 계정 연결이 필요하면 서버에서 별도 자격 증명과 custom token을 관리하는 방식을 검토한다.

v1 접두사·도메인·문자 집합·정규화·해시 규칙은 발급된 코드와 호환돼야 한다. 이를 고정값 테스트와 Firebase 에뮬레이터 테스트로 검증한다.
