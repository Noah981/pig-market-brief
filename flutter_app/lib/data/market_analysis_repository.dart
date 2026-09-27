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
  static const MarketAnalysis? bundledSnapshot=null;

  Future<MarketAnalysis?> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    return raw == null ? null : _decode(raw);
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
              x['status']?.toString() ?? '', x['detail']?.toString() ?? '',
              source:x['source']?.toString()??'',sourceDate:x['sourceDate']?.toString()??'',direction:x['direction']?.toString()??'neutral'))
          .where((x) => x.title.isNotEmpty && x.detail.isNotEmpty && x.source.isNotEmpty)
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
