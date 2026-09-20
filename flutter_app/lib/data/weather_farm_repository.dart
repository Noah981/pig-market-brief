import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_farm_models.dart';

class WeatherFarmRepository {
  WeatherFarmRepository({http.Client? client}):_client=client??http.Client();
  static const _url='https://noah981.github.io/pig-market-brief/data/briefing.json';
  static const _cacheKey='weather_farm_guide_v1';
  final http.Client _client;
  static const fallback=WeatherFarmGuide(region:'대구·경북',tempMin:16,tempMax:28,humidity:95,rainProbability:0,riskFactors:['큰 일교차','고습'],checks:['야간 최소환기와 입기구 방향을 확인하세요.','기침이 늘면 온도·일교차·암모니아를 확인하세요.','자돈이 뭉치면 외풍과 보온구역을 확인하세요.'],updatedAt:'2026-09-20T07:53:12+09:00',source:'기상청 단기예보 조회서비스',fromCache:true);

  Future<WeatherFarmGuide> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null)return fallback;
    try{return _decode(jsonDecode(raw) as Map<String,dynamic>,true);}catch(_){return fallback;}
  }
  Future<WeatherFarmGuide> refresh({String region='대구광역시'})async{
    final response=await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw Exception('Weather briefing unavailable');
    final raw=utf8.decode(response.bodyBytes),json=jsonDecode(raw) as Map<String,dynamic>;
    final value=_decode(json,false,preferredRegion:region);
    await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode({'updatedAt':json['updatedAt'],'weatherSource':json['weatherSource'],'regions':[...((json['regions'] as List? ?? const []).whereType<Map<String,dynamic>>().where((x)=>x['region']==value.region))]}));
    return value;
  }
  WeatherFarmGuide _decode(Map<String,dynamic> json,bool fromCache,{String preferredRegion='대구광역시'}){
    final regions=(json['regions'] as List? ?? const []).whereType<Map<String,dynamic>>().toList();
    if(regions.isEmpty)throw const FormatException('No weather region');
    final row=regions.firstWhere((x)=>x['region']==preferredRegion,orElse:()=>regions.first);
    return WeatherFarmGuide(region:row['region']?.toString()??preferredRegion,tempMin:(row['tempMin'] as num?)?.toDouble()??0,tempMax:(row['tempMax'] as num?)?.toDouble()??0,humidity:(row['humidityMax'] as num?)?.toDouble()??0,rainProbability:(row['rainProbabilityMax'] as num?)?.toDouble()??0,riskFactors:(row['riskFactors'] as List? ?? const []).map((x)=>x.toString()).toList(),checks:(row['farmChecks'] as List? ?? row['top3'] as List? ?? const []).map((x)=>x.toString()).toList(),updatedAt:json['updatedAt']?.toString()??'',source:json['weatherSource']?.toString()??'기상청',fromCache:fromCache);
  }

  List<FarmHealthRisk> risks(WeatherFarmGuide weather){
    final result=<FarmHealthRisk>[];
    if(weather.diurnalRange>=8)result.add(const FarmHealthRisk('호흡기 질환군 관찰','주의','큰 일교차와 외풍은 돼지의 스트레스를 높일 수 있습니다. 날씨만으로 PRRS·인플루엔자·흉막폐렴 등을 구분할 수 없습니다.','기침·재채기·복식호흡·발열·사료섭취 감소'));
    if(weather.humidity>=80)result.add(const FarmHealthRisk('설사성 질환군 관찰','주의','고습과 결로는 돈사 내 가스·오염 부담을 키울 수 있습니다. PED 등 감염병 여부는 임상증상과 검사로 확인해야 합니다.','결로·바닥 습윤·설사·구토·돈군 뭉침'));
    if(weather.tempMax>=30)result.add(const FarmHealthRisk('열스트레스','높음','고온은 섭취량과 번식·포유 성적에 영향을 줄 수 있습니다.','헐떡임·음수 증가·사료섭취 감소·무기력'));
    if(result.isEmpty)result.add(const FarmHealthRisk('일상 관찰','보통','뚜렷한 기상 위험 신호는 낮지만 돈군 상태는 매일 확인해야 합니다.','섭취량·음수량·분변·기침·체온 이상'));
    return result;
  }

  static const medicines=[
    MedicineGuide('해열·소염제','발열·통증·염증의 보조적 관리에 사용되는 계열','원인 진단 없이 사용하면 증상을 가릴 수 있습니다. 성분·용량·휴약기간은 수의사가 결정해야 합니다.'),
    MedicineGuide('전해질·영양 보조제','탈수 또는 섭취 저하 시 보조적으로 검토하는 계열','치료제를 대신하지 않습니다. 음수 상태와 제품 표시사항을 확인하고 수의사와 상의하세요.'),
    MedicineGuide('항균제','세균성 질환이 의심·확인될 때 검토하는 처방 계열','바이러스성 질환에는 효과가 없습니다. 진단·감수성·처방과 휴약기간 준수가 필요합니다.'),
    MedicineGuide('백신','질병 예방을 위한 농장별 프로그램','발병 후 치료제가 아닙니다. 돈군 면역상태와 접종 시기는 담당 수의사가 정해야 합니다.'),
  ];
}
