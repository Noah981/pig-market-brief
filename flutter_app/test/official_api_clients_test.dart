import 'dart:convert';
import 'package:dondonhae/services/api/ecos_api_client.dart';
import 'package:dondonhae/services/api/kape_api_client.dart';
import 'package:dondonhae/services/api/kma_api_client.dart';
import 'package:dondonhae/services/api/mafra_api_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
  test('KAPE 등급별 가격을 대표 돈가와 분리해 파싱한다',()async{
    final xml='<response><header><resultCode>00</resultCode></header><body><items>'
      '<item><gradeNm>1+</gradeNm><avgPrc>5892</avgPrc><totCnt>10</totCnt></item>'
      '<item><gradeNm>1</gradeNm><avgPrc>5614</avgPrc><totCnt>20</totCnt></item>'
      '<item><gradeNm>2</gradeNm><avgPrc>5217</avgPrc><totCnt>30</totCnt></item>'
      '<item><gradeNm>등외</gradeNm><avgPrc>4326</avgPrc><totCnt>5</totCnt></item>'
      '</items></body></response>';
    final client=KapeApiClient(apiKey:'test',client:MockClient((_)async=>http.Response.bytes(
      utf8.encode(xml),200,headers:{'content-type':'application/xml; charset=utf-8'},
    )));
    final rows=await client.gradePricesFor('20260926');
    expect(rows.map((x)=>x.grade),['1+','1','2','등외']);
    expect(rows.first.price,5892);expect(rows.last.price,4326);expect(rows.last.date,'20260926');
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

}
