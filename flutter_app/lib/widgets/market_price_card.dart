import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../data/market_repository.dart';
import '../theme/app_theme.dart';
import 'period_tab_bar.dart';
import 'price_line_chart.dart';

class MarketPriceCard extends StatelessWidget {
  const MarketPriceCard({super.key, required this.period, required this.series, required this.onPeriodChanged,this.snapshot,this.onRefresh,this.onTap});
  final int period;
  final List<PriceSeries> series;
  final ValueChanged<int> onPeriodChanged;
  final MarketSnapshot? snapshot;
  final VoidCallback? onRefresh;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(18), onTap:onTap,
    child:Container(padding: const EdgeInsets.fromLTRB(12, 11, 12, 9), decoration: appCard(radius:18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('전국 돈가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const Text(' (제주 제외)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)), const Spacer(), const Text('단위: 원/kg', style: TextStyle(fontSize: 7.5, color: AppColors.secondary)), IconButton(onPressed:onRefresh, constraints: const BoxConstraints(minWidth: 29,minHeight: 29), padding: EdgeInsets.zero, icon: const Icon(Icons.refresh, size: 16, color: AppColors.secondary))]),
      LayoutBuilder(builder: (context, box) { final narrow=box.maxWidth<350; return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child:Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(snapshot==null?'—':_number(snapshot!.price), style:const TextStyle(fontSize:42,height:1,fontWeight:FontWeight.w900,letterSpacing:-1.8)),const Padding(padding:EdgeInsets.only(bottom:5),child:Text(' 원/kg',style:TextStyle(fontSize:13,fontWeight:FontWeight.w800)))])),
          const SizedBox(height:2),Text(_changeText(),maxLines:1,style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:(snapshot?.change??-1)>=0?AppColors.coral:AppColors.blue)),Text(snapshot==null?'공식 데이터 불러오는 중':'전일 ${_number(snapshot!.previousPrice)}원',style:const TextStyle(fontSize:10,color:AppColors.secondary)),
        ])),
        SizedBox(width: narrow?6:8), Container(width: narrow?105:114, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.lightBlue,borderRadius: BorderRadius.circular(13)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Icon((snapshot?.change??0)>=0?Icons.trending_up:Icons.bar_chart,color:(snapshot?.change??0)>=0?AppColors.coral:AppColors.blue,size:18),const SizedBox(width:5),Flexible(child:Text(snapshot==null?'가격 확인 중':(snapshot!.change>=0?'전일 대비\n상승':'전일 대비\n하락'),style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:(snapshot?.change??0)>=0?AppColors.coral:AppColors.blue)))]),const SizedBox(height:5),Text(snapshot==null?'공식 가격을 불러오고 있습니다.':'가격 변동 근거를 눌러 확인하세요.',style:const TextStyle(fontSize:8.5,height:1.35))])),
      ]);}),
      const SizedBox(height:7),PriceLineChart(series:snapshot?.seriesFor(period)??series[period]),const SizedBox(height:3),PeriodTabBar(selected:period,onChanged:onPeriodChanged),const SizedBox(height:6),
      Text(_sourceText(),style:const TextStyle(fontSize:7.5,color:AppColors.secondary)),
    ]),
  ));
  String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
  String _changeText(){if(snapshot==null)return '확정 가격 확인 중';final c=snapshot!.change;final p=snapshot!.changePct;return '${c>=0?'▲':'▼'} ${_number(c.abs())}원 (${p>=0?'+':''}${p.toStringAsFixed(2)}%)';}
  String _sourceText(){if(snapshot==null)return '출처: 축산물품질평가원 · 데이터 연결 중';final d=snapshot!.date.length==8?'${snapshot!.date.substring(0,4)}.${snapshot!.date.substring(4,6)}.${snapshot!.date.substring(6,8)}':snapshot!.date;return '출처: ${snapshot!.source} · $d 기준${snapshot!.fromCache?' · 마지막 저장 데이터':''}';}
}
