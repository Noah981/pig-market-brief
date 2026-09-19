import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_models.dart';

class CommodityRepository {
  CommodityRepository({http.Client? client}) : _client = client ?? http.Client();

  static const _url =
      'https://noah981.github.io/pig-market-brief/data/platform.json';
  static const _cacheKey = 'verified_commodity_market_v1';
  final http.Client _client;
  static const bundledSnapshot = [
    Commodity('옥수수','213.19',r'$/톤',8.89,Icons.grass,id:'corn',source:'국제통화기금(IMF)·FRED',asOf:'2026-07-01',frequency:'monthly',basis:'세계 옥수수 벤치마크 월평균',history:[CommodityPoint('2026-06-01',195.78),CommodityPoint('2026-07-01',213.19)]),
    Commodity('대두박','329.43',r'$/톤',11.24,Icons.eco,id:'soybean_meal',source:'국제통화기금(IMF)·FRED',asOf:'2026-07-01',frequency:'monthly',basis:'세계 대두박 벤치마크 월평균',history:[CommodityPoint('2026-06-01',296.16),CommodityPoint('2026-07-01',329.43)]),
    Commodity('소맥','228.74',r'$/톤',14.57,Icons.grain,id:'wheat',source:'국제통화기금(IMF)·FRED',asOf:'2026-07-01',frequency:'monthly',basis:'세계 소맥 벤치마크 월평균',history:[CommodityPoint('2026-06-01',199.65),CommodityPoint('2026-07-01',228.74)]),
    Commodity('대두','442.45',r'$/톤',6.73,Icons.spa,id:'soybean',source:'국제통화기금(IMF)·FRED',asOf:'2026-07-01',frequency:'monthly',basis:'세계 대두 벤치마크 월평균',history:[CommodityPoint('2026-06-01',414.54),CommodityPoint('2026-07-01',442.45)]),
    Commodity('국제유가\n(WTI)','107.02',r'$/bbl',4.49,Icons.local_gas_station,id:'wti',source:'미국 에너지정보청(EIA)·FRED',asOf:'2026-09-15',frequency:'daily',basis:'WTI Cushing 현물가격',history:[CommodityPoint('2026-09-14',102.42),CommodityPoint('2026-09-15',107.02)]),
    Commodity('환율\n(USD/KRW)','1340.3','원/USD',-0.40,Icons.attach_money,id:'usd_krw',source:'미국 연방준비제도 이사회·FRED',asOf:'2026-09-11',frequency:'daily',basis:'뉴욕 정오 원/달러 현물환율',history:[CommodityPoint('2026-09-10',1345.63),CommodityPoint('2026-09-11',1340.3)]),
  ];

  Future<List<Commodity>> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null)return bundledSnapshot;
    try {
      return _parse(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return bundledSnapshot;
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
