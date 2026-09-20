import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/home_dashboard_page.dart';
import 'settings/display_settings.dart';
import 'pages/price_deep_link_page.dart';
import 'pages/disease_page.dart';
import 'services/price_widget_bridge.dart';

class DondonhaeApp extends StatefulWidget {
  const DondonhaeApp({super.key});
  @override State<DondonhaeApp> createState()=>_DondonhaeAppState();
}

class _DondonhaeAppState extends State<DondonhaeApp>{
  final settings=DisplaySettings.instance;
  final navigatorKey=GlobalKey<NavigatorState>();
  @override void initState(){super.initState();settings.addListener(_changed);settings.load();PriceWidgetBridge.listenForOpen(price:()=>navigatorKey.currentState?.pushNamed('/price'),disease:()=>navigatorKey.currentState?.pushNamed('/disease'));}
  @override void dispose(){settings.removeListener(_changed);super.dispose();}
  void _changed(){if(mounted)setState((){});}
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '돈돈해',
        navigatorKey:navigatorKey,
        theme: AppTheme.light,
        builder:(context,child){
          final media=MediaQuery.of(context);
          return MediaQuery(data:media.copyWith(textScaler:TextScaler.linear(settings.textScale)),child:child!);
        },
        home: HomeDashboardPage(key:ValueKey('home_${settings.largeTextMode}_${settings.textScale}')),
        onGenerateRoute:(route)=>route.name=='/price'?MaterialPageRoute(settings:route,builder:(_)=>const PriceDeepLinkPage()):route.name=='/disease'?MaterialPageRoute(settings:route,builder:(_)=>const DiseasePage()):null,
      );
}
