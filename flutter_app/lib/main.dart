import 'package:flutter/material.dart';
import 'app.dart';
import 'services/notification_service.dart';
import 'services/background_refresh_service.dart';

Future<void> main()async{WidgetsFlutterBinding.ensureInitialized();await NotificationService.instance.initialize();try{await initializeBackgroundRefresh();}catch(_){}runApp(const DondonhaeApp());}
