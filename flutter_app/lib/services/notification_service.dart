import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import '../models/disease_models.dart';
import '../data/market_repository.dart';
import 'disease_risk_engine.dart';

class NotificationService{
 NotificationService._();static final instance=NotificationService._();final _plugin=FlutterLocalNotificationsPlugin();bool _ready=false;
 final ValueNotifier<String?> selectedDiseaseEvent=ValueNotifier(null);
 Future<void> initialize({bool requestPermission=false})async{
  if(!_ready){
   const android=AndroidInitializationSettings('@mipmap/ic_launcher');
   const ios=DarwinInitializationSettings(requestAlertPermission:false,requestBadgePermission:false,requestSoundPermission:false);
   await _plugin.initialize(const InitializationSettings(android:android,iOS:ios),onDidReceiveNotificationResponse:(r)=>selectedDiseaseEvent.value=r.payload);
   _ready=true;
  }
  // A headless worker has no Activity and must never request permissions.
  if(requestPermission){
   final launch=await _plugin.getNotificationAppLaunchDetails();
   if(launch?.didNotificationLaunchApp??false)selectedDiseaseEvent.value=launch?.notificationResponse?.payload;
   await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestNotificationsPermission();
   await _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()?.requestPermissions(alert:true,badge:true,sound:true);
  }
 }
 Future<void> newMarketPrice(MarketSnapshot market)async{
  await initialize();
  final sign=market.change>0?'+':'';
  await _plugin.show(41001,'전국 돈가 갱신 · ${market.price}원/kg',
   '기준일 ${market.date} · 전일 대비 $sign${market.change}원 (${market.changePct.toStringAsFixed(1)}%)',
   const NotificationDetails(android:AndroidNotificationDetails('market_price','돈가 갱신',channelDescription:'공식 대표 돈가의 새 발표 및 정정',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));
 }
 Future<void> newBenefit(String region,String title)async{await initialize();await _plugin.show(title.hashCode,'$region 신규 지원사업',title,const NotificationDetails(android:AndroidNotificationDetails('benefits','지원사업',channelDescription:'내 지역 신규 지원사업과 마감 알림',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()));}
 Future<void> newDiseaseEvent(DiseaseAlert event,double km)async{await initialize();final level=DiseaseRiskEngine.levelFor(km),label=switch(level){DiseaseRiskLevel.level1=>'긴급',DiseaseRiskLevel.level2=>'주의',_=>'관심'};await _plugin.show(event.stableKey.hashCode,'[$label] ${event.disease} 신규 발생','${event.region} · 내 기준 위치에서 약 ${km<10?km.toStringAsFixed(1):km.round()}km',const NotificationDetails(android:AndroidNotificationDetails('disease_official','질병 공식 발생',channelDescription:'50km 이내 공식 가축질병 신규 발생',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),payload:event.stableKey);}
 Future<void> newNationwideDiseaseEvent(DiseaseAlert event)async{
  await initialize();
  await _plugin.show(event.stableKey.hashCode,'[전국 발생] ${event.disease}',
   '${event.region} · ${event.summary}',
   const NotificationDetails(android:AndroidNotificationDetails('disease_nationwide','전국 질병 신규 발생',channelDescription:'전국 공식 가축질병 신규 발생',importance:Importance.max,priority:Priority.high),iOS:DarwinNotificationDetails()),payload:event.stableKey);
 }
 Future<void> diseaseStatusUpdate(DiseaseAlert event,{required String phase})async{await initialize();final (title,body)=switch(phase){'suspected'=>('[확인 중] ${event.disease} 의심 신고','${event.region.isEmpty?event.summary:event.region} · 정밀검사 결과를 확인 중입니다.'),'confirmed'=>('[양성] ${event.disease} 공식 확진','${event.region.isEmpty?event.summary:event.region} · 의심 신고가 공식 발생으로 전환됐습니다.'),'negative'=>('[음성] ${event.disease} 의심 해제','${event.region.isEmpty?event.summary:event.region} · 정밀검사 결과 음성으로 확인됐습니다.'),_=>('${event.disease} 정보 갱신',event.summary)};await _plugin.show(event.incidentKey.hashCode,title,body,const NotificationDetails(android:AndroidNotificationDetails('disease_status','질병 의심·검사 결과',channelDescription:'질병 의심 신고와 양성·음성 결과',importance:Importance.high,priority:Priority.high),iOS:DarwinNotificationDetails()),payload:event.stableKey);}
}
