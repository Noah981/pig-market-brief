import 'package:shared_preferences/shared_preferences.dart';
import '../models/disease_models.dart';
import '../settings/farm_location_settings.dart';
import 'disease_risk_engine.dart';
import 'notification_service.dart';

class DiseaseNotificationCoordinator {
  static const _baseline='disease_notification_baseline_v1',_notified='notified_disease_event_ids_v1',_evidence='disease_event_evidence_v1',_status='disease_incident_status_v2';
  static Future<int> process(DiseaseFeed feed)async{
    final prefs=await SharedPreferences.getInstance(),now=DateTime.now(),recent=feed.items.where((x)=>x.countryCode=='KR'&&x.isRecentAt(now)).toList(),active=recent.where((x)=>!x.isNegative).toList();
    final ids=active.map((x)=>x.stableKey).toSet(),previousEvidence=_decodeMap(prefs.getString(_evidence));
    final previousStatus=_decodeMap(prefs.getString(_status));
    if(!(prefs.getBool(_baseline)??false)){
      await prefs.setStringList(_notified,ids.toList());await prefs.setString(_evidence,_encodeMap(active));await prefs.setString(_status,_encodeStatus(recent));await prefs.setBool(_baseline,true);return 0;
    }
    final notified=(prefs.getStringList(_notified)??const <String>[]).toSet(),location=FarmLocationSettings.instance.location;
    var count=0;
    for(final event in recent){
      final old=previousStatus[event.incidentKey],current=_phase(event);
      if(old==null&&current=='suspected'){await NotificationService.instance.diseaseStatusUpdate(event,phase:current);count++;}
      else if(old=='suspected'&&(current=='confirmed'||current=='negative')){await NotificationService.instance.diseaseStatusUpdate(event,phase:current);count++;}
    }
    if(location.gpsVerified){
      for(final event in active.where((x)=>x.isOfficial&&x.latitude!=null&&x.longitude!=null)){
        final promoted=previousEvidence[event.stableKey]=='publicInfo';
        if((notified.contains(event.stableKey)&&!promoted))continue;
        final km=DiseaseRiskEngine.distanceKm(location.latitude,location.longitude,event.latitude!,event.longitude!);
        if(km<=50){await NotificationService.instance.newDiseaseEvent(event,km);count++;}
        notified.add(event.stableKey);
      }
    }
    await prefs.setStringList(_notified,notified.toList());await prefs.setString(_evidence,_encodeMap(active));await prefs.setString(_status,_encodeStatus(recent));return count;
  }
  static Map<String,String> _decodeMap(String? raw){if(raw==null||raw.isEmpty)return {};return {for(final item in raw.split('\n'))if(item.contains('\t'))item.split('\t').first:item.split('\t').last};}
  static String _encodeMap(Iterable<DiseaseAlert> events)=>events.map((x)=>'${x.stableKey}\t${x.evidence.name}').join('\n');
  static String _encodeStatus(Iterable<DiseaseAlert> events)=>events.map((x)=>'${x.incidentKey}\t${_phase(x)}').join('\n');
  static String _phase(DiseaseAlert event)=>event.isNegative?'negative':event.isSuspected?'suspected':event.isConfirmed?'confirmed':'publicInfo';
}
