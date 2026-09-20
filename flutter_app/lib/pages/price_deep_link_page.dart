import 'package:flutter/material.dart';
import '../data/market_analysis_repository.dart';
import '../data/market_repository.dart';
import '../models/dashboard_models.dart';
import 'market_detail_pages.dart';

class PriceDeepLinkPage extends StatefulWidget{const PriceDeepLinkPage({super.key});@override State<PriceDeepLinkPage> createState()=>_PriceDeepLinkPageState();}
class _PriceDeepLinkPageState extends State<PriceDeepLinkPage>{MarketSnapshot? _price;MarketAnalysis? _analysis=MarketAnalysisRepository.bundledSnapshot;
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final prices=MarketRepository(),analysis=MarketAnalysisRepository();try{final cached=await prices.cached();if(mounted)setState(()=>_price=cached);}catch(_){}try{final value=await prices.refresh();if(mounted)setState(()=>_price=value);}catch(_){}try{final value=await analysis.refresh();if(mounted)setState(()=>_analysis=value);}catch(_){} }
 @override Widget build(BuildContext context)=>PigPriceDetailPage(snapshot:_price,analysis:_analysis);
}
