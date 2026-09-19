import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';

class DiseaseRepository {
  DiseaseRepository({http.Client? client}):_client=client??http.Client();
  static const _url='https://noah981.github.io/pig-market-brief/data/disease-alerts.json';
  static const _cacheKey='verified_disease_feed_v2';
  final http.Client _client;

  Future<DiseaseFeed> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey)??await rootBundle.loadString('assets/data/disease-alerts.json');
    return _parse(raw,true);
  }
  Future<DiseaseFeed> refresh()async{
    final response=await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw Exception('Disease feed unavailable');
    final raw=utf8.decode(response.bodyBytes);final feed=_parse(raw,false);
    await (await SharedPreferences.getInstance()).setString(_cacheKey,raw);return feed;
  }
  DiseaseFeed _parse(String raw,bool fromCache){
    final json=jsonDecode(raw) as Map<String,dynamic>;final items=<DiseaseAlert>[];final seen=<String>{};
    for(final x in (json['items'] as List? ?? const []).whereType<Map<String,dynamic>>()){
      final code=x['countryCode']?.toString()??'';if(code.isEmpty)continue;
      final summary=x['summary']?.toString()??'';final disease=x['disease']?.toString()??'';
      final place=_place(summary);final key='$disease|$summary';if(disease.isEmpty||summary.isEmpty||!seen.add(key))continue;
      items.add(DiseaseAlert(disease:disease,source:x['source']?.toString()??'',countryCode:code,scope:code=='KR'?'국내':'국외',evidenceLevel:x['evidenceLevel']?.toString()??'PUBLIC_UNCONFIRMED',level:x['level']?.toString()??'확인 중',summary:summary,sourceUrl:x['sourceUrl']?.toString()??'',publishedAt:x['publishedAt']?.toString()??x['detectedAt']?.toString()??'',region:place?.$1,latitude:place?.$2,longitude:place?.$3));
    }
    return DiseaseFeed(items:items,updatedAt:json['updatedAt']?.toString()??'',fromCache:fromCache);
  }
  (String,double,double)? _place(String text){
    const places=<String,(double,double)>{'강화':(37.746,126.488),'예천':(36.657,128.452),'창녕':(35.544,128.492),'순천':(34.950,127.487),'영주':(36.805,128.624),'상주':(36.410,128.159),'문경':(36.586,128.186),'김천':(36.139,128.114),'경주':(35.856,129.224)};
    for(final entry in places.entries){if(text.contains(entry.key))return(entry.key,entry.value.$1,entry.value.$2);}return null;
  }
}
