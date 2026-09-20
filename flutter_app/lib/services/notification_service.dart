import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService{
 NotificationService._();static final instance=NotificationService._();final _plugin=FlutterLocalNotificationsPlugin();bool _ready=false;
 Future<void> initialize()async{if(_ready)return;const android=AndroidInitializationSettings('@mipmap/ic_launcher');const ios=DarwinInitializationSettings();await _plugin.initialize(const InitializationSettings(android:android,iOS:ios));await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);_ready=true;}
 Future<void> newBenefit(String region,String title)async{await initialize();await _plugin.show(title.hashCode,'$region 신규 지원사업',title,const NotificationDetails(android:AndroidNotificationDetails('benefits','지원사업',channelDescription:'내 지역 신규 지원사업과 마감 알림',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));}
}
