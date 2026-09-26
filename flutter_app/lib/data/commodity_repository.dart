import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../models/dashboard_models.dart';
import '../config/api_config.dart';
import '../services/api/ecos_api_client.dart';

class CommodityRepository {
  CommodityRepository({http.Client? client, EcosApiClient? ecosClient})
      : _client = client ?? http.Client(),
        _ecosClient = ecosClient ?? EcosApiClient(client: client);

  static const _url =
      'https://noah981.github.io/pig-market-brief/data/platform.json';
  static const _cacheKey = 'verified_commodity_market_v1';
  final http.Client _client;
  final EcosApiClient _ecosClient;
  static const List<Commodity> bundledSnapshot = [];

  Future<List<Commodity>> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null){
      try{return _parse(jsonDecode(await rootBundle.loadString('assets/data/platform.json')) as Map<String,dynamic>);}catch(_){return const [];}
    }
    try {
      return _parse(jsonDecode(raw) as Map<String, dynamic>);
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
    var values = _parse(json);
    if (ApiConfig.hasEcos) {
      try {
        final points = await _ecosClient.usdKrw();
        final latest = points.last, previous = points.length > 1 ? points[points.length - 2] : latest;
        final changePct = previous.value == 0 ? 0.0 : (latest.value - previous.value) / previous.value * 100;
        final official = Commodity('환율\n(USD/KRW)', latest.value.toStringAsFixed(1), '원/USD', changePct, Icons.attach_money,
            id: 'usd_krw', source: '한국은행 ECOS', asOf: latest.date, frequency: 'daily',
            basis: '원/미국달러 매매기준율',
            history: points.map((x) => CommodityPoint(x.date, x.value)).toList());
        values = values.map((x) => x.id == 'usd_krw' ? official : x).toList();
      } catch (_) {
        // ECOS 실패 시 검증된 마지막 플랫폼 값과 캐시를 유지한다.
      }
    }
    await (await SharedPreferences.getInstance()).setString(_cacheKey, jsonEncode(_cacheJson(values)));
    return values;
  }

  Map<String, dynamic> _cacheJson(List<Commodity> values) => {'markets': values.map((x) => {
    'name': x.id, 'value': double.tryParse(x.value), 'unit': x.unit, 'changePct': x.change,
    'previousValue':x.previousValue,'previousDate':x.previousDate,'updatedAt':x.updatedAt,'status':x.status,
    'source': x.source, 'date': x.asOf, 'frequency': x.frequency, 'basis': x.basis,'url':x.url,
    'history': x.history.map((p) => {'date': p.date, 'value': p.value}).toList(),
    'analysis':{'summary':x.analysisSummary,'updatedAt':x.analysisUpdatedAt,'confidence':x.analysisConfidence,
      'factors':x.analysisFactors.map((f)=>{'title':f.title,'status':f.status,'detail':f.detail,'source':f.source,'sourceDate':f.sourceDate,'direction':f.direction}).toList(),
      'sources':x.analysisSources.map((s)=>{'name':s.name,'label':s.label,'url':s.url}).toList()},
  }).toList()};

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
    final analysis=row['analysis'] is Map<String,dynamic>?row['analysis'] as Map<String,dynamic>:const <String,dynamic>{};
    final factors=(analysis['factors'] as List? ?? const []).whereType<Map<String,dynamic>>().map((x)=>MarketFactor(x['title']?.toString()??'',x['status']?.toString()??'확인',x['detail']?.toString()??'',source:x['source']?.toString()??'',sourceDate:x['sourceDate']?.toString()??'',direction:x['direction']?.toString()??'neutral')).where((x)=>x.title.isNotEmpty&&x.detail.isNotEmpty&&x.source.isNotEmpty).toList();
    final sources=(analysis['sources'] as List? ?? const []).whereType<Map<String,dynamic>>().map((x)=>MarketSource(x['name']?.toString()??'',x['label']?.toString()??'',x['url']?.toString()??'')).where((x)=>x.url.isNotEmpty).toList();
    return Commodity(label, text, row['unit']?.toString() ?? '', change, icon,
        id: row['name']?.toString() ?? _idForLabel(label),
        source: row['source']?.toString() ?? '',
        asOf: row['date']?.toString() ?? row['updatedAt']?.toString() ?? '',
        frequency: row['frequency']?.toString() ?? '',
        basis: row['basis']?.toString() ?? '',
        url: row['url']?.toString() ?? '',
        history: history,
        analysisSummary:analysis['summary']?.toString()??'',
        analysisUpdatedAt:analysis['updatedAt']?.toString()??'',
        analysisConfidence:analysis['confidence']?.toString()??'',
        analysisFactors:factors,
        analysisSources:sources,
        previousValue:(row['previousValue'] as num?)?.toDouble(),
        previousDate:row['previousDate']?.toString()??'',
        updatedAt:row['updatedAt']?.toString()??'',
        status:row['status']?.toString()??'LIVE');
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
