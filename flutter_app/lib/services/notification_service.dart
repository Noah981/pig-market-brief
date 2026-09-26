import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../models/disease_models.dart';
import 'disease_risk_engine.dart';

class NotificationService{
 NotificationService._();static final instance=NotificationService._();final _plugin=FlutterLocalNotificationsPlugin();bool _ready=false;
 final ValueNotifier<String?> selectedDiseaseEvent=ValueNotifier(null);
 Future<void> initialize()async{if(_ready)return;const android=AndroidInitializationSettings('@mipmap/ic_launcher');const ios=DarwinInitializationSettings();await _plugin.initialize(const InitializationSettings(android:android,iOS:ios),onDidReceiveNotificationResponse:(r)=>selectedDiseaseEvent.value=r.payload);final launch=await _plugin.getNotificationAppLaunchDetails();if(launch?.didNotificationLaunchApp??false)selectedDiseaseEvent.value=launch?.notificationResponse?.payload;await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);_ready=true;}
 Future<void> newBenefit(String region,String title)async{await initialize();await _plugin.show(title.hashCode,'$region 신규 지원사업',title,const NotificationDetails(android:AndroidNotificationDetails('benefits','지원사업',channelDescription:'내 지역 신규 지원사업과 마감 알림',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));}
 Future<void> newDiseaseEvent(DiseaseAlert event,double km)async{await initialize();final level=DiseaseRiskEngine.levelFor(km),label=switch(level){DiseaseRiskLevel.level1=>'긴급',DiseaseRiskLevel.level2=>'주의',_=>'관심'};await _plugin.show(event.stableKey.hashCode,'[$label] ${event.disease} 신규 발생','${event.region} · 내 기준 위치에서 약 ${km<10?km.toStringAsFixed(1):km.round()}km',const NotificationDetails(android:AndroidNotificationDetails('disease_official','질병 공식 발생',channelDescription:'50km 이내 공식 가축질병 신규 발생',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),payload:event.stableKey);}
}
