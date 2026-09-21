import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'api_exception.dart';

class EcosExchangePoint {
  const EcosExchangePoint(this.date, this.value);
  final String date;
  final double value;
}

class EcosApiClient {
  EcosApiClient({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.ecosApiKey;
  final http.Client _client;
  final String _apiKey;

  Future<List<EcosExchangePoint>> usdKrw({int days = 45}) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('ECOS', 'missing-key');
    final end = DateTime.now().toUtc().add(const Duration(hours: 9));
    final start = end.subtract(Duration(days: days));
    String ymd(DateTime x) => '${x.year.toString().padLeft(4, '0')}${x.month.toString().padLeft(2, '0')}${x.day.toString().padLeft(2, '0')}';
    // 731Y001 / 0000001: 원/미국달러(매매기준율), 일별.
    final uri = Uri.https('ecos.bok.or.kr', '/api/StatisticSearch/$_apiKey/json/kr/1/100/731Y001/D/${ymd(start)}/${ymd(end)}/0000001');
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw OfficialApiException('ECOS', 'http', response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    if (json['RESULT'] != null) throw const OfficialApiException('ECOS', 'service-error');
    final rows = ((json['StatisticSearch'] as Map?)?['row'] as List? ?? const []);
    final values = <EcosExchangePoint>[];
    for (final raw in rows.whereType<Map>()) {
      final row = raw.cast<String, dynamic>();
      final value = double.tryParse((row['DATA_VALUE'] ?? '').toString().replaceAll(',', ''));
      final date = row['TIME']?.toString() ?? '';
      if (value != null && value > 0 && date.length == 8) values.add(EcosExchangePoint(date, value));
    }
    values.sort((a, b) => a.date.compareTo(b.date));
    if (values.isEmpty) throw const OfficialApiException('ECOS', 'empty-result');
    return values;
  }
}
