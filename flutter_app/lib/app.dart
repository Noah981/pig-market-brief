import 'package:flutter/material.dart';
import 'theme/app_theme.dart';
import 'pages/home_dashboard_page.dart';

class DondonhaeApp extends StatelessWidget {
  const DondonhaeApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '돈돈해',
        theme: AppTheme.light,
        home: const HomeDashboardPage(),
      );
}
