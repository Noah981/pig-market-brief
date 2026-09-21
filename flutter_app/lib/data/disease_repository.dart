import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';
import '../settings/farm_location_settings.dart';
import '../config/api_config.dart';
import '../services/api/mafra_api_client.dart';

class DiseaseRepository {
  DiseaseRepository({http.Client? client,MafraApiClient? mafraClient}):_client=client??http.Client(),_mafraClient=mafraClient??MafraApiClient(client:client);
  static const _url='https://noah981.github.io/pig-market-brief/data/disease-alerts.json';
  static const _cacheKey='verified_disease_feed_v2';
  final http.Client _client;
  final MafraApiClient _mafraClient;

  Future<DiseaseFeed> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey)??await rootBundle.loadString('assets/data/disease-alerts.json');
    return _parse(raw,true);
  }
  Future<DiseaseFeed> refresh()async{
    if(ApiConfig.hasMafra){
      final rows=await _mafraApi();final official=<DiseaseAlert>[];final representatives=await _provinceRepresentatives();
      for(final row in rows){
        final disease=row.pick(const ['LKNTS_NM']);
        final livestock=row.pick(const ['LVSTCKSPC_NM']);
        if(!_isPigDisease(disease,livestock))continue;
        final region=row.pick(const ['FARM_LOCPLC']);
        final place=FarmLocationSettings.find(region);if(place==null)continue;
        final representative=representatives.entries.where((x)=>region.contains(x.key)||_sameProvinceAlias(region,x.key)).map((x)=>x.value).firstOrNull;
        if(representative==null)continue;
        final occurrence=row.pick(const ['OCCRRNC_DE']);
        final id=row.pick(const ['ICTSD_OCCRRNC_NO']);
        final ended=row.pick(const ['CESSATION_DE']);
        official.add(DiseaseAlert(id:id.isEmpty?'MAFRA|$disease|$region|$occurrence':id,disease:disease,source:'농림축산검역본부 가축질병발생정보',countryCode:'KR',scope:'국내',evidenceLevel:'OFFICIAL',level:ended.isEmpty?'발생':'종식',summary:'$region $disease',sourceUrl:'https://data.mafra.go.kr/opendata/data/indexOpenDataDetail.do?data_id=20151204000000000563',publishedAt:occurrence,occurrenceDate:occurrence,livestockType:livestock,districtCode:row.pick(const ['FARM_LOCPLC_LEGALDONG_CODE']),region:place.cityCounty,latitude:representative.$2,longitude:representative.$1));
      }
      final previous=await cached();final overseas=previous.items.where((x)=>x.countryCode!='KR').toList();
      final feed=DiseaseFeed(items:[...official,...overseas],updatedAt:DateTime.now().toIso8601String(),fromCache:false);
      await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode({'updatedAt':feed.updatedAt,'items':feed.items.map(_toJson).toList()}));return feed;
    }
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
      items.add(DiseaseAlert(id:x['id']?.toString()??'',disease:disease,source:x['source']?.toString()??'',countryCode:code,scope:code=='KR'?'국내':'국외',evidenceLevel:x['evidenceLevel']?.toString()??'PUBLIC_UNCONFIRMED',level:x['level']?.toString()??'확인 중',summary:summary,sourceUrl:x['sourceUrl']?.toString()??'',publishedAt:x['publishedAt']?.toString()??x['detectedAt']?.toString()??'',occurrenceDate:x['occurrenceDate']?.toString()??'',livestockType:x['livestockType']?.toString()??'',districtCode:x['districtCode']?.toString()??'',region:structuredRegion??place?.cityCounty,latitude:lat??place?.latitude,longitude:lng??place?.longitude));
    }
    return DiseaseFeed(items:items,updatedAt:json['updatedAt']?.toString()??'',fromCache:fromCache);
  }
  Future<List<MafraDiseaseRow>> _mafraApi()=>_mafraClient.fetch();
  bool _isPigDisease(String disease,String livestock){final text='$disease $livestock'.toUpperCase();return text.contains('돼지')||text.contains('ASF')||text.contains('구제역')||text.contains('PRRS')||text.contains('PED')||text.contains('SWINE');}
  Map<String,dynamic> _toJson(DiseaseAlert x)=>{'id':x.id,'disease':x.disease,'source':x.source,'countryCode':x.countryCode,'evidenceLevel':x.evidenceLevel,'level':x.level,'summary':x.summary,'sourceUrl':x.sourceUrl,'publishedAt':x.publishedAt,'occurrenceDate':x.occurrenceDate,'livestockType':x.livestockType,'districtCode':x.districtCode,'region':x.region,'latitude':x.latitude,'longitude':x.longitude};
  bool _sameProvinceAlias(String address,String name)=>(name.startsWith('강원')&&address.contains('강원도'))||(name.startsWith('전북')&&address.contains('전라북도'));
  Future<Map<String,(double,double)>> _provinceRepresentatives()async{
    final bytes=await rootBundle.load('assets/data/korea_provinces.geojson.gz');
    final root=jsonDecode(utf8.decode(gzip.decode(bytes.buffer.asUint8List()))) as Map<String,dynamic>;
    final result=<String,(double,double)>{};
    for(final feature in (root['features'] as List? ?? const []).whereType<Map<String,dynamic>>()){
      final name=((feature['properties'] as Map?)?['name'])?.toString()??'';final geometry=feature['geometry'] as Map<String,dynamic>?;if(name.isEmpty||geometry==null)continue;
      final coordinates=geometry['coordinates'] as List? ?? const [];final rings=<List>[];
      if(geometry['type']=='Polygon'){if(coordinates.isNotEmpty)rings.add(coordinates.first as List);}
      if(geometry['type']=='MultiPolygon'){for(final polygon in coordinates.whereType<List>()){if(polygon.isNotEmpty)rings.add(polygon.first as List);}}
      if(rings.isEmpty)continue;rings.sort((a,b)=>b.length.compareTo(a.length));
      final points=rings.first.whereType<List>().where((p)=>p.length>=2).toList();if(points.isEmpty)continue;
      final lon=points.map((p)=>(p[0] as num).toDouble()).reduce((a,b)=>a+b)/points.length;
      final lat=points.map((p)=>(p[1] as num).toDouble()).reduce((a,b)=>a+b)/points.length;
      result[name]=(lon,lat);
    }
    return result;
  }
}
