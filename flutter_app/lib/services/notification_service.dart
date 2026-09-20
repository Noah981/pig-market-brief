import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService{
 NotificationService._();static final instance=NotificationService._();final _plugin=FlutterLocalNotificationsPlugin();bool _ready=false;
 Future<void> initialize()async{if(_ready)return;const android=AndroidInitializationSettings('@mipmap/ic_launcher');const ios=DarwinInitializationSettings();await _plugin.initialize(const InitializationSettings(android:android,iOS:ios));await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);_ready=true;}
 Future<void> newBenefit(String region,String title)async{await initialize();await _plugin.show(title.hashCode,'$region 신규 지원사업',title,const NotificationDetails(android:AndroidNotificationDetails('benefits','지원사업',channelDescription:'내 지역 신규 지원사업과 마감 알림',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));}
 Future<void> newDisease(String disease,String region)async{await initialize();await _plugin.show('$disease|$region'.hashCode,'국내 신규 질병정보','$region에서 $disease 공식 정보가 확인됐습니다. 원문과 방역지침을 확인하세요.',const NotificationDetails(android:AndroidNotificationDetails('disease','질병 알림',channelDescription:'국내 신규 질병과 내 지역 주변 공식 정보',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));}
}
