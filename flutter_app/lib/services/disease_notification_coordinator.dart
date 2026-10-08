import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';
import 'notification_service.dart';

class DiseaseNotificationCoordinator {
  static const _baseline='nationwide_confirmed_baseline_v2';
  static const _notified='nationwide_confirmed_notified_v2';
  static Future<int> process(DiseaseFeed feed,{
    Future<void> Function(DiseaseAlert)? notify,
  })async{
    if(feed.fromCache||feed.state!=DiseaseDataState.live||!feed.coverageVerified)return 0;
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    final now=DateTime.now();
    final active=feed.items.where((x)=>x.countryCode=='KR'&&x.isOfficial&&
      x.isConfirmed&&!x.isClosed&&x.isRecentAt(now)&&
      (x.status.contains('발생')||x.status.contains('확진')||x.status.contains('양성'))).toList();
    final keys=active.map((x)=>x.incidentKey).toSet();
    if(!(prefs.getBool(_baseline)??false)){
      await prefs.setStringList(_notified,keys.toList());
      await prefs.setBool(_baseline,true);
      return 0;
    }
    final seen=(prefs.getStringList(_notified)??const <String>[]).toSet();
    final push=prefs.getBool('server_push_active_v1')??false;
    final enabled=prefs.getBool('disease_notifications_enabled')??true;
    var count=0;
    for(final event in active){
      if(seen.contains(event.incidentKey))continue;
      final allowed=enabled&&(prefs.getBool('disease_type_${_typeIndex(event.type)}')??true);
      if(allowed&&!push){
        await (notify??NotificationService.instance.newNationwideDiseaseEvent)(event);
        count++;
      }
      seen.add(event.incidentKey);
      // Commit each delivered event before continuing; a later failure does not replay it.
      await prefs.setStringList(_notified,seen.toList());
    }
    return count;
  }
  static int _typeIndex(DiseaseType type)=>switch(type){DiseaseType.fmd=>0,DiseaseType.asf=>1,DiseaseType.ped=>2,DiseaseType.prrs=>3};
}
