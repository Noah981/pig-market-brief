import 'dart:convert';
import 'dart:math' as math;
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'api_exception.dart';

class KmaForecast {
  const KmaForecast({required this.tempMin, required this.tempMax, required this.humidityMax, required this.rainProbabilityMax, required this.baseDate, required this.baseTime});
  final double tempMin, tempMax, humidityMax, rainProbabilityMax;
  final String baseDate, baseTime;
}

class KmaApiClient {
  KmaApiClient({http.Client? client, String? apiKey}) : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.kmaApiKey;
  final http.Client _client;
  final String _apiKey;

  Future<KmaForecast> forecast(double latitude, double longitude) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('KMA', 'missing-key');
    final grid = _grid(latitude, longitude), now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final available = now.subtract(const Duration(minutes: 15));
    const slots = [2, 5, 8, 11, 14, 17, 20, 23];
    var date = available, hour = slots.where((x) => x <= available.hour).lastOrNull;
    if (hour == null) { date = available.subtract(const Duration(days: 1)); hour = 23; }
    String two(int x) => x.toString().padLeft(2, '0');
    final baseDate = '${date.year}${two(date.month)}${two(date.day)}', baseTime = '${two(hour)}00';
    final uri = Uri.https('apis.data.go.kr', '/1360000/VilageFcstInfoService_2.0/getVilageFcst', {
      'serviceKey': Uri.decodeComponent(_apiKey), 'pageNo': '1', 'numOfRows': '1000', 'dataType': 'JSON',
      'base_date': baseDate, 'base_time': baseTime, 'nx': '${grid.$1}', 'ny': '${grid.$2}',
    });
    final response = await _client.get(uri).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw OfficialApiException('KMA', 'http', response.statusCode);
    final json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    final root = (json['response'] as Map?)?.cast<String, dynamic>();
    final code = ((root?['header'] as Map?)?['resultCode'])?.toString();
    if (code != '00') throw const OfficialApiException('KMA', 'service-error');
    final rows = ((((root?['body'] as Map?)?['items'] as Map?)?['item']) as List? ?? const []);
    final values = <String, List<double>>{};
    for (final raw in rows.whereType<Map>()) {
      final row = raw.cast<String, dynamic>(), category = row['category']?.toString() ?? '';
      final value = double.tryParse(row['fcstValue']?.toString() ?? '');
      if (value != null && const ['TMP', 'TMN', 'TMX', 'REH', 'POP'].contains(category)) values.putIfAbsent(category, () => []).add(value);
    }
    final temps = [...?values['TMP'], ...?values['TMN'], ...?values['TMX']];
    if (temps.isEmpty) throw const OfficialApiException('KMA', 'empty-result');
    double maxOf(String key) => values[key]?.reduce(math.max) ?? 0;
    return KmaForecast(tempMin: temps.reduce(math.min), tempMax: temps.reduce(math.max), humidityMax: maxOf('REH'), rainProbabilityMax: maxOf('POP'), baseDate: baseDate, baseTime: baseTime);
  }

  (int, int) _grid(double lat, double lon) {
    const re = 6371.00877, grid = 5.0, slat1 = 30.0, slat2 = 60.0, olon = 126.0, olat = 38.0, xo = 43.0, yo = 136.0;
    const degrad = math.pi / 180.0;
    final reGrid = re / grid, sl1 = slat1 * degrad, sl2 = slat2 * degrad;
    var sn = math.log(math.cos(sl1) / math.cos(sl2)) / math.log(math.tan(math.pi * 0.25 + sl2 * 0.5) / math.tan(math.pi * 0.25 + sl1 * 0.5));
    var sf = math.pow(math.tan(math.pi * 0.25 + sl1 * 0.5), sn) * math.cos(sl1) / sn;
    var ro = reGrid * sf / math.pow(math.tan(math.pi * 0.25 + olat * degrad * 0.5), sn);
    var ra = reGrid * sf / math.pow(math.tan(math.pi * 0.25 + lat * degrad * 0.5), sn);
    var theta = lon * degrad - olon * degrad;
    if (theta > math.pi) theta -= 2.0 * math.pi;
    if (theta < -math.pi) theta += 2.0 * math.pi;
    theta *= sn;
    return ((ra * math.sin(theta) + xo + 0.5).floor(), (ro - ra * math.cos(theta) + yo + 0.5).floor());
  }
}
