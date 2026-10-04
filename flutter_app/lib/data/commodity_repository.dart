import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/dashboard_models.dart';
import '../config/api_config.dart';
import '../services/api/ecos_api_client.dart';

class CommodityRepository {
  CommodityRepository({http.Client? client, EcosApiClient? ecosClient})
      : _client = client ?? http.Client(),
        _ecosClient = ecosClient ?? EcosApiClient(client: client);

  static const _url =
      'https://noah981.github.io/pig-market-brief/data/platform.json';
  static const _cacheKey = 'verified_commodity_market_v2';
  final http.Client _client;
  final EcosApiClient _ecosClient;
  static const bundledSnapshot = [
    Commodity('옥수수','확인 중','',null,Icons.grass,id:'corn'),
    Commodity('대두박','확인 중','',null,Icons.eco,id:'soybean_meal'),
    Commodity('소맥','확인 중','',null,Icons.grain,id:'wheat'),
    Commodity('대두','확인 중','',null,Icons.spa,id:'soybean'),
    Commodity('국제유가\n(WTI)','확인 중','',null,Icons.local_gas_station,id:'wti'),
    Commodity('환율\n(USD/KRW)','확인 중','',null,Icons.attach_money,id:'usd_krw'),
  ];

  Future<List<Commodity>> cached() async {
    final raw = (await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null){
      try{return _parse(jsonDecode(await rootBundle.loadString('assets/data/platform.json')) as Map<String,dynamic>).map((x)=>x.copyWith(status:'STALE')).toList();}catch(_){return bundledSnapshot;}
    }
    try {
      return _parse(jsonDecode(raw) as Map<String, dynamic>).map((x)=>x.copyWith(status:'STALE')).toList();
    } catch (_) {
      return bundledSnapshot;
    }
  }

  Future<List<Commodity>> refresh() async {
    var values=await cached();
    try {
      final response=await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds:12));
      if(response.statusCode==200){
        final incoming=_parse(jsonDecode(utf8.decode(response.bodyBytes)) as Map<String,dynamic>);
        values=incoming.map((x){final old=values.where((v)=>v.id==x.id).firstOrNull;return old!=null&&old.hasQuote&&(!x.hasQuote||old.asOf.compareTo(x.asOf)>0)?old:x;}).toList();
      }
    }catch(_){ /* Other official providers still run if the mirror fails. */ }
    final refreshed=<String,Commodity>{};
    await Future.wait({
      'corn':'PMAIZMTUSDM','soybean_meal':'PSMEAUSDM','wheat':'PWHEAMTUSDM','soybean':'PSOYBUSDM','wti':'DCOILWTICO','usd_krw':'DEXKOUS'
    }.entries.map((entry)async{try{refreshed[entry.key]=await _fred(entry.key,entry.value);}catch(_){}}));
    if(refreshed.isNotEmpty)values=values.map((x){final latest=refreshed[x.id];return latest!=null&&(!x.hasQuote||latest.asOf.compareTo(x.asOf)>=0)?latest:x;}).toList();
    if (ApiConfig.hasEcos) {
      try {
        final points = await _ecosClient.usdKrw();
        final latest = points.last, previous = points.length > 1 ? points[points.length - 2] : latest;
        final changePct = previous.value == 0 ? 0.0 : (latest.value - previous.value) / previous.value * 100;
        final official = Commodity('환율\n(USD/KRW)', latest.value.toStringAsFixed(1), '원/USD', changePct, Icons.attach_money,
            id: 'usd_krw', source: '한국은행 ECOS', asOf: _isoDate(latest.date), frequency: 'daily',
            basis: '원/미국달러 매매기준율', url:'https://ecos.bok.or.kr/', previousValue:previous.value,previousDate:_isoDate(previous.date),updatedAt:DateTime.now().toIso8601String(),status:'LIVE',
            history: points.map((x) => CommodityPoint(_isoDate(x.date), x.value)).toList());
        values = values.map((x) => x.id == 'usd_krw' ? official : x).toList();
      } catch (_) {
        // ECOS 실패 시 검증된 마지막 플랫폼 값과 캐시를 유지한다.
      }
    }
    await (await SharedPreferences.getInstance()).setString(_cacheKey, jsonEncode(_cacheJson(values)));
    return values;
  }

  Future<Commodity> _fred(String id,String series)async{
    final response=await _client.get(Uri.https('fred.stlouisfed.org','/graph/fredgraph.csv',{'id':series})).timeout(const Duration(seconds:15));
    if(response.statusCode!=200)throw Exception('FRED unavailable');
    final points=<CommodityPoint>[];
    for(final line in utf8.decode(response.bodyBytes).split(RegExp(r'\r?\n')).skip(1)){
      final cells=line.split(',');if(cells.length<2)continue;
      final value=double.tryParse(cells[1].trim());if(value!=null&&value.isFinite&&value>0&&_validDate(cells[0].trim()))points.add(CommodityPoint(cells[0].trim(),value));
    }
    points.sort((a,b)=>a.date.compareTo(b.date));
    if(points.length<2)throw const FormatException('FRED series empty');
    final latest=points.last,previous=points[points.length-2],change=(latest.value-previous.value)/previous.value*100;
    final meta={
      'corn':('옥수수','\$/톤','세계 옥수수 벤치마크 월평균','국제통화기금(IMF)·FRED','monthly'),
      'soybean_meal':('대두박','\$/톤','세계 대두박 벤치마크 월평균','국제통화기금(IMF)·FRED','monthly'),
      'wheat':('소맥','\$/톤','세계 소맥 벤치마크 월평균','국제통화기금(IMF)·FRED','monthly'),
      'soybean':('대두','\$/톤','세계 대두 벤치마크 월평균','국제통화기금(IMF)·FRED','monthly'),
      'usd_krw':('환율\n(USD/KRW)','원/USD','뉴욕 정오 원/달러 현물환율','미국 연방준비제도 이사회·FRED','daily'),
      'wti':('국제유가\n(WTI)','\$/bbl','WTI Cushing 현물가격','미국 에너지정보청(EIA)·FRED','daily'),
    }[id]!;
    return Commodity(meta.$1,latest.value.toStringAsFixed(latest.value>=1000?1:2),meta.$2,change,id=='wti'?Icons.local_gas_station:id=='usd_krw'?Icons.attach_money:Icons.eco,id:id,source:meta.$4,asOf:latest.date,frequency:meta.$5,basis:meta.$3,url:'https://fred.stlouisfed.org/series/$series',history:points.length>366?points.sublist(points.length-366):points,previousValue:previous.value,previousDate:_isoDate(previous.date),updatedAt:DateTime.now().toIso8601String(),status:'LIVE',analysisSummary:'공식 공표값의 실제 추세입니다. 가격 변동의 원인은 별도 확인이 필요합니다.',analysisFactors:points.length<3?const []:[MarketFactor('최근 3회 발표 추세','실측 계산','${((latest.value/points[points.length-3].value-1)*100).toStringAsFixed(1)}% · ${points[points.length-3].date} → ${latest.date}',source:meta.$4,sourceDate:latest.date)]);
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
    if (row == null || row['value'] is! num || !(row['value'] as num).isFinite || (row['value'] as num)<=0 || !_validDate(row['date']?.toString()??'') || (row['source']?.toString()??'').isEmpty || (row['unit']?.toString()??'').isEmpty) {
      return Commodity(label, '확인 중', '', null, icon,
          id: row?['name']?.toString() ?? _idForLabel(label));
    }
    final value = (row['value'] as num).toDouble();
    final decimals = value >= 1000 ? 1 : 2;
    final text = value.toStringAsFixed(decimals);
    final previous=(row['previousValue'] as num?)?.toDouble();
    final change=previous!=null&&previous.isFinite&&previous>0?(value-previous)/previous*100:_finite(row['changePct']);
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
        asOf: _isoDate(row['date']?.toString() ?? ''),
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

  double? _finite(dynamic value)=>value is num&&value.isFinite?value.toDouble():null;
  String _isoDate(String raw){
    if(RegExp(r'^\d{8}$').hasMatch(raw))return '${raw.substring(0,4)}-${raw.substring(4,6)}-${raw.substring(6,8)}';
    return raw;
  }
  bool _validDate(String raw){
    final iso=_isoDate(raw),date=DateTime.tryParse(_isoDate(raw));
    if(date==null||!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(iso))return false;
    return date.toIso8601String().startsWith(iso)&&!date.isAfter(DateTime.now().toUtc().add(const Duration(hours:9)));
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
