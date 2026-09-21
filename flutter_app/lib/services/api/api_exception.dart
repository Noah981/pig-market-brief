class OfficialApiException implements Exception {
  const OfficialApiException(this.service, this.kind, [this.statusCode]);
  final String service;
  final String kind;
  final int? statusCode;
  @override
  String toString() => '$service API $kind${statusCode == null ? '' : ' ($statusCode)'}';
}
