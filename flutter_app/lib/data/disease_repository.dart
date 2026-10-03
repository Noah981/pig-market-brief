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
  // v4: 기사 게시일 기반 공개뉴스 캐시를 폐기하고 공식 발생 자료만 사용.
  static const _cacheKey='verified_disease_feed_v4';
  final http.Client _client;final MafraApiClient _mafraClient;final DateTime Function() _clock;

  Future<DiseaseFeed> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey)??await rootBundle.loadString('assets/data/disease-alerts.json');
    return _parse(raw,true);
  }
  Future<DiseaseFeed> refresh()async{
    try{
      final hosted=await _fromHosted();
      DiseaseFeed feed=hosted;
      if(ApiConfig.hasMafra){try{feed=await _fromMafra(hosted);}catch(_){feed=DiseaseFeed(items:hosted.items,updatedAt:hosted.updatedAt,fromCache:false,state:DiseaseDataState.reviewRequired,errorMessage:'국내 공식 API 확인 실패 · 해외 공식 자료는 표시합니다.');}}
      await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode(_feedJson(feed)));
      return feed;
    }catch(error){
      try{final old=await cached();return DiseaseFeed(items:old.items,updatedAt:old.updatedAt,fromCache:true,state:DiseaseDataState.stale,errorMessage:'공식 데이터 확인 실패');}
      catch(_){return DiseaseFeed(items:const [],updatedAt:'',fromCache:true,state:DiseaseDataState.error,errorMessage:'질병 데이터를 확인할 수 없습니다.');}
    }
  }
  Future<DiseaseFeed> _fromMafra(DiseaseFeed hosted)async{
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
    final merged=<String,DiseaseAlert>{};
    for(final x in hosted.items){_putLatest(merged,x);}
    // An official result always wins over a public signal for the same incident.
    for(final x in items){merged[x.incidentKey]=x;}
    return DiseaseFeed(items:merged.values.toList(),updatedAt:_clock().toIso8601String(),fromCache:false,coverageVerified:hosted.coverageVerified,state:hosted.coverageVerified?DiseaseDataState.live:DiseaseDataState.reviewRequired,errorMessage:hosted.coverageVerified?null:'국내 전체 조회 범위를 확인 중입니다. 표시된 자료만으로 발생 없음을 판단하지 마세요.');
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
      // publishedAt is not an incident date. Old incidents are often
      // republished, so using it here makes February events look current.
      final occurrence=x['occurrenceDate']?.toString()??x['eventDate']?.toString()??'';
      final summary=x['summary']?.toString()??'';if(summary.isEmpty||(occurrence.isEmpty&&(code=='KR'||x['dateBasis']!='notification'||x['announcementDate']==null)))continue;
      final evidence=(x['evidenceLevel']?.toString().toUpperCase()=='OFFICIAL'||x['verificationLevel']?.toString().toUpperCase()=='OFFICIAL')?DiseaseEvidence.official:DiseaseEvidence.publicInfo;
      final address=x['region']?.toString()??summary;
      final rawStatus=x['status']?.toString()??x['level']?.toString()??'확인 중';
      final status=_status(rawStatus,summary,evidence);
      final alert=DiseaseAlert(id:x['id']?.toString()??'',type:type,source:x['source']?.toString()??'',countryCode:code,evidence:evidence,status:status,summary:summary,sourceUrl:x['sourceUrl']?.toString()??'',occurrenceDate:occurrence,announcementDate:x['announcementDate']?.toString()??x['publishedAt']?.toString()??'',updatedAt:x['updatedAt']?.toString()??x['detectedAt']?.toString()??'',livestockType:x['livestockType']?.toString()??'',districtCode:x['districtCode']?.toString()??'',province:x['province']?.toString()??_province(address),cityCounty:x['cityCounty']?.toString()??_cityCounty(address),town:x['town']?.toString()??'',latitude:(x['latitude'] as num?)?.toDouble(),longitude:(x['longitude'] as num?)?.toDouble());
      if(seen.add(alert.stableKey))items.add(alert);
    }
    final unverifiedEmpty=items.isEmpty&&json['coverageVerified']!=true;
    return DiseaseFeed(items:items,updatedAt:json['updatedAt']?.toString()??'',fromCache:fromCache,coverageVerified:json['coverageVerified']==true,state:fromCache?DiseaseDataState.stale:unverifiedEmpty?DiseaseDataState.reviewRequired:DiseaseDataState.live,errorMessage:unverifiedEmpty?'공식 발생자료의 조회 범위를 확인하지 못했습니다. 발생 없음으로 판단하지 마세요.':null);
  }
  String _status(String raw,String summary,DiseaseEvidence evidence){if(raw.contains('종식'))return '종식';if(raw.contains('공식 통보'))return '공식 통보';final text='$raw $summary';if(RegExp(r'음성|불검출|의심.*해제|발생하지 않은').hasMatch(text))return '음성 · 의심 해제';if(RegExp(r'의심|검사 중|정밀검사').hasMatch(text))return '의심 · 정밀검사 중';if(evidence==DiseaseEvidence.official||RegExp(r'확진|양성|공식 발생').hasMatch(text))return '공식 발생';return '공개정보 · 확인 중';}
  void _putLatest(Map<String,DiseaseAlert> target,DiseaseAlert next){
    final old=target[next.incidentKey];
    if(old==null||_eventMoment(next).isAfter(_eventMoment(old))||(_eventMoment(next)==_eventMoment(old)&&_statusRank(next)>_statusRank(old))){target[next.incidentKey]=next;}
  }
  DateTime _eventMoment(DiseaseAlert event){
    for(final value in [event.updatedAt,event.announcementDate,event.occurrenceDate]){
      final parsed=DateTime.tryParse(value);
      if(parsed!=null)return parsed;
      final digits=value.replaceAll(RegExp(r'[^0-9]'),'');
      if(digits.length>=8){final date=DateTime.tryParse('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}');if(date!=null)return date;}
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
  int _statusRank(DiseaseAlert event)=>event.isNegative?4:event.isConfirmed?3:event.isSuspected?2:1;
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
  Map<String,dynamic> _feedJson(DiseaseFeed feed)=>{'schemaVersion':4,'coverageVerified':feed.coverageVerified,'updatedAt':feed.updatedAt,'items':feed.items.map((x)=>{'id':x.id,'diseaseType':x.type.name,'disease':x.disease,'countryCode':x.countryCode,'evidenceLevel':x.isOfficial?'OFFICIAL':'PUBLIC_INFO','status':x.status,'summary':x.summary,'source':x.source,'sourceUrl':x.sourceUrl,'occurrenceDate':x.occurrenceDate,'announcementDate':x.announcementDate,'dateBasis':x.usesNotificationDate?'notification':'occurrence','updatedAt':x.updatedAt,'livestockType':x.livestockType,'districtCode':x.districtCode,'province':x.province,'cityCounty':x.cityCounty,'town':x.town,'latitude':x.latitude,'longitude':x.longitude}).toList()};
}
