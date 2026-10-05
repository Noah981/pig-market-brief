import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../widgets/commodity_quote_card.dart';
import '../data/market_repository.dart';
import '../models/dashboard_models.dart';
import '../settings/display_settings.dart';
import 'market_detail_pages.dart';
import '../settings/farm_location_settings.dart';
import '../widgets/farm_location_picker.dart';
import 'benefit_page.dart';
import 'disease_page.dart' show DiseaseNotificationSettingsPage;

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.title, required this.subtitle, required this.child,this.help,this.onRefresh,this.compactHeader=false});
  final bool compactHeader;
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
                padding: EdgeInsets.fromLTRB(16, compactHeader?10:14, 16, 20),
                sliver: SliverList.list(children: [
                  if (title.isNotEmpty) Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(child:Text(title, style: const TextStyle(fontSize: 30, height: 1.08, fontWeight: FontWeight.w900,letterSpacing:-1.3))),if(help!=null)IconButton(onPressed:help,icon:const Icon(Icons.help_outline,size:26),tooltip:'도움말',constraints:compactHeader?const BoxConstraints.tightFor(width:32,height:32):null,padding:compactHeader?EdgeInsets.zero:null,visualDensity:VisualDensity.compact)]),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: TextStyle(fontSize: compactHeader?12:15, height: 1.35, color: AppColors.secondary)),
                  ],
                  if (title.isNotEmpty) SizedBox(height:compactHeader?10:14),
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
      _MarketTile(Icons.savings_rounded,'전국 돈가',snapshot==null?'확인 중':_number(snapshot!.price),snapshot==null?'':'원/kg',_change(snapshot),(snapshot?.change??-1)>=0,basis:snapshot==null?'공식 자료 확인 필요':'${snapshot!.date.substring(0,4)}.${snapshot!.date.substring(4,6)}.${snapshot!.date.substring(6,8)} 기준',tileKey:const ValueKey('market_pig'),onTap:()=>_openPig(context)),
      _commodityTile('🌽','corn',context),
      _commodityTile('🫘','soybean_meal',context),
      _commodityTile('grain','wheat',context),
      _commodityTile('soy','soybean',context),
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
        const Align(alignment:Alignment.centerLeft,child:Text('원료는 월평균 · 돈가와 유가는 공표일 기준',style:TextStyle(fontSize:11,color:AppColors.secondary))),
        const SizedBox(height:8),
        if(MediaQuery.textScalerOf(context).scale(1)>1.3)Column(children:tiles.map((tile)=>Padding(padding:const EdgeInsets.only(bottom:7),child:SizedBox(width:double.infinity,child:tile))).toList())else GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:MediaQuery.textScalerOf(context).scale(1)>1.3?1:2,mainAxisSpacing:7,crossAxisSpacing:7,mainAxisExtent:220.0 * MediaQuery.textScalerOf(context).scale(1).clamp(1,1.8)),
          children: tiles,
        ),
        const SizedBox(height: 7),
        _commodityTile('oil','wti',context,wide:true),
        const SizedBox(height: 10),
        Container(padding:const EdgeInsets.fromLTRB(12,10,12,4),decoration:appCard(radius:18),child:Column(children:[
          const Row(children:[Expanded(child:_SectionTitle('공식 시황 요약'))]),
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
  Widget _commodityTile(String token,String id,BuildContext context,{bool wide=false}){
    final item=_find(id);if(item==null)return const SizedBox.shrink();
    return CommodityQuoteCard(key:ValueKey('market_$id'),item:item,detail:wide,compact:MediaQuery.textScalerOf(context).scale(1)>1.3,onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:item))));
  }
  void _openPig(BuildContext context)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PigPriceDetailPage(snapshot:snapshot,analysis:analysis)));
}

class _MarketRecentTrend extends StatefulWidget{const _MarketRecentTrend({this.snapshot,required this.commodities});final MarketSnapshot? snapshot;final List<Commodity> commodities;@override State<_MarketRecentTrend> createState()=>_MarketRecentTrendState();}
class _MarketRecentTrendState extends State<_MarketRecentTrend>{String selected='pig';@override Widget build(BuildContext context){final choices=[('pig','전국 돈가'),('corn','옥수수'),('soybean_meal','대두박'),('wti','국제유가'),('usd_krw','환율')];final points=selected=='pig'?(widget.snapshot?.history.where((x)=>x.resolution!='month').map((x)=>(x.date,x.value)).toList()??[]):(widget.commodities.where((x)=>x.id==selected).firstOrNull?.history.map((x)=>(x.date,x.value)).toList()??[]);final data=points.length>7?points.sublist(points.length-7):points;return Container(height:145 * MediaQuery.textScalerOf(context).scale(1).clamp(1,1.8),padding:const EdgeInsets.fromLTRB(12,8,12,6),decoration:appCard(radius:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Wrap(spacing:8,runSpacing:4,crossAxisAlignment:WrapCrossAlignment.center,children:[const _SectionTitle('최근 공표 추이'),Wrap(spacing:3,children:choices.take(4).map((x)=>ChoiceChip(label:Text(x.$2),selected:selected==x.$1,onSelected:(_)=>setState(()=>selected=x.$1),selectedColor:AppColors.coral,showCheckmark:false,visualDensity:VisualDensity.compact,labelPadding:const EdgeInsets.symmetric(horizontal:3),labelStyle:TextStyle(fontSize:8,fontWeight:FontWeight.w700,color:selected==x.$1?Colors.white:AppColors.secondary))).toList())]),const SizedBox(height:3),Expanded(child:data.length<2?const Center(child:Text('해당 기간의 실제 데이터가 없습니다.',style:TextStyle(fontSize:11,color:AppColors.secondary))):LineChart(LineChartData(borderData:FlBorderData(show:false),minX:0,maxX:(data.length-1).toDouble(),gridData:FlGridData(show:true,drawVerticalLine:true,getDrawingHorizontalLine:(_)=>const FlLine(color:AppColors.divider,strokeWidth:1),getDrawingVerticalLine:(_)=>const FlLine(color:AppColors.divider,strokeWidth:.6)),titlesData:FlTitlesData(topTitles:const AxisTitles(),rightTitles:const AxisTitles(),leftTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:34,getTitlesWidget:(v,meta)=>Text(v>=1000?v.toStringAsFixed(0):v.toStringAsFixed(1),style:const TextStyle(fontSize:8,color:AppColors.secondary)))),bottomTitles:AxisTitles(sideTitles:SideTitles(showTitles:true,reservedSize:18,interval:1,getTitlesWidget:(v,meta){final i=v.round();if(i<0||i>=data.length)return const SizedBox();final d=data[i].$1;return Padding(padding:const EdgeInsets.only(top:3),child:Text(d.length>=8?'${d.replaceAll('-','').substring(4,6)}/${d.replaceAll('-','').substring(6,8)}':d,style:const TextStyle(fontSize:8,color:AppColors.secondary)));}))),lineTouchData:const LineTouchData(enabled:true),lineBarsData:[LineChartBarData(spots:List.generate(data.length,(i)=>FlSpot(i.toDouble(),data[i].$2)),color:AppColors.coral,barWidth:2.5,isCurved:true,dotData:const FlDotData(show:true),belowBarData:BarAreaData(show:true,gradient:LinearGradient(begin:Alignment.topCenter,end:Alignment.bottomCenter,colors:[AppColors.lightCoral,Colors.transparent])))]))) ]));}}

class _MarketTile extends StatelessWidget {
  const _MarketTile(this.icon,this.name,this.value,this.unit,this.change,this.up,{this.basis='',this.onTap,this.tileKey});
  final IconData icon;final String name,value,unit,change,basis;final bool up;final VoidCallback? onTap;final Key? tileKey;
  @override Widget build(BuildContext context)=>Material(color:const Color(0xFFFFF7FA),borderRadius:BorderRadius.circular(20),child:InkWell(key:tileKey,onTap:onTap,borderRadius:BorderRadius.circular(20),child:Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(borderRadius:BorderRadius.circular(20),border:Border.all(color:AppColors.coral.withValues(alpha:.15))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(children:[Icon(icon,size:25,color:AppColors.coral),const SizedBox(width:7),Expanded(child:Text(name,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w800))),const Icon(Icons.chevron_right,size:17,color:AppColors.secondary)]),
    const SizedBox(height:13),FittedBox(fit:BoxFit.scaleDown,child:Text(value,style:const TextStyle(fontSize:27,fontWeight:FontWeight.w900,letterSpacing:-1))),
    Text(unit,style:const TextStyle(fontSize:10,color:AppColors.secondary)),const SizedBox(height:9),Text(change,style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:up?AppColors.coral:AppColors.blue)),const SizedBox(height:12),
    Text(basis,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:AppColors.coral)),const SizedBox(height:4),const Text('축산유통정보 다봄',style:TextStyle(fontSize:9,color:AppColors.secondary)),
  ]))));
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
    ('글자 크기', '기본 · 크게 · 매우 크게', Icons.text_fields),
    ('지역 설정', '', Icons.location_on_outlined),
    ('데이터 출처', '정보 제공 기관 안내', Icons.info_outline),
    ('공지사항', '앱 소식 및 업데이트', Icons.campaign_outlined),
    ('이용약관 / 개인정보처리방침', '', Icons.article_outlined),
    ('앱 정보', '버전 1.8.7', Icons.info),
  ];
  @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_changed);FarmLocationSettings.instance.load();}
  @override void dispose(){FarmLocationSettings.instance.removeListener(_changed);super.dispose();}
  void _changed(){if(mounted)setState((){});}
  @override
  Widget build(BuildContext context) => PageShell(
    title: '', subtitle: '',
    child: Column(children: [
      const ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(radius:25,backgroundColor:AppColors.lightCoral,child:Icon(Icons.pets_rounded,color:AppColors.coral)),title:Text('돈돈해',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),subtitle:Text('로그인 없이 누구나 사용할 수 있습니다.',style:TextStyle(fontSize:11,fontWeight:FontWeight.w600,color:AppColors.secondary))),
      const Divider(height:22),
      ...items.map((x){final subtitle=x.$1=='지역 설정'?'내 지역: ${FarmLocationSettings.instance.location.label}':x.$2;return InkWell(onTap:()=>_open(context,x.$1),borderRadius:BorderRadius.circular(12),child:Padding(padding:const EdgeInsets.symmetric(vertical:9),child:Row(children:[SizedBox(width:42,child:Icon(x.$3,color:const Color(0xFF52627A),size:23)),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.$1,style:const TextStyle(fontSize:14.5,fontWeight:FontWeight.w900,letterSpacing:-.2)),if(subtitle.isNotEmpty)Text(subtitle,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w600,color:AppColors.secondary))])),const Icon(Icons.chevron_right_rounded,size:21,color:AppColors.secondary)])));}),
      const SizedBox(height:16),
      const Text('© 2026 신보석. All rights reserved.',style:TextStyle(fontSize:9.5,fontWeight:FontWeight.w700,color:AppColors.secondary)),
    ]),
  );

  void _open(BuildContext context,String item){
    if(item=='글자 크기'){_textSize(context);return;}
    if(item=='지역 설정'||item=='내 농장'){showFarmLocationPicker(context);return;}
    if(item=='정부·지자체 지원사업'){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const BenefitPage()));return;}
    final page=switch(item){
      '인증 정보'=>const _CertificationSettingsPage(),
      '알림 설정'=>const _NotificationHubPage(),
      '데이터 출처'=>const _InfoListPage(title:'데이터 출처',rows:[('전국·등급별 돈가 및 경락 현황','축산물품질평가원 · 축산유통정보 다봄'),('법정가축전염병','농림축산식품 공공데이터 · 농림축산검역본부'),('날씨','기상청 단기예보 및 초단기실황'),('USD/KRW','한국은행 ECOS'),('국제 원료·유가','각 상세화면에 표시된 원자료 제공처')]),
      '공지사항'=>const _InfoListPage(title:'공지사항',rows:[('질병 정보 기준 개선','기사 게시일을 발생일로 사용하지 않고 공식 API의 실제 발생일만 표시합니다.'),('데이터 원칙','예시값이나 임의 생성값 없이 마지막 정상 데이터와 상태를 구분합니다.')]),
      '이용약관 / 개인정보처리방침'=>const _TermsPage(),
      '앱 정보'=>const _InfoListPage(title:'앱 정보',rows:[('돈돈해','양돈의 오늘을 든든하게'),('소유자·개발 책임자','신보석'),('버전','1.4.0'),('이용 방식','회원가입·로그인 없이 이용')]),
      _=>null,
    };
    if(page!=null)Navigator.of(context).push(MaterialPageRoute(builder:(_)=>page));
  }

  Future<void> _textSize(BuildContext context)async{
    final settings=DisplaySettings.instance;
    const choices=[(1.15,'기본'),(1.3,'크게'),(1.45,'매우 크게')];
    await showModalBottomSheet(context:context,showDragHandle:true,isScrollControlled:true,builder:(context)=>SafeArea(child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[const ListTile(title:Text('글자 크기',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('선택하면 앱 전체 글자에 바로 적용됩니다. 큰글씨 모드는 홈 상단에서 별도로 켤 수 있습니다.')),...choices.map((x)=>RadioListTile<double>(value:x.$1,groupValue:settings.selectedTextScale,title:Text(x.$2,style:TextStyle(fontSize:14*x.$1,fontWeight:FontWeight.w800)),onChanged:(value)async{if(value==null)return;Navigator.pop(context);await settings.setTextScale(value);})),const SizedBox(height:8)]))));
  }
}

class _PlainSettingsScaffold extends StatelessWidget{
  const _PlainSettingsScaffold({required this.title,required this.child});final String title;final Widget child;
  @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,surfaceTintColor:Colors.transparent,title:Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900))),body:SafeArea(child:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,28),children:[child])));
}

class _InfoListPage extends StatelessWidget{
  const _InfoListPage({required this.title,required this.rows});final String title;final List<(String,String)> rows;
  @override Widget build(BuildContext context)=>_PlainSettingsScaffold(title:title,child:Column(children:rows.map((x)=>Padding(padding:const EdgeInsets.symmetric(vertical:14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Expanded(flex:4,child:Text(x.$1,style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900))),const SizedBox(width:14),Expanded(flex:6,child:Text(x.$2,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w600,height:1.55,color:AppColors.secondary)))]))).toList()));
}

class _CertificationSettingsPage extends StatefulWidget{const _CertificationSettingsPage();@override State<_CertificationSettingsPage> createState()=>_CertificationSettingsPageState();}
class _CertificationSettingsPageState extends State<_CertificationSettingsPage>{final values=<String,bool>{};static const names=['깨끗한 축산농장','저탄소 축산물 인증','HACCP','무항생제','동물복지','유기축산'];@override void initState(){super.initState();_load();}Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){for(final x in names){values[x]=p.getBool('cert_$x')??false;}});}Future<void> _set(String key,bool value)async{setState(()=>values[key]=value);await (await SharedPreferences.getInstance()).setBool('cert_$key',value);}@override Widget build(BuildContext context)=>_PlainSettingsScaffold(title:'인증 정보',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('내 농장에 해당하는 인증을 선택하세요.',style:TextStyle(fontSize:12,fontWeight:FontWeight.w700,color:AppColors.secondary)),const SizedBox(height:10),...names.map((x)=>SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(x,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)),value:values[x]??false,onChanged:(v)=>_set(x,v),activeColor:AppColors.coral))]));}

class _NotificationHubPage extends StatefulWidget{const _NotificationHubPage();@override State<_NotificationHubPage> createState()=>_NotificationHubPageState();}
class _NotificationHubPageState extends State<_NotificationHubPage>{bool market=true,weather=true,benefit=true;@override void initState(){super.initState();_load();}Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){market=p.getBool('notify_market')??true;weather=p.getBool('notify_weather')??true;benefit=p.getBool('notify_benefit')??true;});}Future<void> _save(String key,bool value)async{await (await SharedPreferences.getInstance()).setBool(key,value);}@override Widget build(BuildContext context)=>_PlainSettingsScaffold(title:'알림 설정',child:Column(children:[_toggle('돈가·시황','공식 새 가격이 발표될 때',market,(v){setState(()=>market=v);_save('notify_market',v);}),_toggle('기상 위험','폭염·한파·호우 등 농장 관리 주의',weather,(v){setState(()=>weather=v);_save('notify_weather',v);}),_toggle('지원사업','설정 지역의 신규 지원사업',benefit,(v){setState(()=>benefit=v);_save('notify_benefit',v);}),ListTile(contentPadding:EdgeInsets.zero,title:const Text('질병 알림 상세',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),subtitle:const Text('질병·거리 LEVEL별 알림 설정',style:TextStyle(fontSize:10.5,fontWeight:FontWeight.w600)),trailing:const Icon(Icons.chevron_right),onTap:()=>Navigator.push(context,MaterialPageRoute(builder:(_)=>const DiseaseNotificationSettingsPage()))) ]));Widget _toggle(String title,String sub,bool value,ValueChanged<bool> changed)=>SwitchListTile(contentPadding:EdgeInsets.zero,title:Text(title,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900)),subtitle:Text(sub,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w600)),value:value,onChanged:changed,activeColor:AppColors.coral);}

class _TermsPage extends StatelessWidget{const _TermsPage();@override Widget build(BuildContext context)=>const _PlainSettingsScaffold(title:'이용약관·개인정보',child:Text('''돈돈해 이용약관\n\n1. 소유권\n돈돈해의 자체 개발 소스코드, 화면 구성, 명칭, 로고 및 편집 저작물의 권리는 신보석에게 있습니다. 공공데이터, 오픈소스 및 제3자 자료의 권리는 각 원권리자에게 있습니다.\n\n2. 이용 허락\n이 앱은 로그인 없이 누구나 개인적인 정보 확인 목적으로 사용할 수 있습니다. 앱의 복제, 변조, 재배포, 역분석, 명칭·디자인 도용 또는 소유권 표시 제거는 사전 서면 허락 없이 허용되지 않습니다.\n\n3. 테스트·배포\n비공개 시험판의 설치·테스트·재배포는 소유자 신보석의 승인을 받은 경우에만 허용됩니다. 공식 배포본 여부는 소유자가 제공한 경로로 확인해야 합니다.\n\n4. 데이터와 책임\n시황·날씨·질병 정보는 각 제공기관의 발표 시차, 정정 또는 장애가 있을 수 있습니다. 질병 정보는 방역기관의 공식 발표와 현장 지침을 우선하며, 앱 정보만으로 진단하거나 방역조치를 결정해서는 안 됩니다.\n\n개인정보처리방침\n\n돈돈해는 회원가입과 로그인을 요구하지 않습니다. 서버에 사용자 계정정보를 수집하지 않으며, 지역·알림·농장 설정은 기능 제공을 위해 기기에 저장됩니다. GPS는 날씨·거리 계산을 위해 사용되며 별도 서버 계정에 저장하지 않습니다. Android 권한은 기기 설정에서 언제든 철회할 수 있습니다.\n\n시행일: 2026년 9월 28일\n소유자: 신보석\n© 2026 신보석. All rights reserved.''',style:TextStyle(fontSize:12,fontWeight:FontWeight.w600,height:1.7,color:AppColors.text)));}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.name, this.value, this.detail,this.up); final String name, value, detail;final bool up;
  @override Widget build(BuildContext context) => Container(height: 27, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))), child: Row(children: [Expanded(flex:4,child:Text(name,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w700))),Expanded(flex:5,child:Text(value,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))),Expanded(flex:4,child:Text(detail,textAlign:TextAlign.right,style:TextStyle(fontSize:10,fontWeight:FontWeight.w700,color:up?AppColors.coral:AppColors.blue)))]));
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text); final String text;
  @override Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)));
}
