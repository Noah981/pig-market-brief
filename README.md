# pig-market-brief
대한민국 전역(제주 포함) 양돈 시황·날씨·질병·농장점검 브리핑 앱.

## 원칙
- 특정 사료회사 내부정보/제품/거래처 정보 제외
- 공식 데이터의 공표 범위를 그대로 표시
- 제주 흑돼지를 전국 흑돼지 가격으로 표시하지 않음
- 사실과 해석/관련 체크요인을 분리
- 날씨·특보·질병·시황에 따라 농장 체크리스트 우선순위를 자동 조정

## GitHub Secrets
- KAPE_SERVICE_KEY : 축산물품질평가원 인증키
- KMA_SERVICE_KEY : 기상청 API 연결 시 추가

공식 API -> GitHub Actions -> docs/data JSON -> Android 앱/위젯
