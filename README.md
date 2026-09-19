# 돈돈해 — 양돈의 오늘을 든든하게

Android 26+ / Kotlin / Jetpack Compose. 농가가 반복 입력하는 ERP 대신 오늘·돈가·시장·혜택·간단 도구를 제공합니다.

## 현재 개발 브랜치
`codex/dondonhae-information-platform` — 검증 중, 운영 완성판 아님.

## 동작 구조
기존 공식 수집 스크립트 → 정적 JSON → 정상 응답 로컬 캐시 → Android 화면·동일 캐시 위젯.
공식 데이터와 사용자 입력은 분리합니다. 월평균을 일간 돈가로 사용하지 않습니다.

## 검증 명령
```sh
python -m unittest discover -s scripts -p test_platform.py -v
cd android
gradle :app:testDebugUnitTest :app:assembleDebug :app:assembleRelease
```
Android CI는 별도 에뮬레이터에 debug APK를 설치해 최초 설정·5개 탭 이동·치명적 예외를 검사합니다.
Release APK에는 배포 서명을 제공해야 합니다. 개발용 APK를 운영 서명판으로 표현하지 않습니다.

## 데이터 연결 상태
- 돈가·기상·질병: 기존 수집 파이프라인을 유지합니다. 실제 확정 신호가 없는 가격은 확정 여부 확인 필요로 표시합니다.
- 원료·환율·유류·지원사업: `config/platform_sources.json`의 검증된 소스만 수집합니다. 기본 설정은 비활성입니다.
- `scripts/platform_pipeline.py`: JSON/RSS 어댑터, 날짜·단위·샘플 검증, 공고 중복 제거, 실패 시 기존값 보존.
- 외부 API가 정규화 스키마와 다르면 공급기관별 필드 매핑이 추가로 필요합니다. 키 하나만으로 모든 API가 연결된다고 보장하지 않습니다.
- 인증: 사용자 보유 상태와 담당기관 연결. 개별 인증 상세요건·접수일정 자동 수집은 아직 미연결입니다.
- GPS: 현재 행정구역과 등록 농장 지역은 별개입니다. 질병 발생 좌표가 없으면 거리나 위치를 만들지 않습니다.

## 개인정보와 알림
정확한 GPS 좌표는 저장하지 않습니다. 농장 조건·주문주기·알림 설정은 기기에 저장하며 Android 자동 백업은 사용하지 않습니다.
알림은 WorkManager 정기 확인 방식으로 FCM 즉시 푸시가 아닙니다. OS 정책·권한·방해금지에 따라 지연됩니다.

## 보존
이전 농장 기록 및 인증 저장소를 삭제하지 않습니다. 기존 ERP 화면은 새 내비게이션에서 제외되며 데이터는 유지됩니다.
