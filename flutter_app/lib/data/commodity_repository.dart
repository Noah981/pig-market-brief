import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/dashboard_models.dart';

class CommodityRepository {
  CommodityRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _url =
      'https://noah981.github.io/pig-market-brief/data/platform.json';
  static const _cacheKey = 'verified_commodity_market_v1';
  final http.Client _client;

  Future<List<Commodity>> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    final value = raw ?? await rootBundle.loadString('assets/data/platform.json');
    try {
      return _parse(jsonDecode(value) as Map<String, dynamic>);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Commodity>> refresh() async {
    final response = await _client
        .get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}'))
        .timeout(const Duration(seconds: 12));
    if (response.statusCode != 200) throw Exception('Market data unavailable');
    final raw = utf8.decode(response.bodyBytes);
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final values = _parse(json);
    await (await SharedPreferences.getInstance()).setString(_cacheKey, raw);
    return values;
  }

  List<Commodity> _parse(Map<String, dynamic> json) {
    final rows = (json['markets'] as List? ?? const [])
        .whereType<Map<String, dynamic>>();
    final byName = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final name = row['name']?.toString();
      if (name != null) byName[name] = row;
    }
    return [
      _item(byName['corn'], '옥수수', Icons.grass),
      _item(byName['soybean_meal'], '대두박', Icons.eco),
      _item(byName['wheat'], '소맥', Icons.grain),
      _item(byName['soybean'], '대두', Icons.spa),
      _item(byName['wti'], '국제유가\n(WTI)', Icons.local_gas_station),
      _item(byName['usd_krw'], '환율\n(USD/KRW)', Icons.attach_money),
    ];
  }

  Commodity _item(
      Map<String, dynamic>? row, String label, IconData icon) {
    if (row == null || row['value'] is! num) {
      return Commodity(label, '확인 중', '', null, icon,
          id: row?['name']?.toString() ?? _idForLabel(label));
    }
    final value = (row['value'] as num).toDouble();
    final decimals = value >= 1000 ? 1 : 2;
    final text = value.toStringAsFixed(decimals);
    final change = (row['changePct'] as num?)?.toDouble();
    final history = (row['history'] as List? ?? const [])
        .whereType<Map<String, dynamic>>()
        .where((x) => x['value'] is num)
        .map((x) => CommodityPoint(x['date']?.toString() ?? '', (x['value'] as num).toDouble()))
        .toList();
    return Commodity(label, text, row['unit']?.toString() ?? '', change, icon,
        id: row['name']?.toString() ?? _idForLabel(label),
        source: row['source']?.toString() ?? '',
        asOf: row['date']?.toString() ?? row['updatedAt']?.toString() ?? '',
        frequency: row['frequency']?.toString() ?? '',
        basis: row['basis']?.toString() ?? '',
        url: row['url']?.toString() ?? '',
        history: history);
  }

  String _idForLabel(String label) {
    if (label.startsWith('옥수수')) return 'corn';
    if (label.startsWith('대두박')) return 'soybean_meal';
    if (label.startsWith('소맥')) return 'wheat';
    if (label.startsWith('대두')) return 'soybean';
    if (label.startsWith('국제유가')) return 'wti';
    return 'usd_krw';
  }
}
