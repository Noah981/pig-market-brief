# 돈돈해 무료 전국 푸시 출시 연결

현재 PR은 연결 준비본이며 실제 FCM 기기 수신이 검증된 최종본이 아닙니다.

## 무료 구성

기존 공개 GitHub 저장소의 공식 수집기를 24시간 5분 간격으로 실행하고 Firebase Spark의 무료 FCM으로 발송합니다. Cloud Functions, 유료 서버, 결제 계정은 사용하지 않습니다. 공식 공표 및 GitHub Actions 대기로 지연될 수 있습니다.

전국의 새 공식 확진 발생만 발송합니다. 첫 연결은 과거 발생 목록을 조용히 기준선으로 저장합니다. 의심, 음성, 해제, 종식, 해외 및 통계에서 추정한 발생은 발송하지 않습니다. 실제 공개 발생 내역이 없는 질병은 알림을 만들지 않습니다.

## 필요한 계정 설정

1. Firebase 무료 Spark 프로젝트에 기존 Android 패키지 `com.example.dondonhae`를 등록합니다. Android 설정 파일 `google-services.json`을 내려받습니다.
2. Firebase Cloud Messaging HTTP v1 API를 활성화하고 발송 서비스 계정에 Firebase Cloud Messaging API Admin 권한을 부여합니다. 계정 개인 키를 채팅이나 공개 저장소에 넣지 않습니다.
3. 저장소 Settings → Secrets and variables → Actions에 아래 비밀값을 등록합니다.

| 비밀값 | 내용 |
|---|---|
| DDH_FIREBASE_PROJECT_ID | Firebase 프로젝트 ID |
| DDH_FIREBASE_ANDROID_CONFIG_B64 | google-services.json의 Base64 값 |
| DDH_FCM_SERVICE_ACCOUNT_JSON | 해당 프로젝트의 발송 서비스 계정 JSON |
| DDH_ANDROID_KEYSTORE_B64 | 기존 배포용 PKCS12 키의 Base64 값 |
| DDH_ANDROID_KEYSTORE_PASSWORD | 기존 키 비밀번호 |

기존 서명키를 유지합니다. 새 키를 생성해 기존 앱 서명을 교체하지 않습니다.

## 최종 검증 순서

계정 연결 이후 FCM validate_only로 실제 발송 권한을 검증합니다. 전국 푸시 워크플로를 첫 실행해 조용한 기준선을 저장합니다. 알림 권한을 허용한 실제 Android 기기에서 앱을 한 번 열어 구독한 후 홈으로 이동한 상태, 최근 앱에서 제거한 상태, 잠금 화면과 야간의 돈가·질병 푸시를 확인합니다. 테스트 발송은 운영 질병 주제를 이용해 가짜 발생을 공지하지 않고 테스트 기기 토큰으로만 수행합니다.

Android 설정에서 강제 종료한 앱은 다시 열어야 수신이 재개됩니다. 방해 금지·알림 권한·기기 제조사 절전 정책은 시스템 설정을 따릅니다.

Verified Play Store bundle 워크플로는 실제 Firebase 연결, 공식 데이터, 회귀 테스트, 기존 서명, Android API 36과 APK 16KB 정렬을 확인한 경우에만 AAB와 APK를 만듭니다. 기기 수신 확인과 Play 내부 테스트가 완료되기 전에는 최종본으로 배포하지 않습니다.

## 공식 참고

- https://firebase.google.com/docs/projects/billing/firebase-pricing-plans
- https://firebase.google.com/docs/cloud-messaging/flutter/receive-messages
- https://firebase.google.com/docs/cloud-messaging/send/v1-api
