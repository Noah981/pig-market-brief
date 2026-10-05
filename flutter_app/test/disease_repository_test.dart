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
  test('해외 공식 통보는 실제 발생일을 만들지 않고 표시하고 국내 경보에서 제외한다',()async{
    final payload={'items':[{'id':'WOAH-SS','disease':'ASF','countryCode':'SS','evidenceLevel':'OFFICIAL','source':'WOAH','sourceUrl':'https://rr-africa.woah.org/en/immediate-notifications-in-africa/','summary':'South Sudan ASF 공식 통보','dateBasis':'notification','announcementDate':'2026-09-18','occurrenceDate':''}]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)));
    final alert=(await repo.refresh()).items.single;
    expect(alert.occurrenceDate,isEmpty);expect(alert.displayDate,'2026-09-18');expect(alert.dateLabel,'공식 통보일');
    expect(alert.displayMoment,DateTime(2026,9,18));expect(alert.isActiveAt(DateTime(2026,10,3)),isFalse);expect(alert.hasMapPoint,isFalse);
  });
  test('PED 공식 통계는 개별 발생을 만들지 않고 캐시에도 보존한다',()async{
    final payload={'coverageVerified':true,'statistics':{'ped':{'source':'KAHIS','periods':{'365':{'farmCount':56,'animalCount':4198}}}},'items':[]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)));
    final feed=await repo.refresh();expect(feed.items,isEmpty);expect(feed.statistics['ped']['periods']['365']['farmCount'],56);
    expect((await repo.cached()).statistics['ped']['periods']['365']['animalCount'],4198);
  });
  test('과거의 검증 완료 피드도 최신 경보 없음으로 사용하지 않는다',()async{
    final payload={'coverageVerified':true,'updatedAt':'2026-10-04T00:00:00+09:00','items':[]};
    final repo=DiseaseRepository(clock:()=>DateTime.utc(2026,10,5),client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)));
    final feed=await repo.refresh(checkOfficial:false);expect(feed.state,DiseaseDataState.stale);expect(feed.coverageVerified,isFalse);
  });
  test('종식된 공식 발생은 내역을 유지하되 현재 경보에서 제외한다',()async{
    final payload={'items':[{'id':'closed-case','disease':'PRRS','countryCode':'KR','evidenceLevel':'OFFICIAL','status':'종식','summary':'공식 과거 내역','occurrenceDate':'2026-10-01'}]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)));
    final alert=(await repo.refresh()).items.single;
    expect(alert.isClosed,isTrue);expect(alert.isActiveAt(DateTime(2026,10,3)),isFalse);expect(alert.occurrenceDate,'2026-10-01');
  });
  test('조회 범위가 검증되지 않은 빈 피드를 발생 없음으로 확정하지 않는다',()async{
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response('{"items":[],"updatedAt":"2026-10-03"}',200)));
    final feed=await repo.refresh();
    expect(feed.state,DiseaseDataState.reviewRequired);
    expect(feed.errorMessage,contains('발생 없음으로 판단하지'));
  });
  test('같은 시군의 서로 다른 발생 ID를 합치지 않는다',(){
    const first=DiseaseAlert(id:'farm-a',type:DiseaseType.asf,source:'공식',countryCode:'KR',evidence:DiseaseEvidence.official,status:'발생',summary:'첫 농장',sourceUrl:'',occurrenceDate:'2026-10-01',province:'경상북도',cityCounty:'김천시');
    const second=DiseaseAlert(id:'farm-b',type:DiseaseType.asf,source:'공식',countryCode:'KR',evidence:DiseaseEvidence.official,status:'발생',summary:'둘째 농장',sourceUrl:'',occurrenceDate:'2026-10-01',province:'경상북도',cityCounty:'김천시');
    expect(first.incidentKey,isNot(second.incidentKey));
  });
  test('김천 공식 발생은 1년 이력에 남고 현재 30일 경보에서는 제외된다',()async{
    final root={'coverageVerified':true,'items':[{'id':'MAFRA-ASF-TABLE|2026|13','disease':'ASF','countryCode':'KR','evidenceLevel':'OFFICIAL','source':'농림축산식품부 ASF 발생현황 정보공개','sourceUrl':'https://mafra.go.kr/bbs/FMD-AI2/404/577369/artclView.do','region':'경상북도 김천시 구성면','summary':'경상북도 김천시 구성면 ASF','occurrenceDate':'2026-02-12','announcementDate':'2026-03-20'}]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(root)),200)),clock:()=>DateTime(2026,10,4));
    final feed=await repo.refresh();
    final kimcheon=feed.items.singleWhere((x)=>x.type==DiseaseType.asf&&x.cityCounty=='김천시');
    expect(kimcheon.occurrenceDate,'2026-02-12');expect(kimcheon.region,contains('구성면'));
    expect(kimcheon.isActiveAt(DateTime(2026,10,4)),isFalse);
    expect(feed.items.length,1);
  });
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
  test('방역반경 밖이거나 좌표가 없어도 최근 30일이면 활성 목록에 포함',(){
    final now=DateTime(2026,9,27);
    final far=event(DiseaseType.asf,180,date:now.subtract(const Duration(days:4)));
    const noPoint=DiseaseAlert(type:DiseaseType.ped,source:'공개뉴스',countryCode:'KR',evidence:DiseaseEvidence.publicInfo,status:'공개정보 · 확인 중',summary:'충청남도 PED 발생 정보',sourceUrl:'',occurrenceDate:'2026-09-20');
    expect([far,noPoint].where((x)=>x.isActiveAt(now)).length,2);
  });
  test('최근 게시됐어도 제목의 2월 발생 정보는 최근 30일에서 제외',(){
    const alert=DiseaseAlert(type:DiseaseType.asf,source:'공개뉴스',countryCode:'KR',evidence:DiseaseEvidence.publicInfo,status:'공개정보 · 확인 중',summary:'지난 2월 발생한 양평 ASF 사례 재조명',sourceUrl:'',occurrenceDate:'2026-09-27');
    expect(alert.eventDate,DateTime(2026,2,1));
    expect(alert.isActiveAt(DateTime(2026,9,27)),isFalse);
  });
  test('공개뉴스 RFC 2822 발표일도 최근 발생일로 판정한다',(){
    const alert=DiseaseAlert(type:DiseaseType.asf,source:'공개뉴스',countryCode:'KR',evidence:DiseaseEvidence.publicInfo,status:'의심 · 정밀검사 중',summary:'양평군 ASF 의심 신고',sourceUrl:'',occurrenceDate:'Sun, 27 Sep 2026 03:20:00 GMT');
    expect(alert.isRecentAt(DateTime(2026,9,27)),isTrue);
  });
  test('의심은 공개정보로 표시하고 음성 전환 시 활성 목록에서 제거한다',()async{
    final payload={'updatedAt':'2026-09-27','items':[
      {'disease':'ASF','source':'공개뉴스','countryCode':'KR','evidenceLevel':'PUBLIC_UNCONFIRMED','status':'의심 · 정밀검사 중','summary':'경기 양평군 ASF 의심 신고','sourceUrl':'','occurrenceDate':'2026-09-27','publishedAt':'2026-09-27','region':'양평군','latitude':37.491,'longitude':127.488}
    ]};
    final repo=DiseaseRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(jsonEncode(payload)),200)),clock:()=>DateTime(2026,9,27));
    final suspected=(await repo.refresh()).items.single;
    expect(suspected.isSuspected,isTrue);expect(suspected.isActiveAt(DateTime(2026,9,27)),isTrue);
    final negative=DiseaseAlert(id:suspected.id,type:suspected.type,source:suspected.source,countryCode:'KR',evidence:DiseaseEvidence.publicInfo,status:'음성 · 의심 해제',summary:suspected.summary,sourceUrl:'',occurrenceDate:'2026-09-27',cityCounty:'양평군');
    expect(negative.isNegative,isTrue);expect(negative.isActiveAt(DateTime(2026,9,27)),isFalse);
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
