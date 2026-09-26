import 'package:dondonhae/models/disease_models.dart';
import 'package:dondonhae/services/disease_notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

DiseaseFeed feed(List<DiseaseAlert> items)=>DiseaseFeed(items:items,updatedAt:'2026-09-26',fromCache:false);
DiseaseAlert item(String id,{DiseaseEvidence evidence=DiseaseEvidence.official})=>DiseaseAlert(id:id,type:DiseaseType.fmd,source:'공식',countryCode:'KR',evidence:evidence,status:'발생',summary:'충남 천안 발생',sourceUrl:'',occurrenceDate:DateTime.now().toIso8601String(),province:'충청남도',cityCounty:'천안시 동남구',latitude:36.8,longitude:127.1);

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('최초 동기화는 기존 Event 기준선만 저장하고 알림 0건',()async{
    expect(await DiseaseNotificationCoordinator.process(feed([item('old-1'),item('old-2')])),0);
    final p=await SharedPreferences.getInstance();
    expect(p.getBool('disease_notification_baseline_v1'),isTrue);
    expect(p.getStringList('notified_disease_event_ids_v1'),containsAll(['old-1','old-2']));
  });
  test('공개정보는 알림 대상이 아니며 반복 동기화해도 0건',()async{
    final public=feed([item('public-1',evidence:DiseaseEvidence.publicInfo)]);
    expect(await DiseaseNotificationCoordinator.process(public),0);
    expect(await DiseaseNotificationCoordinator.process(public),0);
  });
}
