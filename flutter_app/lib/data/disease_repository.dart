import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';
import '../settings/farm_location_settings.dart';
import '../core/network/api_environment.dart';

class DiseaseRepository {
  DiseaseRepository({http.Client? client}):_client=client??http.Client();
  static final _url='${ApiEnvironment.publicDataBaseUrl}/disease-alerts.json';
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
      final structuredRegion=x['region']?.toString();final lat=(x['latitude'] as num?)?.toDouble(),lng=(x['longitude'] as num?)?.toDouble();
      final place=(structuredRegion==null?null:FarmLocationSettings.find(structuredRegion))??FarmLocationSettings.find(summary);final key='$disease|$summary';if(disease.isEmpty||summary.isEmpty||!seen.add(key))continue;
      items.add(DiseaseAlert(disease:disease,source:x['source']?.toString()??'',countryCode:code,scope:code=='KR'?'국내':'국외',evidenceLevel:x['evidenceLevel']?.toString()??'PUBLIC_UNCONFIRMED',level:x['level']?.toString()??'확인 중',summary:summary,sourceUrl:x['sourceUrl']?.toString()??'',publishedAt:x['publishedAt']?.toString()??x['detectedAt']?.toString()??'',region:structuredRegion??place?.cityCounty,latitude:lat??place?.latitude,longitude:lng??place?.longitude));
    }
    return DiseaseFeed(items:items,updatedAt:json['updatedAt']?.toString()??'',fromCache:fromCache);
  }
}
