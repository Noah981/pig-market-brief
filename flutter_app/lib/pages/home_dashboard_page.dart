import 'dart:async';
import 'package:flutter/material.dart';
import '../data/mock_data.dart';
import '../data/commodity_repository.dart';
import '../data/market_repository.dart';
import '../data/market_analysis_repository.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/commodity_trend_card.dart';
import '../widgets/farm_hero_section.dart';
import '../widgets/market_price_card.dart';
import '../widgets/notice_card.dart';
import '../widgets/market_reason_card.dart';
import '../widgets/weather_summary_card.dart';
import 'section_pages.dart';
import 'market_detail_pages.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});
  @override State<HomeDashboardPage> createState()=>_HomeDashboardPageState();
}
class _HomeDashboardPageState extends State<HomeDashboardPage> with WidgetsBindingObserver{
  int _nav=0; int _period=0;
  final _marketRepository=MarketRepository();MarketSnapshot? _market=MarketRepository.bundledSnapshot;Timer? _timer;
  final _analysisRepository=MarketAnalysisRepository();MarketAnalysis? _analysis;
  final _commodityRepository=CommodityRepository();List<Commodity> _commodities=CommodityRepository.bundledSnapshot;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_loadMarket();_loadAnalysis();_loadCommodities();_timer=Timer.periodic(const Duration(minutes:30),(_){_refreshMarket();_refreshAnalysis();_refreshCommodities();});}
  @override void dispose(){_timer?.cancel();WidgetsBinding.instance.removeObserver(this);super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_refreshMarket();}
  Future<void> _loadMarket()async{try{final cached=await _marketRepository.cached();if(mounted&&cached!=null)setState(()=>_market=cached);}catch(_){}await _refreshMarket();}
  Future<void> _refreshMarket()async{try{final value=await _marketRepository.refresh();if(mounted)setState(()=>_market=value);}catch(_){}}
  Future<void> _loadAnalysis()async{try{final cached=await _analysisRepository.cached();if(mounted&&cached!=null)setState(()=>_analysis=cached);}catch(_){}await _refreshAnalysis();}
  Future<void> _refreshAnalysis()async{try{final value=await _analysisRepository.refresh();if(mounted)setState(()=>_analysis=value);}catch(_){}}
  Future<void> _loadCommodities()async{try{final cached=await _commodityRepository.cached();if(mounted&&cached.isNotEmpty)setState(()=>_commodities=cached);}catch(_){}await _refreshCommodities();}
  Future<void> _refreshCommodities()async{try{final value=await _commodityRepository.refresh();if(mounted&&value.isNotEmpty)setState(()=>_commodities=value);}catch(_){}}
  Future<void> _pullToRefresh()async{
    await Future.wait([_refreshMarket(),_refreshAnalysis(),_refreshCommodities()]);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('최신 시황을 확인했습니다.'),duration:Duration(seconds:1)));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    bottomNavigationBar:BottomNavigation(index:_nav,onSelected:(i)=>setState(()=>_nav=i)),
    body:SafeArea(bottom:false,child:IndexedStack(index:_nav,children:[_home(),MarketOverviewPage(snapshot:_market,commodities:_commodities,analysis:_analysis),const DiseasePage(),const FarmCheckPage(),const MorePage()])),
  );
  Widget _home()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:RefreshIndicator(color:AppColors.coral,onRefresh:_pullToRefresh,child:CustomScrollView(physics:const AlwaysScrollableScrollPhysics(),key:const PageStorageKey('home'),slivers:[
    const SliverToBoxAdapter(child:FarmHeroSection()),
    SliverPadding(padding:const EdgeInsets.fromLTRB(AppSpacing.page,8,AppSpacing.page,14),sliver:SliverList.list(children:[
      MarketPriceCard(period:_period,series:priceSeries,snapshot:_market,onRefresh:_refreshMarket,onTap:_openPigPrice,onPeriodChanged:(i)=>setState(()=>_period=i)),const SizedBox(height:10),
      SizedBox(height:205,child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:MarketReasonCard(analysis:_analysis,onTap:_openPigPrice)),const SizedBox(width:8),const Expanded(child:WeatherSummaryCard())])),
      const SizedBox(height:10),
      CommodityTrendCard(items:_commodities,onTap:_openCommodity),
      const SizedBox(height:10),
      const NoticeCard(items:notices),
      const SizedBox(height:12),
    ]))
  ]))));
  void _openPigPrice()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PigPriceDetailPage(snapshot:_market,analysis:_analysis)));
  void _openCommodity(Commodity item)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:item)));
}
