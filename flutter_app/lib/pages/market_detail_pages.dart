import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/market_repository.dart';
import '../data/pig_grade_repository.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../widgets/price_line_chart.dart';

class PigPriceDetailPage extends StatefulWidget {
  const PigPriceDetailPage({super.key, required this.snapshot, required this.analysis,this.loadGrades=true});
  final MarketSnapshot? snapshot;
  final MarketAnalysis? analysis;
  final bool loadGrades;
  @override State<PigPriceDetailPage> createState()=>_PigPriceDetailPageState();
}

class _PigPriceDetailPageState extends State<PigPriceDetailPage>{
  int period=0;PigGradeSnapshot? grades;String? gradeError;
  MarketSnapshot? get snapshot=>widget.snapshot;MarketAnalysis? get analysis=>widget.analysis;
  @override void initState(){super.initState();if(widget.loadGrades)_loadGrades();}
  Future<void> _loadGrades()async{final repo=PigGradeRepository();final cached=await repo.cached();if(mounted&&cached!=null)setState(()=>grades=cached);if(snapshot==null)return;try{final value=await repo.refresh(snapshot!.date);if(mounted)setState((){grades=value;gradeError=null;});}catch(_){if(mounted)setState(()=>gradeError='공식 등급별 가격을 확인할 수 없습니다.');}}
  @override
  Widget build(BuildContext context) => _DetailScaffold(
        title: '전국 돈가 상세',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ValueCard(
            title: '생산자 돼지 경락가격 (제주 제외)',
            value: snapshot == null ? '확정 가격 확인 중' : '${_number(snapshot!.price)}원/kg',
            change: snapshot == null ? '' : '${snapshot!.change >= 0 ? '▲' : '▼'} ${_number(snapshot!.change.abs())}원 (${snapshot!.changePct.toStringAsFixed(2)}%)',
            up: (snapshot?.change ?? 0) >= 0,
          ),
          const SizedBox(height:12),
          _PeriodTabs(labels:const ['7일','1개월','1년','3년'],selected:period,onChanged:(i)=>setState(()=>period=i)),
          const SizedBox(height:8),
          if(snapshot!=null)Container(padding:const EdgeInsets.all(10),decoration:appCard(radius:16),child:PriceLineChart(series:snapshot!.detailSeries(period))),
          const SizedBox(height: 16),
          const Text('오늘 가격이 움직인 주요 요인', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (analysis == null || analysis!.factors.isEmpty)
            const _InfoBox('공식 가격과 수급 자료를 확인하고 있습니다.')
          else ...[
            Text(analysis!.summary, style: const TextStyle(fontSize: 12, height: 1.55, color: AppColors.secondary)),
            const SizedBox(height: 10),
            ...analysis!.factors.map((x) => _FactorTile(x)),
          ],
          const SizedBox(height:16),
          const Text('등급별 경락가격',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
          const SizedBox(height:8),
          if(grades==null||grades!.grades.isEmpty)_InfoBox(gradeError??'축산물품질평가원 등급별 가격을 확인하고 있습니다.')
          else Container(padding:const EdgeInsets.all(12),decoration:appCard(radius:16),child:Column(children:[...grades!.grades.map((x){final old=grades!.previous(x.grade),change=old==null?null:x.price-old.price,pct=old==null||old.price==0?null:change!*100/old.price;return Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[SizedBox(width:34,child:Text(x.grade,style:const TextStyle(fontWeight:FontWeight.w900))),Expanded(child:LinearProgressIndicator(value:(x.price/10000).clamp(0,1),color:AppColors.coral,backgroundColor:AppColors.lightBlue)),const SizedBox(width:8),SizedBox(width:80,child:Text('${_number(x.price)}원/kg',textAlign:TextAlign.right,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900))),const SizedBox(width:7),SizedBox(width:56,child:Text(change==null?'정보 없음':'${change>=0?'▲':'▼'} ${pct!.abs().toStringAsFixed(1)}%',textAlign:TextAlign.right,style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:change==null?AppColors.secondary:change>=0?AppColors.coral:AppColors.blue))) ]));}),const SizedBox(height:8),OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>GradePriceTrendPage(snapshot:grades!))),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(44),foregroundColor:AppColors.coral),child:const Text('등급별 가격 추이 보기  >'))])),
          if(grades!=null&&grades!.grades.isNotEmpty)...[
            const SizedBox(height:16),const Text('오늘 경락 현황',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),const SizedBox(height:8),
            _InfoBox('경락두수: ${_number(grades!.grades.fold(0,(sum,x)=>sum+x.count))}두\n평균 도체중: 정보 없음\n성별 데이터: 정보 없음\n※ 공식 응답에 포함된 항목만 표시합니다.'),
          ],
          if(snapshot!=null)...[const SizedBox(height:12),OutlinedButton(onPressed:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>ThreeYearPigPricePage(snapshot:snapshot!))),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(46),foregroundColor:AppColors.coral),child:const Text('3개년 월별 돈가 비교 보기  >'))],
          const SizedBox(height: 12),
          _InfoBox(snapshot == null
              ? '출처: 축산물품질평가원 축산유통정보 다봄'
              : '출처: ${snapshot!.source}\n기준: ${snapshot!.scope}\n가격 기준일: ${_date(snapshot!.date)}'),
          if(analysis!=null&&analysis!.sources.isNotEmpty)...[
            const SizedBox(height:10),
            ...analysis!.sources.map((x)=>_SourceButton(source:x)),
          ],
        ]),
      );

  String _number(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  String _date(String value) => value.length == 8 ? '${value.substring(0, 4)}.${value.substring(4, 6)}.${value.substring(6, 8)}' : value;
}

class ThreeYearPigPricePage extends StatelessWidget{
  const ThreeYearPigPricePage({super.key,required this.snapshot});final MarketSnapshot snapshot;
  @override Widget build(BuildContext context){final series=snapshot.detailSeries(3),values=series.points.map((x)=>x.value).toList(),avg=values.isEmpty?0:values.reduce((a,b)=>a+b)/values.length,high=values.isEmpty?0:values.reduce((a,b)=>a>b?a:b),low=values.isEmpty?0:values.reduce((a,b)=>a<b?a:b);return _DetailScaffold(title:'3개년 월별 돈가 비교',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Container(padding:const EdgeInsets.all(10),decoration:appCard(radius:16),child:PriceLineChart(series:series)),const SizedBox(height:12),_InfoBox('3개년 월평균: ${avg.toStringAsFixed(0)}원/kg\n기간 최고: ${high.toStringAsFixed(0)}원/kg\n기간 최저: ${low.toStringAsFixed(0)}원/kg\n※ 실제 제공된 월만 표시하며 누락 월을 0으로 채우지 않습니다.'),const SizedBox(height:10),_InfoBox('출처: ${snapshot.source}\n기준: ${snapshot.scope}')])) ;}}

class GradePriceTrendPage extends StatefulWidget{
  const GradePriceTrendPage({super.key,required this.snapshot});final PigGradeSnapshot snapshot;
  @override State<GradePriceTrendPage> createState()=>_GradePriceTrendPageState();
}
class _GradePriceTrendPageState extends State<GradePriceTrendPage>{String grade='1+';@override Widget build(BuildContext context){final rows=widget.snapshot.history.where((x)=>x.grade==grade).map((x)=>CommodityPoint(x.date,x.price.toDouble())).toList();return _DetailScaffold(title:'등급별 가격 추이',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[_PeriodTabs(labels:const ['1+','1','2','등외'],selected:const ['1+','1','2','등외'].indexOf(grade),onChanged:(i)=>setState(()=>grade=const ['1+','1','2','등외'][i])),const SizedBox(height:10),if(rows.length>=2)_CommodityChart(points:rows)else const _InfoBox('선택한 등급의 실제 기간 데이터가 충분하지 않습니다.'),const SizedBox(height:12),_InfoBox('출처: 축산물품질평가원 축산유통정보\n기준일: ${widget.snapshot.date}\n대표 돈가와 별도로 조회한 등급별 공식 경락가격입니다.')])) ;}}

class CommodityDetailPage extends StatelessWidget {
  const CommodityDetailPage({super.key, required this.item});
  final Commodity item;

  @override
  Widget build(BuildContext context) {
    final drivers = item.analysisFactors;
    return _DetailScaffold(
      title: '${item.name.replaceAll('\n', ' ')} 상세',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ValueCard(
          title: item.name.replaceAll('\n', ' '),
          value: item.change == null ? '공식 데이터 연결 대기' : '${item.value} ${item.unit}',
          change: item.change == null ? '확인되지 않은 수치는 표시하지 않습니다.' : '${item.change! >= 0 ? '▲ 상승' : '▼ 하락'} ${item.change!.abs().toStringAsFixed(1)}% · ${item.frequency == 'monthly' ? '전월 대비' : '직전 발표 대비'}',
          up: (item.change ?? 0) >= 0,
        ),
        if (item.history.length >= 2) ...[
          const SizedBox(height: 14),
          _PeriodCommodityChart(points: item.history),
        ],
        const SizedBox(height: 16),
        const Text('가격 움직임 주요 요인', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        Text(item.analysisSummary.isEmpty?'가격·최근 추세·공식기관 발표를 함께 확인합니다. 직접 인과관계가 확인되지 않으면 원인으로 단정하지 않습니다.':item.analysisSummary,style:const TextStyle(fontSize:11,height:1.5,color:AppColors.secondary)),
        const SizedBox(height: 10),
        if(drivers.isEmpty)const _InfoBox('확인 가능한 출처와 기준일을 가진 주요 요인 데이터가 부족합니다.') else ...drivers.map(_FactorTile.new),
        if(item.analysisConfidence.isNotEmpty)_InfoBox('자동 분석 신뢰도: ${item.analysisConfidence}\n분석 시점: ${item.analysisUpdatedAt}\n공식 시계열과 공식기관 발표 제목을 이용한 자동 요약이며, 직접 인과관계를 확정하지 않습니다.'),
        if(item.history.isNotEmpty)...[const SizedBox(height:16),const Text('주요 지표',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),const SizedBox(height:8),_CommodityIndicators(item:item)],
        const SizedBox(height: 12),
        _InfoBox(item.source.isEmpty
            ? '데이터 출처 연결 검증 중\n값과 변동 이유가 공식 자료로 확인되면 자동 표시합니다.'
            : '출처: ${item.source}${item.asOf.isEmpty ? '' : '\n기준일: ${item.asOf}'}${item.updatedAt.isEmpty?'':'\n업데이트: ${item.updatedAt}'}${item.basis.isEmpty ? '' : '\n기준: ${item.basis}'}\n갱신주기: ${item.frequency == 'monthly' ? '월간' : '일간'}'),
        if(item.url.isNotEmpty)...[const SizedBox(height:10),_SourceButton(source:MarketSource(item.source,'공식 원자료 확인',item.url))],
        ...item.analysisSources.map((x)=>_SourceButton(source:x)),
      ]),
    );
  }

}

class _CommodityIndicators extends StatelessWidget{const _CommodityIndicators({required this.item});final Commodity item;@override Widget build(BuildContext context){final rows=item.history,values=rows.map((x)=>x.value).toList(),prior=rows.length>1?rows[rows.length-2]:null,month=rows.length>4?rows[rows.length-5]:null,quarter=rows.length>8?rows[rows.length-9]:null,high=values.reduce((a,b)=>a>b?a:b),low=values.reduce((a,b)=>a<b?a:b);String v(double x)=>'${x.toStringAsFixed(x>=1000?1:2)} ${item.unit}';final items=[('현재가','${item.value} ${item.unit}'),if(prior!=null)('직전 발표',v(prior.value)),if(month!=null)('이전 구간',v(month.value)),if(quarter!=null)('장기 비교',v(quarter.value)),('최근 고가',v(high)),('최근 저가',v(low))];return Container(padding:const EdgeInsets.all(13),decoration:appCard(radius:16),child:Column(children:items.map((x)=>Padding(padding:const EdgeInsets.symmetric(vertical:6),child:Row(children:[Expanded(child:Text(x.$1,style:const TextStyle(fontSize:11,color:AppColors.secondary))),Text(x.$2,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900))]))).toList()));}}

class _SourceButton extends StatelessWidget{
  const _SourceButton({required this.source});final MarketSource source;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.only(bottom:7),child:OutlinedButton.icon(onPressed:()async{final uri=Uri.tryParse(source.url);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);},icon:const Icon(Icons.open_in_new,size:16),label:Align(alignment:Alignment.centerLeft,child:Text('${source.name} · ${source.label}',maxLines:2)),style:OutlinedButton.styleFrom(minimumSize:const Size.fromHeight(46),foregroundColor:AppColors.coral,side:const BorderSide(color:AppColors.divider))));
}

class _PeriodTabs extends StatelessWidget{const _PeriodTabs({required this.labels,required this.selected,required this.onChanged});final List<String> labels;final int selected;final ValueChanged<int> onChanged;@override Widget build(BuildContext context)=>Container(height:38,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xFFF1F2F5),borderRadius:BorderRadius.circular(11)),child:Row(children:List.generate(labels.length,(i)=>Expanded(child:InkWell(onTap:()=>onChanged(i),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:selected==i?AppColors.coral:Colors.transparent,borderRadius:BorderRadius.circular(8)),child:Text(labels[i],style:TextStyle(fontSize:9,fontWeight:FontWeight.w800,color:selected==i?Colors.white:AppColors.secondary))))))));}

class _PeriodCommodityChart extends StatefulWidget{const _PeriodCommodityChart({required this.points});final List<CommodityPoint> points;@override State<_PeriodCommodityChart> createState()=>_PeriodCommodityChartState();}
class _PeriodCommodityChartState extends State<_PeriodCommodityChart>{int selected=0;@override Widget build(BuildContext context){final limits=[7,30,90,365],take=limits[selected],points=widget.points.length>take?widget.points.sublist(widget.points.length-take):widget.points;return Column(children:[_PeriodTabs(labels:const ['7일','1개월','3개월','1년'],selected:selected,onChanged:(i)=>setState(()=>selected=i)),const SizedBox(height:8),_CommodityChart(points:points)]);}}

class _CommodityChart extends StatelessWidget {
  const _CommodityChart({required this.points});
  final List<CommodityPoint> points;
  @override
  Widget build(BuildContext context) {
    final values = points.map((x) => x.value).toList();
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final padding = (high - low).abs() < 0.01 ? high * .08 : (high - low) * .16;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 7), decoration: appCard(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('최근 흐름', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: LineChart(LineChartData(
          minY: low - padding, maxY: high + padding,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
          titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(), leftTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: (points.length - 1) / 3, getTitlesWidget: (value, meta) {
            final index = value.round().clamp(0, points.length - 1);
            if (value != 0 && value < points.length - 2 && index % 3 != 0) return const SizedBox();
            final date = points[index].date;
            return Padding(padding: const EdgeInsets.only(top: 5), child: Text(date.length >= 10 ? '${date.substring(5, 7)}/${date.substring(8, 10)}' : date, style: const TextStyle(fontSize: 8, color: AppColors.secondary)));
          }))),
          lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((x) => LineTooltipItem(x.y.toStringAsFixed(x.y >= 1000 ? 1 : 2), const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))).toList())),
          lineBarsData: [LineChartBarData(spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])), color: AppColors.coral, barWidth: 2.5, isCurved: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.lightCoral.withValues(alpha: .55)))],
        ))),
      ]),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: ListView(padding: const EdgeInsets.all(20), children: [child])))),
      );
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.title, required this.value, required this.change, required this.up});
  final String title, value, change;
  final bool up;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18), decoration: appCard(radius: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
          if (change.isNotEmpty) ...[const SizedBox(height: 4), Text(change, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: up ? AppColors.coral : AppColors.blue))],
        ]),
      );
}

class _FactorTile extends StatelessWidget {
  const _FactorTile(this.factor);
  final MarketFactor factor;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.lightCoral, borderRadius: BorderRadius.circular(20)), child: Text(factor.status, style: const TextStyle(fontSize: 8, color: AppColors.coral, fontWeight: FontWeight.w800))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(factor.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(factor.detail, style: const TextStyle(fontSize: 10.5, height: 1.5, color: AppColors.secondary)),if(factor.source.isNotEmpty)...[const SizedBox(height:4),Text('${factor.source}${factor.sourceDate.isEmpty?'':' · ${factor.sourceDate}'}',style:const TextStyle(fontSize:8.5,color:AppColors.secondary))]])),
        ]),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(fontSize: 10.5, height: 1.5, color: AppColors.secondary)));
}
