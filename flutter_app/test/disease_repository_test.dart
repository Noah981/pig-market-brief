import 'dart:convert';
import 'package:dondonhae/data/disease_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('국내와 해외를 국가코드로 분리하고 지도 지역을 추출한다',()async{
    final payload={'updatedAt':'2026-09-19','items':[
      {'disease':'구제역','source':'공식기관','countryCode':'KR','evidenceLevel':'OFFICIAL','level':'공식 발생 확인','summary':'경북 예천 구제역 발생','sourceUrl':'https://example.org/kr','publishedAt':'2026-09-18'},
      {'disease':'ASF','source':'공식기관','countryCode':'VN','evidenceLevel':'OFFICIAL','level':'공식 발생 확인','summary':'베트남 ASF 발생','sourceUrl':'https://example.org/vn','publishedAt':'2026-09-18'}]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)));
    final feed=await repo.refresh();
    expect(feed.items.where((x)=>x.scope=='국내').length,1);
    expect(feed.items.where((x)=>x.scope=='국외').length,1);
    expect(feed.items.first.region,'예천');
    expect(feed.items.first.hasMapPoint,isTrue);
  });
}
