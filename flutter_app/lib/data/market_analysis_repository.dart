import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_models.dart';

class MarketAnalysisRepository {
  MarketAnalysisRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _url =
      'https://noah981.github.io/pig-market-brief/data/market-analysis.json';
  static const _cacheKey = 'official_market_analysis_v1';
  final http.Client _client;
  static const bundledSnapshot=MarketAnalysis(
    summary:'전 거래일보다 298원/kg 하락했습니다. 최근 거래 흐름과 경매 물량, 계절 수급 전망을 함께 확인해야 하며 한 가지 원인으로 단정하지 않습니다.',
    factors:[
      MarketFactor('전일 대비 가격','확인','축산물품질평가원 공표값 기준 6,442원/kg으로 전 거래일보다 298원 하락했습니다.'),
      MarketFactor('최근 거래 흐름','분석','최근 7거래일 평균과 비교하면 높은 수준이지만 직전 고점에서 조정을 보였습니다.'),
      MarketFactor('공급 여건','배경','도축·출하 물량과 계절 수요는 함께 확인해야 할 변수입니다. 당일 원인으로 단정하지 않습니다.'),
    ],
    updatedAt:'2026-09-19T07:00:30+09:00',
    sources:[MarketSource('축산물품질평가원','생산자 돼지 경락가격','https://www.ekape.or.kr/'),MarketSource('KREI 농업관측센터','돼지 수급·가격 전망','https://aglook.krei.re.kr/')],
  );

  Future<MarketAnalysis?> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    return raw == null ? bundledSnapshot : _decode(raw)??bundledSnapshot;
  }

  Future<MarketAnalysis> refresh() async {
    final response = await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Market analysis unavailable');
    final raw = utf8.decode(response.bodyBytes);
    final value = _decode(raw);
    if (value == null) throw const FormatException('Invalid market analysis');
    await (await SharedPreferences.getInstance()).setString(_cacheKey, raw);
    return value;
  }

  MarketAnalysis? _decode(String raw) {
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final factors = (json['factors'] as List? ?? const [])
          .whereType<Map<String, dynamic>>()
          .map((x) => MarketFactor(x['title']?.toString() ?? '',
              x['status']?.toString() ?? '', x['detail']?.toString() ?? ''))
          .where((x) => x.title.isNotEmpty && x.detail.isNotEmpty)
          .toList();
      final sources=(json['sources'] as List? ?? const []).whereType<Map<String,dynamic>>().map((x)=>MarketSource(x['name']?.toString()??'',x['label']?.toString()??'',x['url']?.toString()??'')).where((x)=>x.name.isNotEmpty).toList();
      return MarketAnalysis(
        summary: json['summary']?.toString() ?? '',
        factors: factors,
        updatedAt: json['updatedAt']?.toString() ?? '',
        sources:sources,
      );
    } catch (_) {
      return null;
    }
  }
}
