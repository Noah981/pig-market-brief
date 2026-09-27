import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../theme/app_theme.dart';
import '../data/market_repository.dart';
import '../models/dashboard_models.dart';
import '../settings/display_settings.dart';
import 'market_detail_pages.dart';
import '../settings/farm_location_settings.dart';
import '../widgets/farm_location_picker.dart';
import 'benefit_page.dart';

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.title, required this.subtitle, required this.child,this.help,this.onRefresh});
  final String title;
  final String subtitle;
  final Widget child;
  final VoidCallback? help;
  final Future<void> Function()? onRefresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: RefreshIndicator(color:AppColors.coral,onRefresh:onRefresh??()async{},notificationPredicate:(_)=>onRefresh!=null,child:CustomScrollView(physics:const AlwaysScrollableScrollPhysics(),slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                sliver: SliverList.list(children: [
                  if (title.isNotEmpty) Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(title, style: const TextStyle(fontSize: 30, height: 1.08, fontWeight: FontWeight.w900,letterSpacing:-1.3))),if(help!=null)IconButton(onPressed:help,icon:const Icon(Icons.help_outline,size:26),tooltip:'도움말',visualDensity:VisualDensity.compact)]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 15, height: 1.35, color: AppColors.secondary)),
                  ],
                  if (title.isNotEmpty) const SizedBox(height: 14),
                  child,
                ]),
              ),
            ])),
          ),
        ),
      ),
    );
  }
}

class MarketOverviewPage extends StatelessWidget {
  const MarketOverviewPage({super.key,this.snapshot,this.commodities=const [],this.analysis,this.onRefresh});
  final MarketSnapshot? snapshot;
  final List<Commodity> commodities;
  final MarketAnalysis? analysis;
  final Future<void> Function()? onRefresh;
  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MarketTile(Icons.savings_rounded,'전국 돈가',snapshot==null?'확인 중':_number(snapshot!.price),snapshot==null?'':'원/kg',_change(snapshot),(snapshot?.change??-1)>=0,tileKey:const ValueKey('market_pig'),onTap:()=>_openPig(context)),
      _commodityTile('🌽','corn',context),
      _commodityTile('🫘','soybean_meal',context),
      _commodityTile('＄','usd_krw',context),
    ];
    final summaries = [
      ('전국 돈가',snapshot==null?'확인 중':'${_number(snapshot!.price)} 원/kg',_change(snapshot),(snapshot?.change??0)>=0),
      for(final id in const ['corn','soybean_meal','wti','usd_krw']) if(_find(id)!=null)
        (_find(id)!.name.replaceAll('\n',' '),'${_find(id)!.value} ${_find(id)!.unit}',_find(id)!.change==null?'확인 중':'${_find(id)!.change!>=0?'▲':'▼'} ${_find(id)!.change!.abs().toStringAsFixed(1)}%',(_find(id)!.change??0)>=0),
    ];
    return PageShell(
      title: '시황', subtitle: '지금, 시장의 흐름을 한눈에 확인하세요',onRefresh:onRefresh,help:()=>showDialog(context:context,builder:(context)=>AlertDialog(title:const Text('시황 도움말'),content:const Text('각 가격은 표시된 공식 기준일의 값입니다. 주말·공휴일·미발표일에는 마지막 정상 발표값을 유지합니다. 상승은 분홍색, 하락은 파란색이며 데이터 기준일과 앱 조회 시각은 서로 다를 수 있습니다.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('확인'))])),
      child: Column(children: [
        const _MarketPeriodTabs(),
        const SizedBox(height:8),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 7, crossAxisSpacing: 7, childAspectRatio: 1.72,
          children: tiles,
        ),
        const SizedBox(height: 7),
        SizedBox(height:74,child:_commodityTile('oil','wti',context,wide:true)),
        const SizedBox(height: 10),
        Container(padding:const EdgeInsets.fromLTRB(12,10,12,4),decoration:appCard(radius:18),child:Column(children:[
          const Row(children:[Expanded(child:_SectionTitle('시황 요약 (오늘)')),Text('전체 보기  ›',style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:AppColors.coral))]),
          const SizedBox(height:2),
          ...summaries.map((x) => _SummaryRow(x.$1, x.$2, x.$3,x.$4)),
        ])),
        const SizedBox(height:10),
        _MarketRecentTrend(snapshot:snapshot,commodities:commodities),
      ]),
    );
  }
  String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
  String _change(MarketSnapshot? s){if(s==null)return '공식 데이터 연결 중';return '${s.change>=0?'▲':'▼'} ${s.change.abs()}원 (${s.changePct.toStringAsFixed(2)}%)';}
  Commodity? _find(String id){for(final item in commodities){if(item.id==id)return item;}return null;}
  Widget _commodityTile(String token,String id,BuildContext context,{bool wide=false}){final item=_find(id);final label={'corn':'옥수수','soybean_meal':'대두박','usd_krw':'달러 환율','wti':'국제 유가 (WTI)'}[id]!;final icon={'corn':Icons.eco_rounded,'soybean_meal':Icons.grain_rounded,'usd_krw':Icons.attach_money_rounded,'wti':Icons.oil_barrel_rounded}[id]!;return _MarketTile(icon,label,item?.value??'연결 대기',item?.unit??'',item?.change==null?'공식 데이터 확인 중':'${item!.change!>=0?'▲':'▼'} ${item.change!.abs().toStringAsFixed(1)}%',(item?.change??0)>=0,kind:id,wide:wide,tileKey:ValueKey('market_$id'),onTap:item==null?null:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:item))));}
  void _openPig(BuildContext context)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PigPriceDetailPage(snapshot:snapshot,analysis:analysis)));
}

class _MarketPeriodTabs extends StatefulWidget{const _MarketPeriodTabs();@override State<_MarketPeriodTabs> createState()=>_MarketPeriodTabsState();}
class _MarketPeriodTabsState extends State<_MarketPeriodTabs>{int selected=0;@override Widget build(BuildContext context)=>Container(height:40,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xFFF1F2F5),borderRadius:BorderRadius.circular(12)),child:Row(children:List.generate(4,(i)=>Expanded(child:InkWell(onTap:()=>setState(()=>selected=i),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:selected==i?AppColors.coral:Colors.transparent,borderRadius:BorderRadius.circular(9)),child:Text(const ['오늘','주간','월간','3년 비교'][i],style:TextStyle(fontSize:12,fontWeight:FontWeight.w800,color:selected==i?Colors.white:AppColors.secondary))))))));}

class _MarketRecentTrend extends StatefulWidget{const _MarketRecentTrend({this.snapshot,required this.commodities});final MarketSnapshot? snapshot;final List<Commodity> commodities;@override State<_MarketRecentTrend> createState()=>_MarketRecentTrendState();}
class _MarketRecentTrendState extends State<_MarketRecentTrend>{String selected='pig';@override Widget build(BuildContext context){final choices=[('pig','전국 돈가'),('corn','옥수수'),('soybean_meal','대두박'),('wti','국제유가'),('usd_krw','환율')];final points=selected=='pig'?(widget.snapshot?.history.where((x)=>x.resolution!='month').map((x)=>(x.date,x.value)).toList()??[]):(widget.commodities.where((x)=>x.id==selected).firstOrNull?.history.map((x)=>(x.date,x.value)).toList()??[]);final data=points.length>7?points.sublist(points.length-7):points;return Container(height:145,padding:const EdgeInsets.fromLTRB(12,8,12,6),decoration:appCard(radius:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const Expanded(child:_SectionTitle('최근 7일 추이')),Wrap(spacing:3,children:choices.take(4).map((x)=>ChoiceChip(label:Text(x.$2),selected:selected==x.$1,onSelected:(_)=>setState(()=>selected=x.$1),selectedColor:AppColors.coral,showCheckmark:false,visualDensity:VisualDensity.compact,labelPadding:const EdgeInsets.symmetric(horizontal:3),labelStyle:TextStyle(fontSize:8,fontWeight:FontWeight.w700,color:selected==x.$1?Colors.white:AppColors.secondary))).toList())]),const SizedBox(height:3),Expanded(child:data.length<2?const Center(child:Text('해당 기간의 실제 데이터가 없습니다.',style:TextStyle(fontSize:11,color:AppColors.secondary))):LineChart(LineChartData(borderData:FlBorderData(show:false),minX:0,maxX:(data.length-1).toDouble(),gridData:FlGridData(show:true,drawVerticalLine:true,getDrawingHorizontalLine:(_)=>const FlLine(color:AppColors.divider,strokeWidth:1),getDrawingVerticalLine:(_)=>const FlLine(color:AppColors.divider,strokeWidth:.6)),titlesData:FlTitlesData(topTitles:const AxisTitles(),rightTitles:const AxisTitles(),leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:34,getTitlesWidget:(v,meta)=>Text(v>=1000?v.toStringAsFixed(0):v.toStringAsFixed(1),style:const TextStyle(fontSize:8,color:AppColors.secondary)))),bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:18,interval:1,getTitlesWidget:(v,meta){final i=v.round();if(i<0||i>=data.length)return const SizedBox();final d=data[i].$1;return Padding(padding:const EdgeInsets.only(top:3),child:Text(d.length>=8?'${d.substring(4,6)}/${d.substring(6,8)}':d,style:const TextStyle(fontSize:8,color:AppColors.secondary)));}))),lineTouchData:const LineTouchData(enabled:true),lineBarsData:[LineChartBarData(spots:List.generate(data.length,(i)=>FlSpot(i.toDouble(),data[i].$2)),color:AppColors.coral,barWidth:2.5,isCurved:true,dotData:const FlDotData(show:true),belowBarData:BarAreaData(show:true,gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[AppColors.lightCoral,Colors.transparent])))]))) ]));}}

class _MarketTile extends StatelessWidget {
  const _MarketTile(this.icon, this.name, this.value, this.unit, this.change, this.up, {this.kind='pig',this.wide = false,this.onTap,this.tileKey});
  final IconData icon; final String name, value, unit, change,kind;
  final bool up, wide;
  final VoidCallback? onTap;
  final Key? tileKey;
  @override
  Widget build(BuildContext context) => InkWell(key:tileKey,borderRadius:BorderRadius.circular(18),onTap:onTap,child:Container(
    padding: EdgeInsets.symmetric(horizontal:wide?16:12,vertical:7), decoration: appCard(color:_background(),radius: 18),
    child: Row(children: [
      Container(width:wide?48:44,height:wide?48:44,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.82),shape:BoxShape.circle),child:Icon(icon,color:_iconColor(),size:wide?32:30)),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('$name  ›',maxLines:1,overflow:TextOverflow.ellipsis, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900,letterSpacing:-.3)),
        FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child: Text('$value $unit',maxLines:1,style: const TextStyle(fontSize: 18.5, fontWeight: FontWeight.w900,letterSpacing:-.7))),
        Text(change,maxLines:1,overflow:TextOverflow.ellipsis, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: up ? AppColors.coral : AppColors.blue)),
      ])),
    ]),
  ));
  Color _background()=>switch(kind){'corn'=>const Color(0xFFFFFEF2),'usd_krw'=>const Color(0xFFF0FAFF),'wti'=>const Color(0xFFFFF5FC),_=>const Color(0xFFFFF8FB)};
  Color _iconColor()=>switch(kind){'corn'=>const Color(0xFFE9A600),'usd_krw'=>AppColors.blue,'wti'=>const Color(0xFF3292D0),_=>AppColors.coral};
}

class MorePage extends StatefulWidget {
  const MorePage({super.key});
  @override State<MorePage> createState()=>_MorePageState();
}
class _MorePageState extends State<MorePage>{
  static const items = [
    ('내 농장', '등록된 농장 정보 관리', Icons.home_work_outlined),
    ('인증 정보', '깨끗한 축산농장 · 저탄소 · HACCP 등', Icons.health_and_safety_outlined),
    ('정부·지자체 지원사업', '내 지역 맞춤 지원사업 확인', Icons.account_balance_outlined),
    ('알림 설정', '돈가 · 질병 · 주문 · 지원사업 등', Icons.notifications_outlined),
    ('글자 크기', '작게 · 기본 · 크게 · 매우 크게', Icons.text_fields),
    ('지역 설정', '', Icons.location_on_outlined),
    ('데이터 출처', '정보 제공 기관 안내', Icons.info_outline),
    ('공지사항', '앱 소식 및 업데이트', Icons.campaign_outlined),
    ('이용약관 / 개인정보처리방침', '', Icons.article_outlined),
    ('앱 정보', '버전 1.4.0', Icons.info),
  ];
  @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_changed);FarmLocationSettings.instance.load();}
  @override void dispose(){FarmLocationSettings.instance.removeListener(_changed);super.dispose();}
  void _changed(){if(mounted)setState((){});}
  @override
  Widget build(BuildContext context) => PageShell(
    title: '', subtitle: '',
    child: Column(children: [
      ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(radius:24,backgroundColor:AppColors.lightCoral,child:Icon(Icons.person,color:Color(0xFF4B5A70))),title:const Text('돈돈해님',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),subtitle:const Text('항상 감사합니다.',style:TextStyle(fontSize:10)),trailing:const Icon(Icons.settings_outlined),onTap:()=>_textSize(context)),
      const Divider(),
      ...items.map((x){final subtitle=x.$1=='지역 설정'?'내 지역: ${FarmLocationSettings.instance.location.label}':x.$2;return ListTile(minTileHeight:57,contentPadding:EdgeInsets.zero,leading:Icon(x.$3,color:const Color(0xFF4B5A70),size:21),title:Text(x.$1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),subtitle:subtitle.isEmpty?null:Text(subtitle,style:const TextStyle(fontSize:9,color:AppColors.secondary)),trailing:const Icon(Icons.chevron_right,size:18),onTap:()=>_open(context,x.$1));}),
    ]),
  );

  void _open(BuildContext context,String item){if(item=='글자 크기'){_textSize(context);return;}if(item=='지역 설정'||item=='내 농장'){showFarmLocationPicker(context);return;}if(item=='정부·지자체 지원사업'){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const BenefitPage()));return;}ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$item 화면은 공식 데이터 연결을 준비하고 있습니다.')));}

  Future<void> _textSize(BuildContext context)async{
    final settings=DisplaySettings.instance;
    const choices=[(.85,'작게'),(1.0,'기본'),(1.15,'크게'),(1.3,'매우 크게')];
    await showModalBottomSheet(context:context,showDragHandle:true,isScrollControlled:true,builder:(context)=>SafeArea(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const ListTile(title:Text('글자 크기',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('선택하면 앱 전체 글자에 바로 적용됩니다. 큰글씨 모드는 홈 상단에서 별도로 켤 수 있습니다.')),...choices.map((x)=>RadioListTile<double>(value:x.$1,groupValue:settings.selectedTextScale,title:Text(x.$2,style:TextStyle(fontSize:14*x.$1,fontWeight:FontWeight.w800)),onChanged:(value)async{if(value==null)return;Navigator.pop(context);await settings.setTextScale(value);})),const SizedBox(height:8)]))));
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.name, this.value, this.detail,this.up); final String name, value, detail;final bool up;
  @override Widget build(BuildContext context) => Container(height: 27, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))), child: Row(children: [Expanded(flex:4,child:Text(name,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))),Expanded(flex:5,child:Text(value,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))),Expanded(flex:4,child:Text(detail,textAlign:TextAlign.right,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:up?AppColors.coral:AppColors.blue)))]));
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text); final String text;
  @override Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)));
}
