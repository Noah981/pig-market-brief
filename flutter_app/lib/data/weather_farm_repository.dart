import 'dart:convert';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/weather_farm_models.dart';
import '../config/api_config.dart';
import '../services/api/kma_api_client.dart';
import '../settings/farm_location_settings.dart';

class WeatherFarmRepository {
  WeatherFarmRepository({http.Client? client,KmaApiClient? kmaClient}):_client=client??http.Client(),_kmaClient=kmaClient??KmaApiClient(client:client);
  static const _url='https://noah981.github.io/pig-market-brief/data/briefing.json';
  static const _cacheKey='weather_farm_guide_v2';
  final http.Client _client;
  final KmaApiClient _kmaClient;
  static const fallback=WeatherFarmGuide(region:'지역 설정 필요',tempMin:double.nan,tempMax:double.nan,humidity:double.nan,rainProbability:double.nan,riskFactors:[],checks:['지역을 설정하고 공식 예보를 새로 조회해 주세요.'],updatedAt:'',source:'예보 미확인',fromCache:true);

  Future<WeatherFarmGuide> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null)return fallback;
    try{return _decode(jsonDecode(raw) as Map<String,dynamic>,true,preferredRegion:FarmLocationSettings.instance.location.province);}catch(_){return fallback;}
  }
  Future<WeatherFarmGuide> refresh({String region='대구광역시'})async{
    if(ApiConfig.hasKma){
      try {
      final location=FarmLocationSettings.instance.location;
      double lat=location.latitude,lng=location.longitude;
      if(!location.gpsVerified){
        if(location.label.isEmpty)throw const FormatException('Location not configured');
        final matches=await locationFromAddress('대한민국 ${location.label}').timeout(const Duration(seconds:8));
        if(matches.isEmpty)throw const FormatException('Location unresolved');
        lat=matches.first.latitude;lng=matches.first.longitude;
      }
      if(!lat.isFinite||!lng.isFinite||lat<33||lat>39||lng<124||lng>132)throw const FormatException('Invalid Korean coordinates');
      final forecast=await _kmaApi(lat,lng);
      final value=WeatherFarmGuide(region:location.label,tempMin:forecast.tempMin,tempMax:forecast.tempMax,humidity:forecast.humidityMax,rainProbability:forecast.rainProbabilityMax,windSpeed:forecast.windSpeedMax.isFinite?forecast.windSpeedMax:null,riskFactors:_riskLabels(forecast.tempMin,forecast.tempMax,forecast.humidityMax),checks:_checks(forecast.tempMin,forecast.tempMax,forecast.humidityMax),updatedAt:'${forecast.baseDate} ${forecast.baseTime}',source:'기상청 단기예보 조회서비스',fromCache:false);
      await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode({'updatedAt':value.updatedAt,'weatherSource':value.source,'regions':[{'region':value.region,'tempMin':value.tempMin,'tempMax':value.tempMax,'humidityMax':value.humidity,'rainProbabilityMax':value.rainProbability,'windSpeedMax':value.windSpeed,'riskFactors':value.riskFactors,'farmChecks':value.checks}]}));
      return value;
      } catch (_) { /* Try the matching official regional feed. */ }
    }
    final response=await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw Exception('Weather briefing unavailable');
    final raw=utf8.decode(response.bodyBytes),json=jsonDecode(raw) as Map<String,dynamic>;
    final value=_decode(json,false,preferredRegion:region);
    await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode({'updatedAt':json['updatedAt'],'weatherSource':json['weatherSource'],'regions':[...((json['regions'] as List? ?? const []).whereType<Map<String,dynamic>>().where((x)=>x['region']==value.region))]}));
    return value;
  }
  Future<KmaForecast> _kmaApi(double lat,double lng)=>_kmaClient.forecast(lat,lng);
  List<String> _riskLabels(double min,double max,double humidity)=>[if(max-min>=8)'큰 일교차',if(humidity>=80)'고습',if(max>=30)'열스트레스'];
  List<String> _checks(double min,double max,double humidity)=>[if(max-min>=8)'야간 최소환기와 입기구 방향을 확인하세요.',if(humidity>=80)'결로와 바닥 습윤, 암모니아를 확인하세요.',if(max>=30)'음수량과 쿨링·환기 상태를 확인하세요.',if(max-min<8&&humidity<80&&max<30)'기본 환기와 돈군 상태를 확인하세요.'];
  WeatherFarmGuide _decode(Map<String,dynamic> json,bool fromCache,{String preferredRegion='대구광역시'}){
    final regions=(json['regions'] as List? ?? const []).whereType<Map<String,dynamic>>().toList();
    if(regions.isEmpty)throw const FormatException('No weather region');
    final wanted=preferredRegion.isEmpty?FarmLocationSettings.instance.location.province:preferredRegion;
    final matches=regions.where((x)=>x['region']==wanted||x['region']==FarmLocationSettings.instance.location.label).toList();
    if(matches.isEmpty)throw const FormatException('Requested weather region unavailable');
    final row=matches.first;
    for(final key in ['tempMin','tempMax','humidityMax','rainProbabilityMax']){final value=row[key];if(value is! num||!value.isFinite)throw const FormatException('Incomplete official forecast');}
    if((row['tempMin'] as num)>(row['tempMax'] as num)||(row['humidityMax'] as num)<0||(row['humidityMax'] as num)>100||(row['rainProbabilityMax'] as num)<0||(row['rainProbabilityMax'] as num)>100)throw const FormatException('Invalid forecast');
    return WeatherFarmGuide(region:row['region']?.toString()??preferredRegion,tempMin:(row['tempMin'] as num?)?.toDouble()??0,tempMax:(row['tempMax'] as num?)?.toDouble()??0,humidity:(row['humidityMax'] as num?)?.toDouble()??0,rainProbability:(row['rainProbabilityMax'] as num?)?.toDouble()??0,windSpeed:(row['windSpeedMax'] as num?)?.toDouble(),riskFactors:(row['riskFactors'] as List? ?? const []).map((x)=>x.toString()).toList(),checks:(row['farmChecks'] as List? ?? row['top3'] as List? ?? const []).map((x)=>x.toString()).toList(),updatedAt:json['updatedAt']?.toString()??'',source:json['weatherSource']?.toString()??'기상청',fromCache:fromCache);
  }

  List<FarmHealthRisk> risks(WeatherFarmGuide weather){
    if(!weather.hasForecast)return const [FarmHealthRisk('예보 미확인','확인 필요','공식 예보가 없어 기상 위험을 판단할 수 없습니다.','지역 설정·네트워크·공식 기준일을 확인하세요.')];
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

  List<SeasonalDiseaseGuide> seasonalDiseases(DateTime now,WeatherFarmGuide weather){
    final coldSeason=now.month>=11||now.month<=3;
    final transition=now.month==3||now.month==4||now.month==9||now.month==10||weather.diurnalRange>=8;
    final result=<SeasonalDiseaseGuide>[];
    if(transition){result.addAll(const [
      SeasonalDiseaseGuide('PRRS·돼지인플루엔자 등 호흡기 질환군','환절기 일교차와 외풍은 돈군 스트레스를 높여 기존 감염의 임상증상이 두드러질 수 있습니다.','기침, 발열, 귀·피부 청색증, 호흡곤란, 성장정체, 모돈 유산·조산','PRRS, 인플루엔자, 마이코플라스마, 흉막폐렴은 증상이 겹칠 수 있어 PCR·부검 등 수의사 검사가 필요합니다.','복식호흡·고열·급격한 폐사·유산 증가 시 당일 수의사 상담'),
      SeasonalDiseaseGuide('마이코플라스마성 폐렴·흉막폐렴 관찰','최소환기가 줄거나 결로·암모니아가 높아지면 호흡기 증상이 악화될 수 있습니다.','지속적인 마른기침, 복식호흡, 사료섭취 감소, 갑작스러운 고열·폐사','기침만으로 원인체를 구분할 수 없습니다. 돈사 환경 확인과 함께 검사해야 합니다.','입 벌림 호흡·혈성 비말·급사는 즉시 수의사 연락'),
    ]);}
    if(coldSeason||weather.humidity>=80){result.add(const SeasonalDiseaseGuide('PED 등 설사성 질환군','저온·고습기에는 소독 후 건조가 늦어지고 분변 오염 관리가 어려워질 수 있습니다.','수양성 설사, 구토, 탈수, 포유자돈 체온저하·폐사','사료성 설사, 대장균, 로타바이러스 등과 증상이 비슷해 농장 내 전파양상과 검사가 필요합니다.','포유자돈 집단 설사·구토가 시작되면 이동을 줄이고 즉시 수의사 상담'));}
    if(weather.tempMax>=30){result.add(const SeasonalDiseaseGuide('열스트레스와 2차 건강문제','고온은 섭취량·번식성적을 낮추고 기존 질환의 회복을 방해할 수 있습니다.','헐떡임, 침흘림, 무기력, 사료섭취 감소, 포유돈 유량 저하','감염성 발열과 환경성 고체온을 체온·돈사온도·돈군 분포로 함께 확인해야 합니다.','쓰러짐·심한 호흡곤란은 즉시 냉각조치와 수의사 연락'));}
    return result.isEmpty?const [SeasonalDiseaseGuide('연중 기본 관찰','뚜렷한 계절 위험 신호가 낮아도 농장 내 질병은 발생할 수 있습니다.','섭취량·음수량 변화, 기침, 설사, 발열, 유산, 폐사 증가','한 가지 증상만으로 질병을 확정하지 않습니다.','돈군 단위로 급격한 변화가 있으면 수의사 상담')]:result;
  }
}
