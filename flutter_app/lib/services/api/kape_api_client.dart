import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'api_exception.dart';

class KapePigPrice {
  const KapePigPrice({required this.date, required this.price, required this.count});
  final String date;
  final int price;
  final int count;
}

class KapeApiClient {
  KapeApiClient({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.kapeApiKey;
  final http.Client _client;
  final String _apiKey;
  static const _base = 'data.ekape.or.kr';

  Future<KapePigPrice?> priceFor(String ymd) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('KAPE', 'missing-key');
    var amount = 0.0, count = 0;
    for (final sex in const ['025001', '025003']) {
      final normalizedKey = Uri.decodeComponent(_apiKey);
      final uri = Uri.http(_base, '/openapi-data/service/user/grade/auct/pigGrade', {
        'serviceKey': normalizedKey, 'startYmd': ymd, 'endYmd': ymd,
        'skinYn': 'Y', 'sexCd': sex, 'egradeExceptYn': 'Y',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw OfficialApiException('KAPE', 'http', response.statusCode);
      final xml = response.body;
      final code = RegExp(r'<resultCode>(.*?)</resultCode>').firstMatch(xml)?.group(1)?.trim();
      if (code != null && code != '00') throw const OfficialApiException('KAPE', 'service-error');
      final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml);
      for (final item in items) {
        final body = item.group(1)!;
        double? number(String tag) => double.tryParse((RegExp('<$tag>(.*?)</$tag>').firstMatch(body)?.group(1) ?? '').replaceAll(',', ''));
        final price = number('c_1101eTotAmt'), n = number('c_1101eTotCnt');
        if (price != null && n != null && price > 0 && n > 0) { amount += price * n; count += n.round(); }
      }
    }
    return count == 0 ? null : KapePigPrice(date: ymd, price: (amount / count).round(), count: count);
  }

  Future<List<KapePigPrice>> latest({int lookbackDays = 14}) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final out = <KapePigPrice>[];
    for (var ago = 0; ago < lookbackDays && out.length < 2; ago++) {
      final day = now.subtract(Duration(days: ago));
      final ymd = '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
      final value = await priceFor(ymd);
      if (value != null) out.add(value);
    }
    if (out.isEmpty) throw const OfficialApiException('KAPE', 'empty-result');
    return out.reversed.toList();
  }
}
