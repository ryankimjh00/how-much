# iOS 27 실행 호환성

## 1. 작업 출처
사용자 요청(2026-10-12), [Issue #12](https://github.com/ryankimjh00/how-much/issues/12).

## 2. 배경
iOS 27.0.1 아이폰에서 앱을 누르면 즉시 종료된다. 기존 iOS 설정에는 Xcode 27 / iOS 27 SDK가 요구하는 `UIScene` 선언이 없다. 실제 1.5.1(18) 종료 로그의 첫 프레임은 `UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption`이다.

## 3. 목표
기존 기록을 보존하면서 아이폰에서 업데이트 앱을 실행한다.

## 4. 범위
iOS 화면 시작·플러그인 등록 설정과 앱 버전. 저장·인증·동기화 데이터 구조는 유지한다.

## 5. 구현해야 할 것
- [x] `FlutterSceneDelegate`와 Main storyboard를 사용하는 단일 화면 선언
- [x] `FlutterImplicitEngineDelegate`에서 플러그인 등록
- [x] 앱 1.5.2(19), Flutter 최소 3.38 명시
- [x] 코드 검사·기존 테스트·iOS 서명 빌드
- [x] 아이폰 업데이트 설치·재실행

## 6. 현재 구현 상태
| 항목 | 상태 | 비고 |
|---|---|---|
| UIScene 설정 | 완료 | Flutter 3.38.5에 있는 공식 API 사용 |
| 검사·빌드 | 완료 | 포맷·analyze·27개 테스트, Xcode 27 / iOS 27 SDK 서명 release 빌드 |
| 아이폰 설치·실행 | 완료 | iPhone 17 / iOS 27.0.1, 1.5.1(18) → 1.5.2(19), 유선 설치·실행·재실행 |
| 기존 저장값 | 완료 | 업데이트 전후 모든 기존 preferences 값 일치 |
| 무선 연결 | 보류 | 동일 Wi-Fi에서도 기기 미발견. 사용자 유선 연결로 설치 완료 |

## 7. 다음에 바로 해야 할 것
아이폰에서 장보기·구매 기록과 카메라·앨범·한국어 OCR을 사용해 확인한다.

## 8. 후속에 구현해야 할 것
실기기 카메라·앨범·한국어 OCR과 배경 복귀 확인.

## 9. 결정된 사항
- [Flutter 공식 전환 절차](https://docs.flutter.dev/release/breaking-changes/uiscenedelegate)에 따라 `UIScene`을 사용한다.
- 엔진 초기화 후 플러그인을 등록한다. 별도 SceneDelegate 클래스는 추가하지 않는다.
- 번들 ID `com.todayone.todo`와 서명 팀 `2263MJ8YV6`를 유지하고 앱을 삭제하지 않고 업데이트한다.

## 10. 아직 결정되지 않은 사항
없음.

## 11. 임시 구현 / 주의사항
실기기 설치·실행·재실행과 기존 preferences 보존을 확인했다. 카메라·앨범·한국어 OCR의 실제 표본은 별도 확인이 필요하다. 종료 로그와 로컬 백업은 커밋하지 않는다. 운영 배포 전 남은 실기기 검증은 [배포 확인 문서](../release/pre-deploy-discussions.md)에 기록한다.

## 12. 변경 이력
- 2026-10-12: iOS 27 UIScene 시작 설정과 플러그인 등록 시점 수정.
- 2026-10-12: iOS 27.0.1 아이폰에 1.5.2(19) 업데이트 설치·재실행·기존 저장값 보존 확인.
