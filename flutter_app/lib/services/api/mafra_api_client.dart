import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'api_exception.dart';

class MafraDiseaseRow {
  const MafraDiseaseRow(this.values);
  final Map<String, dynamic> values;
  String pick(List<String> keys) { for (final key in keys) { final v = values[key]?.toString().trim(); if (v != null && v.isNotEmpty) return v; } return ''; }
}

class MafraApiClient {
  MafraApiClient({http.Client? client, String? apiKey}) : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.mafraApiKey;
  final http.Client _client;
  final String _apiKey;

  Future<List<MafraDiseaseRow>> fetch({int limit = 1000}) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('MAFRA', 'missing-key');
    // 농식품 공공데이터 포털 가축질병발생정보의 공식 Grid ID.
    final first = await _request(1, 1);
    final total = int.tryParse((first['totalCnt'] ?? first['TOTAL_CNT'] ?? '0').toString()) ?? 0;
    if (total <= 0) return const [];
    final end = total, start = (end - limit + 1).clamp(1, end);
    final grid = start == 1 && end == 1 ? first : await _request(start, end);
    final rows = (grid['row'] as List? ?? const []).whereType<Map>().map((x) => MafraDiseaseRow(x.cast<String, dynamic>())).toList();
    return rows;
  }

  Future<Map<String, dynamic>> _request(int start, int end) async {
    final uri = Uri.http('211.237.50.150:7080', '/openapi/$_apiKey/json/Grid_20151204000000000316_1/$start/$end');
    final response = await _client.get(uri).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) throw OfficialApiException('MAFRA', 'http', response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final grid = (json['Grid_20151204000000000316_1'] as Map?)?.cast<String, dynamic>();
    if (grid == null) throw const OfficialApiException('MAFRA', 'invalid-schema');
    final result = ((grid['RESULT'] ?? grid['result']) as Map?)?.cast<String, dynamic>();
    final code = (result?['CODE'] ?? result?['code'])?.toString();
    if (code != null && code != 'INFO-000') throw const OfficialApiException('MAFRA', 'service-error');
    return grid;
  }
}
