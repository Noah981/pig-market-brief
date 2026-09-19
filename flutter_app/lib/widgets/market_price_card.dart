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
    padding: const EdgeInsets.fromLTRB(16, 15, 16, 13), decoration: appCard(),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [const Text('전국 돈가', style: TextStyle(fontSize: 23, fontWeight: FontWeight.w900)), const Text(' (제주 제외)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(width: 12), const Text('단위: 원/kg (탕박)', style: TextStyle(fontSize: 10, color: AppColors.secondary)), const Spacer(), const Text('최종 업데이트 09.18 06:00', style: TextStyle(fontSize: 9, color: AppColors.secondary)), IconButton(onPressed: () {}, constraints: const BoxConstraints(minWidth: 36,minHeight: 36), padding: EdgeInsets.zero, icon: const Icon(Icons.refresh, size: 20, color: AppColors.secondary))]),
      LayoutBuilder(builder: (context, box) { final narrow=box.maxWidth<350; return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: const Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Text('6,442', style: TextStyle(fontSize: 58, height: 1, fontWeight: FontWeight.w900, letterSpacing: -2)), Padding(padding: EdgeInsets.only(bottom: 7), child: Text(' 원/kg', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)))])),
          const SizedBox(height: 4), const Text('▼ 298원 (-4.42%)', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: AppColors.blue)), const Text('전일 6,740원', style: TextStyle(fontSize: 14, color: AppColors.secondary)),
        ])),
        SizedBox(width: narrow?8:12), Container(width: narrow?130:144, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.lightBlue,borderRadius: BorderRadius.circular(15)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Row(children:[Icon(Icons.bar_chart,color:AppColors.blue,size:24),SizedBox(width:7),Flexible(child:Text('전일 대비 하락',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900,color:AppColors.blue)))]),SizedBox(height:10),Text('시장이 조정을 보이고 있습니다.',style:TextStyle(fontSize:11.5,height:1.4))])),
      ]);}),
      const SizedBox(height: 11), PriceLineChart(values: series[period].values), const SizedBox(height: 5), PeriodTabBar(selected: period,onChanged:onPeriodChanged), const SizedBox(height: 8),
      const Text('출처 축산물품질평가원 · 기준: 생산자 돼지 경락가격 · 2025.09.18', style: TextStyle(fontSize: 9.5,color:AppColors.secondary)),
    ]),
  );
}
