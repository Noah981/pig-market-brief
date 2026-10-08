import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> handleBackgroundPush(RemoteMessage message)async{
  await Firebase.initializeApp();
  // Notification payloads are displayed by Android while the app is closed.
  // Do not show a second local notification from this handler.
  final prefs=await SharedPreferences.getInstance();
  await prefs.setString('last_server_push_received_at',DateTime.now().toIso8601String());
}

class PushNotificationService {
  static bool _ready=false;
  static Future<bool> initialize()async{
    final prefs=await SharedPreferences.getInstance();
    try{
      if(!_ready){
        await Firebase.initializeApp();
        FirebaseMessaging.onBackgroundMessage(handleBackgroundPush);
        FirebaseMessaging.onMessage.listen(_foreground);
        FirebaseMessaging.onMessageOpenedApp.listen(_opened);
        final initial=await FirebaseMessaging.instance.getInitialMessage();
        if(initial!=null)_opened(initial);
        FirebaseMessaging.instance.onTokenRefresh.listen((_)async{await syncSubscriptions();});
        _ready=true;
      }
      await syncSubscriptions();
      await prefs.setString('server_push_state','connected');
      return true;
    }catch(error){
      await prefs.setBool('server_push_active_v1',false);
      await prefs.setString('server_push_state','connection_required');
      await prefs.setString('server_push_error_type',error.runtimeType.toString());
      return false;
    }
  }

  static Future<void> syncSubscriptions()async{
    if(!_ready)return;
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    final desired=<String,bool>{
      'dondonhae_market_v1':prefs.getBool('market_notifications_enabled')??true,
      for(final entry in const {'fmd':0,'asf':1,'ped':2,'prrs':3}.entries)
        'dondonhae_confirmed_${entry.key}_v1':(prefs.getBool('disease_notifications_enabled')??true)&&
          (prefs.getBool('disease_type_${entry.value}')??true),
    };
    for(final entry in desired.entries){
      if(entry.value){await FirebaseMessaging.instance.subscribeToTopic(entry.key);}
      else{await FirebaseMessaging.instance.unsubscribeFromTopic(entry.key);}
    }
    await prefs.setBool('server_push_active_v1',true);
  }

  static Future<void> _foreground(RemoteMessage message)async{
    final data=message.data;
    final kind=data['kind']?.toString(),id=data['eventId']?.toString();
    if(id==null||(kind!='market'&&kind!='disease'))return;
    if(kind=='disease'&&(data['countryCode']!='KR'||data['confirmed']!='true'))return;
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    final seen=(prefs.getStringList('foreground_server_push_ids_v1')??const <String>[]).toSet();
    if(seen.contains(id))return;
    await NotificationService.instance.showServerPush(id:id,
      title:message.notification?.title??'돈돈해 정보 갱신',
      body:message.notification?.body??'',kind:kind!,payload:data['stableKey']?.toString());
    seen.add(id);
    await prefs.setStringList('foreground_server_push_ids_v1',seen.toList().reversed.take(1000).toList());
  }
  static void _opened(RemoteMessage message){
    if(message.data['kind']=='disease'){
      NotificationService.instance.selectedDiseaseEvent.value=message.data['stableKey']?.toString();
    }
  }
}
