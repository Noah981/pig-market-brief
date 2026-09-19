import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/farm_hero_section.dart';
import '../widgets/market_price_card.dart';
import '../widgets/todo_summary_card.dart';
import '../widgets/weather_summary_card.dart';
import 'section_pages.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});
  @override State<HomeDashboardPage> createState()=>_HomeDashboardPageState();
}
class _HomeDashboardPageState extends State<HomeDashboardPage>{
  int _nav=0; int _period=0; late final List<TodoItem> _todos=mockTodos();
  @override Widget build(BuildContext context)=>Scaffold(
    bottomNavigationBar:BottomNavigation(index:_nav,onSelected:(i)=>setState(()=>_nav=i)),
    body:SafeArea(bottom:false,child:IndexedStack(index:_nav,children:[_home(),const MarketOverviewPage(),const DiseasePage(),const FarmCheckPage(),const MorePage()])),
  );
  Widget _home()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:CustomScrollView(key:const PageStorageKey('home'),slivers:[
    const SliverToBoxAdapter(child:FarmHeroSection()),
    SliverPadding(padding:const EdgeInsets.fromLTRB(AppSpacing.page,8,AppSpacing.page,14),sliver:SliverList.list(children:[
      MarketPriceCard(period:_period,series:priceSeries,onPeriodChanged:(i)=>setState(()=>_period=i)),const SizedBox(height:10),
      SizedBox(height:190,child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:TodoSummaryCard(items:_todos,onToggle:(i)=>setState(()=>_todos[i].done=!_todos[i].done))),const SizedBox(width:8),const Expanded(child:WeatherSummaryCard())])),
    ]))
  ])));
}
