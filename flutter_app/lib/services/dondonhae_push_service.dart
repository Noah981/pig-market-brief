import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

@pragma('vm:entry-point')
Future<void> dondonhaeFirebaseBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DondonhaePushService.androidOptions);
}

class DondonhaePushService {
  DondonhaePushService._();
  static const androidOptions = FirebaseOptions(
    apiKey: 'AIzaSyDuNoGGFkxkrZqedDyM3jbFsgfnpuU7QS8',
    appId: '1:1046916972137:android:1aa9952af46e34652b6cf8',
    messagingSenderId: '1046916972137',
    projectId: 'dondonhae-cd1d7',
    storageBucket: 'dondonhae-cd1d7.firebasestorage.app',
  );
  static Future<void> initialize() async {
    if (kIsWeb || !Platform.isAndroid) return;
    await Firebase.initializeApp(options: androidOptions);
    FirebaseMessaging.onBackgroundMessage(dondonhaeFirebaseBackgroundHandler);
    final messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);
    await syncPreferences();
    FirebaseMessaging.onMessage.listen((message) async {
      final notification = message.notification;
      if (notification == null) return;
      await NotificationService.instance.remotePush(
        message.messageId ?? '${message.sentTime?.millisecondsSinceEpoch ?? DateTime.now().millisecondsSinceEpoch}',
        notification.title ?? '돈돈해 알림',
        notification.body ?? '',
        message.data['event_id'],
      );
    });
  }
  static Future<void> syncPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final messaging = FirebaseMessaging.instance;
    final topics = <String,bool>{
      'dondonhae_market_updates': prefs.getBool('market_notifications_enabled') ?? true,
      'dondonhae_disease_nationwide': prefs.getBool('disease_notifications_enabled') ?? true,
    };
    for (final entry in topics.entries) {
      if (entry.value) {
        await messaging.subscribeToTopic(entry.key);
      } else {
        await messaging.unsubscribeFromTopic(entry.key);
      }
    }
  }
}
