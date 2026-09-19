import 'dart:convert';

import 'package:dondonhae/data/commodity_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

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
  });
}
