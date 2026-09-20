abstract final class ApiEnvironment {
  static const publicDataBaseUrl=String.fromEnvironment('PUBLIC_DATA_BASE_URL',defaultValue:'https://noah981.github.io/pig-market-brief/data');
  // 기관 API 키는 앱 바이너리에 넣지 않는다. GitHub Actions Secret을 사용하는
  // 서버측 수집기가 검증·정규화한 공개 JSON만 앱이 읽는다.
}
