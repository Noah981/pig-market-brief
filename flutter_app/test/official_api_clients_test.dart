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
    final client=KapeApiClient(apiKey:'test',client:MockClient((request)async=>http.Response.bytes(
      utf8.encode(_dabomHtml()),200,headers:{'content-type':'text/html; charset=utf-8'},
    )));
    final rows=await client.gradePricesFor('20260926');
    expect(rows.map((x)=>x.grade),['1+','1','2','등외']);
    expect(rows.first.price,5977);expect(rows.last.price,3269);expect(rows.last.date,'20260923');
    expect(rows.first.count,57);
  });

  test('KAPE 다봄 경락현황은 암·거세 두수와 도체중을 분리한다',()async{
    final client=KapeApiClient(apiKey:'test',client:MockClient((request)async{
      final sex=request.url.queryParameters['searchCondition2']??'';
      final count=sex=='1'?520:sex=='3'?344:883;
      final weight=sex=='1'?'108.4':sex=='3'?'64.9':'91.3';
      return http.Response.bytes(
        utf8.encode(_dabomHtml(total:count,weight:weight)),
        200,
        headers: const {'content-type': 'text/html; charset=utf-8'},
      );
    }));
    final status=await client.auctionStatusFor('20260926');
    expect(status.date,'20260923');expect(status.totalCount,883);expect(status.femaleCount,520);expect(status.castratedCount,344);expect(status.averageCarcassWeight,91.3);
  });

  test('다봄 요청은 전국 제주제외·탕박 필터를 강제한다',()async{
    late Uri requested;
    final client=KapeApiClient(apiKey:'',client:MockClient((request)async{requested=request.url;return http.Response.bytes(utf8.encode(_dabomHtml()),200);}));
    await client.gradePricesFor('20260923');
    expect(requested.queryParameters['searchCondition'],'057016');
    expect(requested.queryParameters['searchCondition1'],'Y');
    expect(requested.queryParameters['searchCondition2'],'');
  });

  test('다봄 성별 등급 가격을 대표 가격과 섞지 않는다',()async{
    final client=KapeApiClient(apiKey:'test',client:MockClient((request)async{
      final sex=request.url.queryParameters['searchCondition2'];
      final body=_dabomHtml().replaceAll('5,977',sex=='1'?'6,200':sex=='3'?'5,900':'5,977');
      return http.Response.bytes(utf8.encode(body),200);
    }));
    final result=await client.latestDabom(endYmd:'20260923');
    expect(result.grades.first.price,5977);
    expect(result.sexGrades.firstWhere((x)=>x.sex=='female'&&x.grade=='1+').price,6200);
    expect(result.sexGrades.firstWhere((x)=>x.sex=='castrated'&&x.grade=='1+').price,5900);
    expect(result.sexGrades.every((x)=>x.date==result.date),isTrue);
  });

  test('KMA 오늘 예보만 파싱하고 다음 날의 수치를 섞지 않는다', () async {
    final today=DateTime.now().toUtc().add(const Duration(hours:9));
    String ymd(DateTime d)=>'${d.year}${d.month.toString().padLeft(2,'0')}${d.day.toString().padLeft(2,'0')}';
    final body = {'response': {'header': {'resultCode': '00'}, 'body': {'items': {'item': [
      {'category':'TMP','fcstValue':'18','fcstDate':ymd(today)}, {'category':'TMP','fcstValue':'27','fcstDate':ymd(today)}, {'category':'TMP','fcstValue':'99','fcstDate':ymd(today.add(const Duration(days:1)))},
      {'category':'REH','fcstValue':'85','fcstDate':ymd(today)}, {'category':'POP','fcstValue':'40','fcstDate':ymd(today)}
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

String _dabomHtml({int total=883,String weight='91.3'})=>'''<!doctype html><html><body>
<form id="searchForm"><input name="searchStartDate" value="2026-09-23"></form>
<table id="table-type1"><tbody>
<tr><th>구 분</th><th>등 급</th><th>경락두수</th><th>평균가격</th><th>평균 도체중</th></tr>
<tr><td rowspan="4">등급</td><td>1+</td><td>57</td><td>5,977</td><td>86.1</td></tr>
<tr><td>1</td><td>81</td><td>5,737</td><td>85</td></tr>
<tr><td>2</td><td>286</td><td>5,009</td><td>73.2</td></tr>
<tr><td>등외</td><td>459</td><td>3,269</td><td>104.3</td></tr>
<tr><td>등외제외</td><td>424</td><td>5,307</td><td>77.2</td></tr>
<tr><td>모돈</td><td>191</td><td>3,276</td><td>172.6</td></tr>
<tr><td>평균</td><td>$total</td><td>4,097</td><td>$weight</td></tr>
</tbody></table></body></html>''';
