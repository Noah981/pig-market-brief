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

  Future<List<MafraDiseaseRow>> fetch({int pageSize = 1000}) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('MAFRA', 'missing-key');
    final first = await _request(1, 1);
    final total = int.tryParse((first['totalCnt'] ?? first['TOTAL_CNT'] ?? '0').toString()) ?? 0;
    if (total <= 0) throw const OfficialApiException('MAFRA', 'coverage-unknown');
    if (total == 1) return _rows(first);
    final pages = <List<MafraDiseaseRow>>[];
    final size = pageSize.clamp(1, 1000);
    // The official grid does not guarantee chronological ordering. Reading
    // only its last 1,000 rows can silently omit newly registered FMD/PED.
    for (var start = 1; start <= total; start += size * 4) {
      final requests = <Future<List<MafraDiseaseRow>>>[];
      for (var offset = 0; offset < 4 && start + offset * size <= total; offset++) {
        final from = start + offset * size;
        final to = (from + size - 1).clamp(1, total);
        requests.add(_request(from, to).then((grid) {
          final rows = _rows(grid);
          final declared = int.tryParse((grid['totalCnt'] ?? grid['TOTAL_CNT'] ?? '').toString());
          if (declared != total || rows.length != to - from + 1) {
            throw const OfficialApiException('MAFRA', 'incomplete-coverage');
          }
          return rows;
        }));
      }
      pages.addAll(await Future.wait(requests));
    }
    return pages.expand((rows) => rows).toList();
  }
  List<MafraDiseaseRow> _rows(Map<String, dynamic> grid) =>
      (grid['row'] as List? ?? const []).whereType<Map>()
          .map((x) => MafraDiseaseRow(x.cast<String, dynamic>())).toList();

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
