import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';
import '../models/disease_models.dart';
import '../services/api/mafra_api_client.dart';

class DiseaseRepository {
  DiseaseRepository({http.Client? client,MafraApiClient? mafraClient,DateTime Function()? clock}):_client=client??http.Client(),_mafraClient=mafraClient??MafraApiClient(client:client),_clock=clock??DateTime.now;
  static const _url='https://noah981.github.io/pig-market-brief/data/disease-alerts.json';
  static const _cacheKey='verified_disease_feed_v3';
  final http.Client _client;final MafraApiClient _mafraClient;final DateTime Function() _clock;

  Future<DiseaseFeed> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey)??await rootBundle.loadString('assets/data/disease-alerts.json');
    return _parse(raw,true);
  }
  Future<DiseaseFeed> refresh()async{
    try{
      final feed=ApiConfig.hasMafra?await _fromMafra():await _fromHosted();
      await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode(_feedJson(feed)));
      return feed;
    }catch(error){
      try{final old=await cached();return DiseaseFeed(items:old.items,updatedAt:old.updatedAt,fromCache:true,state:DiseaseDataState.stale,errorMessage:'공식 데이터 확인 실패');}
      catch(_){return DiseaseFeed(items:const [],updatedAt:'',fromCache:true,state:DiseaseDataState.error,errorMessage:'질병 데이터를 확인할 수 없습니다.');}
    }
  }
  Future<DiseaseFeed> _fromMafra()async{
    final rows=await _mafraClient.fetch(),items=<DiseaseAlert>[],seen=<String>{};
    for(final row in rows){
      final rawDisease=row.pick(const ['LKNTS_NM','DISEASE_NM','DISS_NM']),type=normalizeDiseaseType(rawDisease);
      final livestock=row.pick(const ['LVSTCKSPC_NM','LSK_NM']);
      if(type==null||!_isPigRelevant(type,livestock))continue;
      final occurrence=row.pick(const ['OCCRRNC_DE','OCCRRNC_DT','FRST_OCRN_DT']);if(occurrence.isEmpty)continue;
      final address=row.pick(const ['FARM_LOCPLC','OCCRRNC_AREA','ADDR']);
      final id=row.pick(const ['ICTSD_OCCRRNC_NO','OCCRRNC_NO']);
      final coordinate=await _coordinate(row,address,occurrence);
      final alert=DiseaseAlert(id:id.isEmpty?'MAFRA|${type.name}|$occurrence|$address':id,type:type,source:'농림축산검역본부 가축질병발생정보',countryCode:'KR',evidence:DiseaseEvidence.official,status:row.pick(const ['CESSATION_DE']).isEmpty?'발생':'종식',summary:'$address ${type.label}',sourceUrl:'https://data.mafra.go.kr/opendata/data/indexOpenDataDetail.do?data_id=20151204000000000316',occurrenceDate:occurrence,announcementDate:row.pick(const ['PBLANC_DE','REGIST_DE']),updatedAt:row.pick(const ['UPDT_DE']),livestockType:livestock,districtCode:row.pick(const ['FARM_LOCPLC_LEGALDONG_CODE']),province:_province(address),cityCounty:_cityCounty(address),town:_town(address),latitude:coordinate?.$1,longitude:coordinate?.$2);
      if(seen.add(alert.stableKey))items.add(alert);
    }
    final previous=await cached(),overseas=previous.items.where((x)=>x.countryCode!='KR');
    return DiseaseFeed(items:[...items,...overseas],updatedAt:_clock().toIso8601String(),fromCache:false,state:DiseaseDataState.live);
  }
  Future<DiseaseFeed> _fromHosted()async{
    final response=await _client.get(Uri.parse('$_url?v=${_clock().millisecondsSinceEpoch}')).timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw Exception('Disease feed unavailable');
    return _parse(utf8.decode(response.bodyBytes),false);
  }
  DiseaseFeed _parse(String raw,bool fromCache){
    final json=jsonDecode(raw) as Map<String,dynamic>,items=<DiseaseAlert>[],seen=<String>{};
    for(final value in (json['items'] as List? ?? const [])){
      if(value is! Map)continue;final x=value.cast<String,dynamic>();
      final type=normalizeDiseaseType(x['diseaseType']?.toString()??x['disease']?.toString()??'');if(type==null)continue;
      final code=(x['countryCode']?.toString()??'').toUpperCase();if(code.isEmpty)continue;
      final occurrence=x['occurrenceDate']?.toString()??x['eventDate']?.toString()??x['publishedAt']?.toString()??'';
      final summary=x['summary']?.toString()??'';if(occurrence.isEmpty||summary.isEmpty)continue;
      final evidence=(x['evidenceLevel']?.toString().toUpperCase()=='OFFICIAL'||x['verificationLevel']?.toString().toUpperCase()=='OFFICIAL')?DiseaseEvidence.official:DiseaseEvidence.publicInfo;
      final address=x['region']?.toString()??summary;
      final alert=DiseaseAlert(id:x['id']?.toString()??'',type:type,source:x['source']?.toString()??'',countryCode:code,evidence:evidence,status:x['status']?.toString()??x['level']?.toString()??'확인 중',summary:summary,sourceUrl:x['sourceUrl']?.toString()??'',occurrenceDate:occurrence,announcementDate:x['announcementDate']?.toString()??x['publishedAt']?.toString()??'',updatedAt:x['updatedAt']?.toString()??'',livestockType:x['livestockType']?.toString()??'',districtCode:x['districtCode']?.toString()??'',province:x['province']?.toString()??_province(address),cityCounty:x['cityCounty']?.toString()??_cityCounty(address),town:x['town']?.toString()??'',latitude:(x['latitude'] as num?)?.toDouble(),longitude:(x['longitude'] as num?)?.toDouble());
      if(seen.add(alert.stableKey))items.add(alert);
    }
    return DiseaseFeed(items:items,updatedAt:json['updatedAt']?.toString()??'',fromCache:fromCache,state:fromCache?DiseaseDataState.stale:DiseaseDataState.live);
  }
  bool _isPigRelevant(DiseaseType type,String livestock)=>type!=DiseaseType.fmd||livestock.isEmpty||livestock.contains('돼지')||livestock.toUpperCase().contains('SWINE');
  double? _number(MafraDiseaseRow row,List<String> keys)=>double.tryParse(row.pick(keys));
  Future<(double,double)?> _coordinate(MafraDiseaseRow row,String address,String occurrence)async{
    final lat=_number(row,const ['LAT','LATITUDE','Y']),lng=_number(row,const ['LON','LNG','LONGITUDE','X']);if(lat!=null&&lng!=null)return (lat,lng);
    final digits=occurrence.replaceAll(RegExp(r'[^0-9]'),'');if(address.isEmpty||digits.length<8)return null;
    final date=DateTime.tryParse('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}');if(date==null||_clock().difference(date).inDays>30)return null;
    try{final locations=await locationFromAddress(address);final point=locations.firstOrNull;return point==null?null:(point.latitude,point.longitude);}catch(_){return null;}
  }
  String _province(String text)=>RegExp(r'(서울특별시|부산광역시|대구광역시|인천광역시|광주광역시|대전광역시|울산광역시|세종특별자치시|경기도|강원(?:특별자치)?도|충청북도|충청남도|전북특별자치도|전라북도|전라남도|경상북도|경상남도|제주특별자치도)').firstMatch(text)?.group(0)??'';
  String _cityCounty(String text)=>RegExp(r'([가-힣]+(?:시|군)(?:\s+[가-힣]+구)?|[가-힣]+구)').firstMatch(text.replaceFirst(_province(text),''))?.group(0)??'';
  String _town(String text)=>RegExp(r'([가-힣]+(?:읍|면|동))').firstMatch(text)?.group(0)??'';
  Map<String,dynamic> _feedJson(DiseaseFeed feed)=>{'schemaVersion':3,'updatedAt':feed.updatedAt,'items':feed.items.map((x)=>{'id':x.id,'diseaseType':x.type.name,'disease':x.disease,'countryCode':x.countryCode,'evidenceLevel':x.isOfficial?'OFFICIAL':'PUBLIC_INFO','status':x.status,'summary':x.summary,'source':x.source,'sourceUrl':x.sourceUrl,'occurrenceDate':x.occurrenceDate,'announcementDate':x.announcementDate,'updatedAt':x.updatedAt,'livestockType':x.livestockType,'districtCode':x.districtCode,'province':x.province,'cityCounty':x.cityCounty,'town':x.town,'latitude':x.latitude,'longitude':x.longitude}).toList()};
}
