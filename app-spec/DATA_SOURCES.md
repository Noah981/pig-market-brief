# 데이터 연결 계획
## 축산물품질평가원
승인받은 축산물경락가격정보 API 사용.
기존 가이드에서 확인된 제주 돼지/일반돼지/흑돼지는 제주 범위로만 표시.
전국/권역 가격은 최신 공식 상세기능을 검증한 뒤 연결하며 endpoint를 추측하지 않음.

## 기상청
단기예보(전국 격자) + 기상특보를 사용. KMA_SERVICE_KEY 추가 후 수집기 연결.

## 가축질병
KAHIS 국내 가축전염병 발생정보를 공식 출처로 사용.
공개 API/제공방식을 확인하기 전에는 비공식 스크래핑을 운영 파이프라인으로 사용하지 않음.

## 키 보안 및 앱 연결
- 기관 인증키는 Flutter `dart-define` 또는 APK에 포함하지 않는다.
- `KAPE_SERVICE_KEY`, `KMA_SERVICE_KEY`, `MOIS_DISEASE_API_KEY`, `ECOS_API_KEY`, `KAMIS_API_KEY`는 GitHub Actions Secret 또는 동등한 서버측 Secret 저장소에서만 주입한다.
- 수집기는 출처·기준시각·수집시각·마지막 성공시각을 포함한 정규화 JSON을 발행한다.
- 앱과 위젯은 `PUBLIC_DATA_BASE_URL`의 검증된 공개 결과만 읽고, 실패 시 마지막 정상 캐시를 유지한다.
