import 'package:flutter/material.dart';
import '../data/commodity_repository.dart';
import '../data/market_repository.dart';
import '../data/market_analysis_repository.dart';
import '../data/weather_farm_repository.dart';
import '../data/benefit_repository.dart';
import '../data/pig_grade_repository.dart';
import '../services/data_refresh_service.dart';
import '../services/notification_service.dart';
import '../models/dashboard_models.dart';
import '../models/weather_farm_models.dart';
import '../settings/display_settings.dart';
import '../settings/farm_location_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/bottom_navigation.dart';
import '../widgets/commodity_trend_card.dart';
import '../widgets/farm_hero_section.dart';
import '../widgets/market_price_card.dart';
import '../widgets/market_reason_card.dart';
import '../widgets/weather_summary_card.dart';
import '../widgets/home_grade_auction_card.dart';
import 'section_pages.dart';
import 'market_detail_pages.dart';
import 'disease_page.dart';
import 'today_care_page.dart';

class HomeDashboardPage extends StatefulWidget {
  const HomeDashboardPage({super.key});
  @override State<HomeDashboardPage> createState()=>_HomeDashboardPageState();
}
class _HomeDashboardPageState extends State<HomeDashboardPage> with WidgetsBindingObserver{
  int _nav=0; int _period=0;
  final _marketRepository=MarketRepository();MarketSnapshot? _market;
  final _analysisRepository=MarketAnalysisRepository();MarketAnalysis? _analysis=MarketAnalysisRepository.bundledSnapshot;
  final _commodityRepository=CommodityRepository();List<Commodity> _commodities=CommodityRepository.bundledSnapshot;
  final _weatherRepository=WeatherFarmRepository();WeatherFarmGuide _weather=WeatherFarmRepository.fallback;
  final _gradeRepository=PigGradeRepository();PigGradeSnapshot? _grades;
  String _weatherRegion='대구광역시';
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);DisplaySettings.instance.addListener(_displayChanged);FarmLocationSettings.instance.addListener(_locationChanged);NotificationService.instance.selectedDiseaseEvent.addListener(_openDiseaseNotification);_loadCachedData();_loadAnalysis();_refreshBenefits();_startupRefresh();_openDiseaseNotification();}
  @override void dispose(){DisplaySettings.instance.removeListener(_displayChanged);FarmLocationSettings.instance.removeListener(_locationChanged);NotificationService.instance.selectedDiseaseEvent.removeListener(_openDiseaseNotification);WidgetsBinding.instance.removeObserver(this);super.dispose();}
  void _displayChanged(){if(mounted)setState((){});}
  void _openDiseaseNotification(){if(NotificationService.instance.selectedDiseaseEvent.value!=null&&mounted)setState(()=>_nav=2);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed)_resumeRefresh();}
  Future<void> _resumeRefresh()async{if(await DataRefreshService.refreshAll()){await Future.wait([_reloadMarketCache(),_reloadCommodityCache(),_reloadWeatherCache()]);}}
  Future<void> _reloadMarketCache()async{final value=await _marketRepository.cached();if(mounted&&value!=null){setState(()=>_market=value);await _loadGrades(value.date);}}
  Future<void> _reloadCommodityCache()async{final value=await _commodityRepository.cached();if(mounted&&value.isNotEmpty)setState(()=>_commodities=value);}
  Future<void> _reloadWeatherCache()async{final value=await _weatherRepository.cached();if(mounted)setState(()=>_weather=value);}
  Future<void> _loadCachedData()async{try{await FarmLocationSettings.instance.load();_weatherRegion=FarmLocationSettings.instance.location.province;}catch(_){}await Future.wait([_reloadMarketCache(),_reloadCommodityCache(),_reloadWeatherCache()]);}
  Future<void> _startupRefresh()async{if(await DataRefreshService.refreshAll()){await Future.wait([_reloadMarketCache(),_reloadCommodityCache(),_reloadWeatherCache()]);}else if(_market!=null){await _loadGrades(_market!.date);}}
  Future<void> _loadGrades(String date)async{try{final cached=await _gradeRepository.cached();if(mounted&&cached!=null)setState(()=>_grades=cached);final value=await _gradeRepository.refresh(date);if(mounted)setState(()=>_grades=value);}catch(_){}}
  Future<void> _refreshMarket()async{try{final value=await _marketRepository.refresh();if(mounted)setState(()=>_market=value);await _loadGrades(value.date);}catch(_){}}
  Future<void> _loadAnalysis()async{try{final cached=await _analysisRepository.cached();if(mounted&&cached!=null)setState(()=>_analysis=cached);}catch(_){}await _refreshAnalysis();}
  Future<void> _refreshAnalysis()async{try{final value=await _analysisRepository.refresh();if(mounted)setState(()=>_analysis=value);}catch(_){}}
  Future<void> _refreshWeather()async{try{final value=await _weatherRepository.refresh(region:_weatherRegion);if(mounted)setState(()=>_weather=value);}catch(_){}}
  Future<void> _refreshBenefits()async{try{await FarmLocationSettings.instance.load();await BenefitRepository().refresh();}catch(_){}}
  void _locationChanged(){final region=FarmLocationSettings.instance.location.province;if(region!=_weatherRegion){_weatherRegion=region;_refreshWeather();}else if(mounted){setState((){});}}
  Future<void> _pullToRefresh()async{
    await Future.wait([DataRefreshService.refreshAll(force:true),_refreshAnalysis(),_refreshBenefits()]);
    await Future.wait([_reloadMarketCache(),_reloadCommodityCache(),_reloadWeatherCache()]);
    if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('최신 시황을 확인했습니다.'),duration:Duration(seconds:1)));
  }
  @override Widget build(BuildContext context)=>Scaffold(
    bottomNavigationBar:BottomNavigation(index:_nav,onSelected:(i)=>setState(()=>_nav=i)),
    body:SafeArea(bottom:false,child:IndexedStack(index:_nav,children:[_home(),MarketOverviewPage(snapshot:_market,commodities:_commodities,analysis:_analysis,onRefresh:_pullToRefresh),const DiseasePage(),TodayCarePage(guide:_weather,onRefresh:_refreshWeather),const MorePage()])),
  );
  Widget _home()=>Center(child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:RefreshIndicator(color:AppColors.coral,onRefresh:_pullToRefresh,child:CustomScrollView(physics:const AlwaysScrollableScrollPhysics(),key:const PageStorageKey('home'),slivers:[
    SliverToBoxAdapter(child:FarmHeroSection()),
    SliverPadding(padding:const EdgeInsets.fromLTRB(AppSpacing.page,0,AppSpacing.page,14),sliver:SliverList.list(children:[
      MarketPriceCard(period:_period,snapshot:_market,onRefresh:_refreshMarket,onTap:_openPigPrice,onPeriodChanged:(i)=>setState(()=>_period=i)),const SizedBox(height:10),
      SizedBox(height:DisplaySettings.instance.largeTextMode?310:DisplaySettings.instance.textScale>=1.3?255:205,child:Row(crossAxisAlignment:CrossAxisAlignment.stretch,children:[Expanded(child:MarketReasonCard(analysis:_analysis,onTap:_openMarketDrivers)),const SizedBox(width:8),Expanded(child:WeatherSummaryCard(guide:_weather,onTap:()=>setState(()=>_nav=3)))])),
      const SizedBox(height:10),
      HomeGradeAuctionCard(snapshot:_grades,onTap:_openPigPrice),
      const SizedBox(height:10),
      CommodityTrendCard(items:_commodities,onTap:_openCommodity,onHeaderTap:()=>setState(()=>_nav=1)),
      const SizedBox(height:12),
    ]))
  ]))));
  void _openPigPrice()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PigPriceDetailPage(snapshot:_market,analysis:_analysis)));
  void _openMarketDrivers()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>MarketDriverDetailPage(analysis:_analysis)));
  void _openCommodity(Commodity item)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:item)));
}
