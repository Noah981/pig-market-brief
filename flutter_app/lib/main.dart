import 'dart:async';
import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/background_refresh_service.dart';
import 'services/push_notification_service.dart';

Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();await NotificationService.instance.initialize(requestPermission:true);try{await initializeBackgroundRefresh();}catch(_){}runApp(const DondonhaeApp());unawaited(PushNotificationService.initialize());}
