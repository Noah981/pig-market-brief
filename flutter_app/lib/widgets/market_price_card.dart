import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import 'period_tab_bar.dart';
import 'price_line_chart.dart';

class MarketPriceCard extends StatelessWidget {
  const MarketPriceCard({super.key, required this.period, required this.series, required this.onPeriodChanged});
  final int period;
  final List<PriceSeries> series;
  final ValueChanged<int> onPeriodChanged;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 11, 12, 9), decoration: appCard(radius:18),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('전국 돈가', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900)), const Text(' (제주 제외)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700)), const Spacer(), const Text('단위: 원/kg', style: TextStyle(fontSize: 7.5, color: AppColors.secondary)), IconButton(onPressed: () {}, constraints: const BoxConstraints(minWidth: 29,minHeight: 29), padding: EdgeInsets.zero, icon: const Icon(Icons.refresh, size: 16, color: AppColors.secondary))]),
      LayoutBuilder(builder: (context, box) { final narrow=box.maxWidth<350; return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('6,442', style: TextStyle(fontSize: 42, height: 1, fontWeight: FontWeight.w900, letterSpacing: -1.8)), Padding(padding: EdgeInsets.only(bottom: 5), child: Text(' 원/kg', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800)))])),
          const SizedBox(height: 2), const Text('▼ 298원 (-4.42%)', maxLines:1,style: TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: AppColors.blue)), const Text('전일 6,740원', style: TextStyle(fontSize: 10, color: AppColors.secondary)),
        ])),
        SizedBox(width: narrow?6:8), Container(width: narrow?105:114, padding: const EdgeInsets.all(9), decoration: BoxDecoration(color: AppColors.lightBlue,borderRadius: BorderRadius.circular(13)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Icon(Icons.bar_chart,color:AppColors.blue,size:18),SizedBox(width:5),Flexible(child:Text('전일 대비\n하락',style:TextStyle(fontSize:11,fontWeight:FontWeight.w900,color:AppColors.blue)))]),SizedBox(height:5),Text('시장이 조정을 보이고 있습니다.',style:TextStyle(fontSize:8.5,height:1.35))])),
      ]);}),
      const SizedBox(height: 7), PriceLineChart(values: series[period].values), const SizedBox(height: 3), PeriodTabBar(selected: period,onChanged:onPeriodChanged), const SizedBox(height: 6),
      const Text('출처: 축산물품질평가원 · 2025.09.18 기준', style: TextStyle(fontSize: 7.5,color:AppColors.secondary)),
    ]),
  );
}
