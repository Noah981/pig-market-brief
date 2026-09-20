import 'dart:convert';
import 'package:dondonhae/data/weather_farm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('기상청 값으로 위험 신호와 점검 포인트를 만든다',()async{
    final repository=WeatherFarmRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode({'updatedAt':'2026-09-20T07:00:00+09:00','weatherSource':'기상청 단기예보 조회서비스','regions':[{'region':'대구광역시','tempMin':16,'tempMax':28,'humidityMax':95,'rainProbabilityMax':0,'riskFactors':['큰 일교차','고습'],'farmChecks':['야간 최소환기 확인','결로 확인']}]})),200)));
    final guide=await repository.refresh();
    expect(guide.diurnalRange,12);expect(guide.checks.length,2);
    final risks=repository.risks(guide);
    expect(risks.map((x)=>x.title),containsAll(['호흡기 질환군 관찰','설사성 질환군 관찰']));
    expect(WeatherFarmRepository.medicines.first.caution,contains('수의사'));
    final seasonal=repository.seasonalDiseases(DateTime(2026,9,20),guide);
    expect(seasonal.map((x)=>x.name).join(' '),contains('PRRS'));
    expect(seasonal.first.differentiate,contains('검사'));
  });
}
