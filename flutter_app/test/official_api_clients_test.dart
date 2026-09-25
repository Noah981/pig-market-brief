import 'dart:convert';
import 'package:dondonhae/services/api/ecos_api_client.dart';
import 'package:dondonhae/services/api/kape_api_client.dart';
import 'package:dondonhae/services/api/kma_api_client.dart';
import 'package:dondonhae/services/api/mafra_api_client.dart';
import 'package:dondonhae/services/api/kamis_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('ECOS 원달러 시계열을 파싱한다', () async {
    final client = EcosApiClient(apiKey: 'test', client: MockClient((_) async => http.Response(jsonEncode({'StatisticSearch': {'row': [
      {'TIME': '20260918', 'DATA_VALUE': '1,340.5'}, {'TIME': '20260919', 'DATA_VALUE': '1342.1'}
    ]}}), 200)));
    final result = await client.usdKrw();
    expect(result.last.value, 1342.1);
  });

  test('KAPE 암·거세 거래두수 가중평균을 계산한다', () async {
    final client = KapeApiClient(apiKey: 'test', client: MockClient((_) async => http.Response('<response><header><resultCode>00</resultCode></header><body><items><item><c_1101eTotAmt>6000</c_1101eTotAmt><c_1101eTotCnt>10</c_1101eTotCnt></item></items></body></response>', 200)));
    final result = await client.priceFor('20260918');
    expect(result?.price, 6000); expect(result?.count, 20);
  });

  test('KMA 예보 필수 항목을 파싱한다', () async {
    final body = {'response': {'header': {'resultCode': '00'}, 'body': {'items': {'item': [
      {'category': 'TMP', 'fcstValue': '18'}, {'category': 'TMP', 'fcstValue': '27'},
      {'category': 'REH', 'fcstValue': '85'}, {'category': 'POP', 'fcstValue': '40'}
    ]}}}};
    final client = KmaApiClient(apiKey: 'test', client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200)));
    final result = await client.forecast(35.87, 128.60);
    expect(result.tempMin, 18); expect(result.tempMax, 27); expect(result.humidityMax, 85);
  });

  test('MAFRA 공식 Grid 행을 파싱한다', () async {
    final body = {'Grid_20151204000000000316_1': {'totalCnt': 1, 'RESULT': {'CODE': 'INFO-000'}, 'row': [{'LKNTS_NM': '아프리카돼지열병'}]}};
    final client = MafraApiClient(apiKey: 'test', client: MockClient((_) async => http.Response.bytes(utf8.encode(jsonEncode(body)), 200)));
    final result = await client.fetch();
    expect(result.single.pick(['LKNTS_NM']), '아프리카돼지열병');
  });

  test('KAMIS 공식 응답을 저장 가능한 형태로 파싱한다',()async{
    SharedPreferences.setMockInitialValues({});
    final body={'error_code':'000','data':[{'regday':'2026-09-25','item_name':'쌀'}]};
    final client=KamisApiClient(apiKey:'test',certId:'tester',client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(body)),200)));
    final result=await client.fetchLatest();
    expect((result['data'] as List).single['regday'],'2026-09-25');
  });
}
