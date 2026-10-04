import 'dart:convert';
import 'package:dondonhae/data/weather_farm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('기상청 값으로 위험 신호와 점검 포인트를 만든다',()async{
    final repository=WeatherFarmRepository(clock:()=>DateTime(2026,9,20),client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode({'updatedAt':'2026-09-20T07:00:00+09:00','weatherSource':'기상청 단기예보 조회서비스','regions':[{'region':'대구광역시','tempMin':16,'tempMax':28,'humidityMax':95,'rainProbabilityMax':0,'riskFactors':['큰 일교차','고습'],'farmChecks':['야간 최소환기 확인','결로 확인']}]})),200)));
    final guide=await repository.refresh();
    expect(guide.diurnalRange,12);expect(guide.checks.length,2);
    final risks=repository.risks(guide);
    expect(risks.map((x)=>x.title),containsAll(['호흡기 질환군 관찰','설사성 질환군 관찰']));
    expect(WeatherFarmRepository.medicines.first.caution,contains('수의사'));
    final seasonal=repository.seasonalDiseases(DateTime(2026,9,20),guide);
    expect(seasonal.map((x)=>x.name).join(' '),contains('PRRS'));
    expect(seasonal.first.differentiate,contains('검사'));
  });
  test('조회 전에는 고정 기온이나 정상 위험을 표시하지 않는다',()async{
    final repository=WeatherFarmRepository();
    final guide=await repository.cached();
    expect(guide.hasForecast,isFalse);
    expect(guide.condition,'정보 없음');
    expect(repository.risks(guide).single.level,'확인 필요');
  });
  test('다른 지역 예보나 누락된 수치를 0으로 대체하지 않는다',()async{
    for(final row in [
      {'region':'서울특별시','tempMin':10,'tempMax':20,'humidityMax':70,'rainProbabilityMax':0},
      {'region':'대구광역시','tempMin':10,'tempMax':20,'rainProbabilityMax':0},
    ]){
      final repository=WeatherFarmRepository(client:MockClient((_)async=>http.Response(jsonEncode({'regions':[row]}),200,headers:{'content-type':'application/json; charset=utf-8'})));
      await expectLater(repository.refresh(region:'대구광역시'),throwsFormatException);
    }
  });

  test('지난 날짜의 예보를 오늘 날씨로 재사용하지 않는다',()async{
    final repository=WeatherFarmRepository(clock:()=>DateTime(2026,10,4),client:MockClient((_)async=>http.Response(jsonEncode({'updatedAt':'2026-10-03T07:00:00+09:00','regions':[{'region':'대구광역시','tempMin':12,'tempMax':25,'humidityMax':70,'rainProbabilityMax':0}]}),200,headers:{'content-type':'application/json; charset=utf-8'})));
    await expectLater(repository.refresh(region:'대구광역시'),throwsFormatException);
  });

}
