import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';
import '../settings/farm_location_settings.dart';
import 'disease_risk_engine.dart';
import 'notification_service.dart';

class DiseaseNotificationCoordinator {
  static const _baseline='disease_notification_baseline_v1',_notified='notified_disease_event_ids_v1',_evidence='disease_event_evidence_v1';
  static Future<int> process(DiseaseFeed feed)async{
    final prefs=await SharedPreferences.getInstance(),active=feed.active(DateTime.now()).where((x)=>x.countryCode=='KR').toList();
    final ids=active.map((x)=>x.stableKey).toSet(),previousEvidence=_decodeMap(prefs.getString(_evidence));
    if(!(prefs.getBool(_baseline)??false)){
      await prefs.setStringList(_notified,ids.toList());await prefs.setString(_evidence,_encodeMap(active));await prefs.setBool(_baseline,true);return 0;
    }
    final notified=(prefs.getStringList(_notified)??const <String>[]).toSet(),location=FarmLocationSettings.instance.location;
    var count=0;
    if(location.gpsVerified){
      for(final event in active.where((x)=>x.isOfficial&&x.latitude!=null&&x.longitude!=null)){
        final promoted=previousEvidence[event.stableKey]=='publicInfo';
        if((notified.contains(event.stableKey)&&!promoted))continue;
        final km=DiseaseRiskEngine.distanceKm(location.latitude,location.longitude,event.latitude!,event.longitude!);
        if(km<=50){await NotificationService.instance.newDiseaseEvent(event,km);count++;}
        notified.add(event.stableKey);
      }
    }
    await prefs.setStringList(_notified,notified.toList());await prefs.setString(_evidence,_encodeMap(active));return count;
  }
  static Map<String,String> _decodeMap(String? raw){if(raw==null||raw.isEmpty)return {};return {for(final item in raw.split('\n'))if(item.contains('\t'))item.split('\t').first:item.split('\t').last};}
  static String _encodeMap(Iterable<DiseaseAlert> events)=>events.map((x)=>'${x.stableKey}\t${x.evidence.name}').join('\n');
}
