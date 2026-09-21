import 'dart:convert';
import 'package:dondonhae/data/disease_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import 'dart:io';

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
    expect(feed.items.first.region,'예천군');
    expect(feed.items.first.hasMapPoint,isTrue);
  });
  testWidgets('실제 대한민국 GeoJSON에 제주 울릉도 독도 좌표가 포함된다',(tester)async{
    final bytes=await rootBundle.load('assets/data/korea_provinces.geojson.gz');
    final raw=utf8.decode(gzip.decode(bytes.buffer.asUint8List()));
    final root=jsonDecode(raw) as Map<String,dynamic>;
    final features=(root['features'] as List).cast<Map<String,dynamic>>();
    expect(features.length,17);
    final names=features.map((x)=>(x['properties'] as Map)['name']).toSet();
    expect(names,containsAll(['서울특별시','부산광역시','대구광역시','제주특별자치도','경상북도']));
    final text=raw;
    expect(text,contains('130.9'));
    expect(text,contains('131.8'));
  });
}
