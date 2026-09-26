import 'dart:convert';
import 'dart:io';
import 'package:dondonhae/data/disease_repository.dart';
import 'package:dondonhae/models/disease_models.dart';
import 'package:dondonhae/services/disease_risk_engine.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiseaseAlert event(DiseaseType type,double km,{bool official=true,DateTime? date})=>DiseaseAlert(id:'${type.name}-$km',type:type,source:'공식',countryCode:'KR',evidence:official?DiseaseEvidence.official:DiseaseEvidence.publicInfo,status:'발생',summary:'테스트',sourceUrl:'',occurrenceDate:(date??DateTime(2026,9,26)).toIso8601String(),latitude:36.8+km/111,longitude:127.1);

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('질병명 정규화와 국내외 분리',()async{
    final payload={'updatedAt':'2026-09-26','items':[
      {'id':'1','disease':'Foot-and-Mouth Disease','source':'공식기관','countryCode':'KR','evidenceLevel':'OFFICIAL','level':'발생','summary':'충청남도 천안시 동남구 구제역','sourceUrl':'','occurrenceDate':'2026-09-18','latitude':36.8,'longitude':127.1},
      {'id':'2','disease':'African Swine Fever','source':'공식기관','countryCode':'VN','evidenceLevel':'PUBLIC_INFO','level':'공개정보','summary':'베트남 ASF','sourceUrl':'','occurrenceDate':'2026-09-18'}]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)),clock:()=>DateTime(2026,9,26));
    final feed=await repo.refresh();
    expect(feed.items.first.type,DiseaseType.fmd);expect(feed.items.first.cityCounty,'천안시 동남구');
    expect(feed.items.where((x)=>x.countryCode=='KR').length,1);expect(feed.items.where((x)=>x.countryCode!='KR').length,1);
  });
  test('30일 경계는 포함하고 31일은 제외',(){
    final now=DateTime(2026,9,26);
    expect(event(DiseaseType.asf,8,date:now.subtract(const Duration(days:29))).isActiveAt(now),isTrue);
    expect(event(DiseaseType.asf,8,date:now.subtract(const Duration(days:30))).isActiveAt(now),isTrue);
    expect(event(DiseaseType.asf,8,date:now.subtract(const Duration(days:31))).isActiveAt(now),isFalse);
  });
  test('질병별 거리 LEVEL과 누적 건수는 독립',(){
    final events=[event(DiseaseType.asf,8),event(DiseaseType.asf,22),event(DiseaseType.asf,43),event(DiseaseType.fmd,70)];
    final asf=DiseaseRiskEngine.summarize(events,latitude:36.8,longitude:127.1,type:DiseaseType.asf);
    expect(asf.level,DiseaseRiskLevel.level1);expect((asf.count10,asf.count30,asf.count50),(1,2,3));
    final fmd=DiseaseRiskEngine.summarize(events,latitude:36.8,longitude:127.1,type:DiseaseType.fmd);
    expect(fmd.level,DiseaseRiskLevel.safe);expect(fmd.count50,0);
  });
  test('공개정보는 LEVEL 계산에서 제외되고 GPS 없으면 unknown',(){
    final public=event(DiseaseType.ped,8,official:false);
    expect(DiseaseRiskEngine.summarize([public],latitude:36.8,longitude:127.1).level,DiseaseRiskLevel.safe);
    expect(DiseaseRiskEngine.summarize([public],latitude:null,longitude:null).level,DiseaseRiskLevel.unknown);
  });
  testWidgets('실제 대한민국 GeoJSON에 제주 울릉도 독도 좌표가 포함된다',(tester)async{
    final bytes=await rootBundle.load('assets/data/korea_provinces.geojson.gz'),raw=utf8.decode(gzip.decode(bytes.buffer.asUint8List())),root=jsonDecode(raw) as Map<String,dynamic>;
    final features=(root['features'] as List).cast<Map<String,dynamic>>(),names=features.map((x)=>(x['properties'] as Map)['name']).toSet();
    expect(features.length,17);expect(names,containsAll(['서울특별시','부산광역시','대구광역시','제주특별자치도','경상북도']));expect(raw,contains('130.9'));expect(raw,contains('131.8'));
  });
}
