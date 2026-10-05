import 'dart:convert';

import 'package:dondonhae/data/commodity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('공식 원자료의 가격과 추세를 FRED 대체 자료로 덮어쓰지 않는다', () async {
    var cornFallbackRequests=0;
    final repository=CommodityRepository(client:MockClient((request) async {
      if(request.url.host=='fred.stlouisfed.org'){
        if(request.url.queryParameters['id']=='PMAIZMTUSDM')cornFallbackRequests++;
        return http.Response('observation_date,PMAIZMTUSDM\n2026-08-01,900\n2026-09-01,950',200);
      }
      return http.Response.bytes(utf8.encode(jsonEncode({'markets':[{
        'name':'corn','value':239.6,'previousValue':224,'changePct':6.96,
        'date':'2026-09-01','previousDate':'2026-08-01','unit':r'$/톤',
        'frequency':'monthly','source':'세계은행 World Bank Pink Sheet','status':'LIVE',
        'history':[{'date':'2026-08-01','value':224},{'date':'2026-09-01','value':239.6}]
      }]})),200);
    }));
    final corn=(await repository.refresh()).first;
    expect(corn.value,'239.60');
    expect(corn.source,contains('World Bank'));
    expect(corn.history.first.value,224);
    expect(cornFallbackRequests,0);
  });

  test('검증된 시황 값·출처·주기·그래프를 보존한다', () async {
    final payload = {
      'markets': [
        {
          'name': 'corn',
          'value': 213.19,
          'unit': r'$/톤',
          'changePct': 8.89,
          'date': '2026-07-01',
          'frequency': 'monthly',
          'basis': '세계 옥수수 벤치마크 월평균',
          'source': '국제통화기금(IMF)·FRED',
          'url': 'https://fred.stlouisfed.org/series/PMAIZMTUSDM',
          'history': [
            {'date': '2026-06-01', 'value': 195.78},
            {'date': '2026-07-01', 'value': 213.19},
          ],
          'analysis':{
            'summary':'공식 시계열과 발표를 교차 확인했습니다.',
            'updatedAt':'2026-09-20T10:00:00+09:00',
            'confidence':'보통',
            'factors':[{'title':'최근 추세','status':'계산','detail':'최근 3개 발표 흐름입니다.','source':'미국 농무부','sourceDate':'2026-09-20','direction':'up'}],
            'sources':[{'name':'미국 농무부(USDA)','label':'공식 발표','url':'https://www.usda.gov/'}],
          },
        }
      ]
    };
    final repository = CommodityRepository(client: MockClient((_) async =>
        http.Response.bytes(utf8.encode(jsonEncode(payload)), 200)));
    final values = await repository.refresh();
    final corn = values.first;
    expect(corn.id, 'corn');
    expect(corn.value, '213.19');
    expect(corn.change, 8.89);
    expect(corn.frequency, 'monthly');
    expect(corn.history.length, 2);
    expect(corn.source, contains('IMF'));
    expect(corn.analysisConfidence,'보통');
    expect(corn.analysisFactors.single.title,'최근 추세');
    expect(corn.analysisSources.single.name,contains('USDA'));
  });
}
