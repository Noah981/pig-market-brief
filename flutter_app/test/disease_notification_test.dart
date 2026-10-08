import 'package:dondonhae/models/disease_models.dart';
import 'package:dondonhae/services/disease_notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiseaseFeed feed(List<DiseaseAlert> items)=>DiseaseFeed(items:items,updatedAt:'2026-09-26',fromCache:false,coverageVerified:true);
DiseaseAlert item(String id,{DiseaseEvidence evidence=DiseaseEvidence.official})=>DiseaseAlert(id:id,type:DiseaseType.fmd,source:'공식',countryCode:'KR',evidence:evidence,status:'발생',summary:'충남 천안 발생',sourceUrl:'',occurrenceDate:DateTime.now().toIso8601String(),province:'충청남도',cityCounty:'천안시 동남구',latitude:36.8,longitude:127.1);

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('최초 동기화는 기존 Event 기준선만 저장하고 알림 0건',()async{
    expect(await DiseaseNotificationCoordinator.process(feed([item('old-1'),item('old-2')])),0);
    final p=await SharedPreferences.getInstance();
    expect(p.getBool('nationwide_confirmed_baseline_v2'),isTrue);
    expect(p.getStringList('nationwide_confirmed_notified_v2'),containsAll(['fmd|KR|old-1','fmd|KR|old-2']));
  });
  test('공개정보는 알림 대상이 아니며 반복 동기화해도 0건',()async{
    final public=feed([item('public-1',evidence:DiseaseEvidence.publicInfo)]);
    expect(await DiseaseNotificationCoordinator.process(public),0);
    expect(await DiseaseNotificationCoordinator.process(public),0);
  });

  test('GPS와 거리 없이 전국 신규 공식 발생만 알리며 같은 발생은 반복하지 않는다',()async{
    final sent=<String>[];
    Future<void> notify(DiseaseAlert x)async{sent.add(x.id);}
    await DiseaseNotificationCoordinator.process(feed([item('old')]),notify:notify);
    expect(await DiseaseNotificationCoordinator.process(feed([item('old'),item('new')]),notify:notify),1);
    expect(await DiseaseNotificationCoordinator.process(feed([item('old'),item('new')]),notify:notify),0);
    expect(sent,['new']);
  });
  test('의심 음성 종식 해외는 제외하고 확진 전환만 알린다',()async{
    final sent=<String>[];
    Future<void> notify(DiseaseAlert x)async{sent.add(x.id);}
    DiseaseAlert status(String id,String value,{String country='KR'})=>DiseaseAlert(id:id,type:DiseaseType.asf,source:'공식',countryCode:country,evidence:DiseaseEvidence.official,status:value,summary:'발생',sourceUrl:'',occurrenceDate:DateTime.now().toIso8601String(),province:'제주특별자치도');
    final excluded=[status('suspect','의심'),status('negative','음성'),status('closed','종식'),status('foreign','공식 발생',country:'VN')];
    await DiseaseNotificationCoordinator.process(feed(excluded),notify:notify);
    expect(await DiseaseNotificationCoordinator.process(feed(excluded),notify:notify),0);
    expect(await DiseaseNotificationCoordinator.process(feed([status('suspect','확진')]),notify:notify),1);
    expect(sent,['suspect']);
  });
  test('서버 푸시 연결 시 주기 갱신의 중복 로컬 알림을 보내지 않는다',()async{
    await DiseaseNotificationCoordinator.process(feed([]));
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('server_push_active_v1',true);
    expect(await DiseaseNotificationCoordinator.process(feed([item('new')]),notify:(_)async{fail('duplicate');}),0);
  });
}
