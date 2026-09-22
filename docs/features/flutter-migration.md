# React Native 앱 Flutter 마이그레이션

- 상태: 완료
- 작업 출처: GitHub #1

## 배경

팀원이 만든 React Native 앱을 팀 저장소의 Flutter 앱으로 이전한다.

## 목표

장보기, OCR, 구매 이력, 가격 비교, 계정 동기화의 핵심 흐름을 Flutter에서 제공한다.

## 범위

- Android와 iOS Flutter 앱
- 로컬 저장, 카메라·앨범 OCR
- Firebase 이메일 인증과 Firestore 동기화
- 자동 분석·단위·위젯 테스트

## 구현해야 할 것

- 원본 `chore/include-app` 기능을 Flutter 모델·화면으로 변환
- 원본 Android 패키지명과 Firebase 서버 경로 유지
- 실행·설정·검증 방법 문서화

## 현재 구현 상태

- 목록 CRUD, 필터, 로컬 복원: 완료
- 메모·영수증 OCR과 검토: 완료
- 부분 구매, 이력, 가격 비교: 완료
- 로그인, 개인 동기화, 공개 가격: 완료
- 정적 분석·자동 테스트: 완료
- Android debug APK: 빌드 완료
- iOS 무서명 빌드: Xcode의 iOS 26.4 플랫폼 미설치로 기기 대상 검증 보류

## 다음에 바로 해야 할 것

- 실기기에서 카메라 권한, 한국어 OCR, Firebase 실프로젝트 동기화 확인
- Xcode Settings > Components에서 iOS 26.4 플랫폼 설치 후 무서명 빌드 재확인
- 운영용 Android/iOS 서명 설정

## 후속에 구현해야 할 것

- React Native AsyncStorage 로컬 파일의 자동 이관이 필요해질 경우 네이티브 변환 도구 추가
- 장기 대규모 사용 시 Firestore 단일 스냅샷 문서를 구매 단위 문서로 분리

## 결정된 사항

- Android 패키지명은 `com.todayone.todo` 유지
- Firebase가 없어도 로컬 사용 가능
- OCR 결과는 기본 미선택이며 사용자 확인 후 저장

## 아직 결정되지 않은 사항

- 앱스토어 배포 계정과 운영 서명 키
- Firebase 운영 프로젝트 값

## 임시 구현 / 주의사항

- Release 빌드는 Flutter 기본 debug 서명을 사용한다.
- 자동 테스트는 실제 카메라·실서버 OCR 정확도를 보장하지 않는다.

## 변경 이력

- 2026-09-22: Flutter 전환, 테스트·문서·플랫폼 설정 완료
