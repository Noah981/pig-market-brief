import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../widgets/add_todo_bottom_sheet.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/commodity_trend_card.dart';
import '../widgets/farm_hero_section.dart';
import '../widgets/market_price_card.dart';
import '../widgets/notice_card.dart';
import '../widgets/todo_summary_card.dart';
import '../widgets/weather_summary_card.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});
  @override State<HomeDashboardPage> createState()=>_HomeDashboardPageState();
}

class _HomeDashboardPageState extends State<HomeDashboardPage>{
  int _nav=0;int _period=0;late final List<TodoItem> _todos=mockTodos();
  Future<void> _addTodo()async{final item=await showModalBottomSheet<TodoItem>(context:context,isScrollControlled:true,showDragHandle:false,builder:(_)=>const AddTodoBottomSheet());if(item!=null)setState(()=>_todos.insert(0,item));}
  @override Widget build(BuildContext context)=>Scaffold(
    bottomNavigationBar:BottomNavigation(index:_nav,onSelected:(i)=>setState(()=>_nav=i),onAdd:_addTodo),
    body:SafeArea(bottom:false,child:_nav==0?_home():_placeholder()),
  );
  Widget _home()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:CustomScrollView(slivers:[
    const SliverToBoxAdapter(child:FarmHeroSection()),
    SliverPadding(padding:const EdgeInsets.fromLTRB(AppSpacing.page,12,AppSpacing.page,22),sliver:SliverList.list(children:[
      MarketPriceCard(period:_period,series:priceSeries,onPeriodChanged:(i)=>setState(()=>_period=i)),const SizedBox(height:14),
      LayoutBuilder(builder:(context,c){if(c.maxWidth<350)return Column(children:[TodoSummaryCard(items:_todos,onToggle:(i)=>setState(()=>_todos[i].done=!_todos[i].done)),const SizedBox(height:12),const WeatherSummaryCard()]);return IntrinsicHeight(child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:TodoSummaryCard(items:_todos,onToggle:(i)=>setState(()=>_todos[i].done=!_todos[i].done))),const SizedBox(width:10),const Expanded(child:WeatherSummaryCard())]));}),
      const SizedBox(height:14),const CommodityTrendCard(items:commodities),const SizedBox(height:14),const NoticeCard(items:notices),
    ]))
  ])));
  Widget _placeholder()=>Center(child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.construction,size:46,color:AppColors.coral),const SizedBox(height:14),Text(['홈','시황','추가','농장점검','더보기'][_nav],style:const TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:7),const Text('준비 중인 화면입니다',style:TextStyle(color:AppColors.secondary))]));
}
