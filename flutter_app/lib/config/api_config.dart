class ApiConfig {
  const ApiConfig._();

  static const ecosApiKey = String.fromEnvironment('ECOS_API_KEY');
  static const kapeApiKey = String.fromEnvironment('KAPE_API_KEY');
  static const kmaApiKey = String.fromEnvironment('KMA_API_KEY');
  static const mafraApiKey = String.fromEnvironment('MAFRA_API_KEY');
  static const kamisApiKey = String.fromEnvironment('KAMIS_API_KEY');
  static const kamisCertId = String.fromEnvironment('KAMIS_CERT_ID');

  static bool get hasEcos => ecosApiKey.trim().isNotEmpty;
  static bool get hasKape => kapeApiKey.trim().isNotEmpty;
  static bool get hasKma => kmaApiKey.trim().isNotEmpty;
  static bool get hasMafra => mafraApiKey.trim().isNotEmpty;
  static bool get hasKamis => kamisApiKey.trim().isNotEmpty && kamisCertId.trim().isNotEmpty;
}
