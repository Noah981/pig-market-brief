import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_theme.dart';
import '../data/market_repository.dart';
import '../models/dashboard_models.dart';
import '../settings/display_settings.dart';
import 'market_detail_pages.dart';
import '../settings/farm_location_settings.dart';
import '../widgets/farm_location_picker.dart';
import 'benefit_page.dart';

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.background,
      child: SafeArea(
        bottom: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: CustomScrollView(slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
                sliver: SliverList.list(children: [
                  if (title.isNotEmpty) Text(title, style: const TextStyle(fontSize: 22, height: 1.18, fontWeight: FontWeight.w900)),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(fontSize: 11, height: 1.35, color: AppColors.secondary)),
                  ],
                  if (title.isNotEmpty) const SizedBox(height: 16),
                  child,
                ]),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

class MarketOverviewPage extends StatelessWidget {
  const MarketOverviewPage({super.key,this.snapshot,this.commodities=const [],this.analysis});
  final MarketSnapshot? snapshot;
  final List<Commodity> commodities;
  final MarketAnalysis? analysis;
  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MarketTile('🐷','전국 돈가',snapshot==null?'확인 중':_number(snapshot!.price),snapshot==null?'':'원/kg',_change(snapshot),(snapshot?.change??-1)>=0,onTap:()=>_openPig(context)),
      _commodityTile('🌽','corn',context),
      _commodityTile('🫘','soybean_meal',context),
      _commodityTile('＄','usd_krw',context),
    ];
    final summaries = [
      ('돈가', snapshot==null?'확인 중':(snapshot!.change>=0?'상승':'하락'), _change(snapshot)),
      ...commodities.map((x)=>(x.name.replaceAll('\n',' '),x.change==null?'확인 중':(x.change!>=0?'상승':'하락'),x.change==null?'공식 데이터 연결 대기':'전일 대비 ${x.change!.abs().toStringAsFixed(1)}%')),
    ];
    return PageShell(
      title: '시황', subtitle: '지금, 시장의 흐름을 한눈에',
      child: Column(children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.38,
          children: tiles,
        ),
        const SizedBox(height: 10),
        SizedBox(height:104,child:_commodityTile('🛢️','wti',context,wide:true)),
        const SizedBox(height: 18),
        const _SectionTitle('시황 요약 (오늘)'),
        ...summaries.map((x) => _SummaryRow(x.$1, x.$2, x.$3)),
        const SizedBox(height:18),
        const _SectionTitle('국제정세 해석'),
        const SizedBox(height:7),
        ...commodities.map((x)=>InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:x))),child:Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:appCard(radius:14),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(x.change==null?Icons.schedule:x.change!>=0?Icons.north_east:Icons.south_east,color:x.change==null?AppColors.secondary:x.change!>=0?AppColors.coral:AppColors.blue,size:19),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.name.replaceAll('\n',' '),style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w900)),const SizedBox(height:3),Text(_brief(x),style:const TextStyle(fontSize:9.5,height:1.45,color:AppColors.secondary))])),const Icon(Icons.chevron_right,size:17,color:AppColors.secondary)])))),
        const Text('자동 해석은 공식 시계열의 방향과 일반적인 영향 변수를 정리한 것으로, 특정 사건이 가격을 움직였다고 단정하지 않습니다.',style:TextStyle(fontSize:8.5,height:1.4,color:AppColors.secondary)),
      ]),
    );
  }
  String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
  String _change(MarketSnapshot? s){if(s==null)return '공식 데이터 연결 중';return '${s.change>=0?'▲':'▼'} ${s.change.abs()}원 (${s.changePct.toStringAsFixed(2)}%)';}
  Commodity? _find(String id){for(final item in commodities){if(item.id==id)return item;}return null;}
  Widget _commodityTile(String emoji,String id,BuildContext context,{bool wide=false}){final item=_find(id);final label={'corn':'옥수수','soybean_meal':'대두박','usd_krw':'달러 환율','wti':'국제 유가 (WTI)'}[id]!;return _MarketTile(emoji,label,item?.value??'연결 대기',item?.unit??'',item?.change==null?'공식 데이터 확인 중':'${item!.change!>=0?'▲':'▼'} ${item.change!.abs().toStringAsFixed(1)}%',(item?.change??0)>=0,wide:wide,onTap:item==null?null:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>CommodityDetailPage(item:item))));}
  void _openPig(BuildContext context)=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>PigPriceDetailPage(snapshot:snapshot,analysis:analysis)));
  String _brief(Commodity x){
    if(x.change==null)return '공식 발표값을 확인하고 있습니다.';
    final direction=x.change!>=0?'상승':'하락';
    if(x.id=='usd_krw')return '원/달러 환율이 직전 발표 대비 $direction했습니다. 수입 곡물의 원화 환산비용과 함께 확인하세요.';
    if(x.id=='wti')return 'WTI가 직전 발표 대비 $direction했습니다. 운송비·에너지비 영향과 EIA 재고, 산유국 공급을 함께 봅니다.';
    return '${x.frequency=='monthly'?'전월':'직전 발표'} 대비 $direction했습니다. 작황·재고·수출입, 환율과 해상운임을 함께 확인하세요.';
  }
}

class _MarketTile extends StatelessWidget {
  const _MarketTile(this.emoji, this.name, this.value, this.unit, this.change, this.up, {this.wide = false,this.onTap});
  final String emoji, name, value, unit, change;
  final bool up, wide;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(borderRadius:BorderRadius.circular(15),onTap:onTap,child:Container(
    padding: const EdgeInsets.all(13), decoration: appCard(radius: 15),
    child: Row(children: [
      Text(emoji, style: TextStyle(fontSize: wide ? 30 : 25)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        FittedBox(child: Text('$value $unit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        Text(change, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: up ? AppColors.coral : AppColors.blue)),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.coral, size: 17),
    ]),
  ));
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
    ('앱 정보', '버전 1.6.0', Icons.info),
  ];
  @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_changed);FarmLocationSettings.instance.load();}
  @override void dispose(){FarmLocationSettings.instance.removeListener(_changed);super.dispose();}
  void _changed(){if(mounted)setState((){});}
  @override
  Widget build(BuildContext context) => PageShell(
    title: '', subtitle: '',
    child: Column(children: [
      ListTile(contentPadding:EdgeInsets.zero,leading:const CircleAvatar(radius:24,backgroundColor:AppColors.lightCoral,child:Icon(Icons.person,color:Color(0xFF4B5A70))),title:const Text('돈돈해님',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900)),subtitle:const Text('항상 감사합니다.',style:TextStyle(fontSize:10)),trailing:IconButton(icon:const Icon(Icons.settings_outlined),onPressed:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AppSettingsPage()))),onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AppSettingsPage()))),
      const Divider(),
      ...items.map((x){final subtitle=x.$1=='지역 설정'?'내 지역: ${FarmLocationSettings.instance.location.label}':x.$2;return ListTile(minTileHeight:57,contentPadding:EdgeInsets.zero,leading:Icon(x.$3,color:const Color(0xFF4B5A70),size:21),title:Text(x.$1,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),subtitle:subtitle.isEmpty?null:Text(subtitle,style:const TextStyle(fontSize:9,color:AppColors.secondary)),trailing:const Icon(Icons.chevron_right,size:18),onTap:()=>_open(context,x.$1));}),
    ]),
  );

  void _open(BuildContext context,String item){if(item=='글자 크기'){_textSize(context);return;}if(item=='알림 설정'){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const AppSettingsPage()));return;}if(item=='지역 설정'||item=='내 농장'){showFarmLocationPicker(context);return;}if(item=='정부·지자체 지원사업'){Navigator.of(context).push(MaterialPageRoute(builder:(_)=>const BenefitPage()));return;}ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$item 화면은 공식 데이터 연결을 준비하고 있습니다.')));}

  Future<void> _textSize(BuildContext context)async{
    final settings=DisplaySettings.instance;
    const choices=[(.85,'작게'),(1.0,'기본'),(1.15,'크게'),(1.3,'매우 크게')];
    await showModalBottomSheet(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[const ListTile(title:Text('글자 크기',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('선택하면 앱 전체 글자에 바로 적용됩니다. 큰글씨 모드는 홈 상단에서 별도로 켤 수 있습니다.')),...choices.map((x)=>RadioListTile<double>(value:x.$1,groupValue:settings.selectedTextScale,title:Text(x.$2,style:TextStyle(fontSize:14*x.$1,fontWeight:FontWeight.w800)),onChanged:(value)async{if(value==null)return;await settings.setTextScale(value);if(context.mounted)Navigator.pop(context);})),const SizedBox(height:8)])));
  }
}

class AppSettingsPage extends StatefulWidget{const AppSettingsPage({super.key});@override State<AppSettingsPage> createState()=>_AppSettingsPageState();}
class _AppSettingsPageState extends State<AppSettingsPage>{final Map<String,bool> values={'돈가 주요변동':true,'국내 신규질병':true,'내 지역 지원사업':true,'지원사업 마감':true,'인증 신청시기':false,'사료 주문시기':false};
 @override void initState(){super.initState();_load();}
 Future<void> _load()async{final p=await SharedPreferences.getInstance();if(!mounted)return;setState((){for(final k in values.keys)values[k]=p.getBool('notify_$k')??values[k]!;});}
 Future<void> _set(String key,bool value)async{setState(()=>values[key]=value);await (await SharedPreferences.getInstance()).setBool('notify_$key',value);}
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,surfaceTintColor:Colors.transparent,title:const Text('설정',style:TextStyle(fontWeight:FontWeight.w900))),body:ListView(padding:const EdgeInsets.fromLTRB(20,8,20,28),children:[const Text('화면',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:8),Container(decoration:appCard(radius:18),child:ListTile(title:const Text('글자 크기',style:TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(_scaleName(),style:const TextStyle(color:AppColors.secondary)),trailing:const Icon(Icons.chevron_right),onTap:()=>_size(context))),const SizedBox(height:22),const Text('알림',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:8),Container(decoration:appCard(radius:18),child:Column(children:values.entries.map((x)=>SwitchListTile(title:Text(x.key,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w800)),value:x.value,activeTrackColor:AppColors.coral,onChanged:(v)=>_set(x.key,v))).toList()))]));
 String _scaleName(){final x=DisplaySettings.instance.selectedTextScale;return x<=.9?'작게':x<=1.05?'기본':x<=1.2?'크게':'매우 크게';}
 Future<void> _size(BuildContext context)async{const choices=[(.85,'작게'),(1.0,'기본'),(1.15,'크게'),(1.3,'매우 크게')];await showModalBottomSheet(context:context,showDragHandle:true,builder:(sheet)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[const ListTile(title:Text('글자 크기',style:TextStyle(fontWeight:FontWeight.w900))),...choices.map((x)=>RadioListTile<double>(value:x.$1,groupValue:DisplaySettings.instance.selectedTextScale,title:Text(x.$2),onChanged:(v)async{if(v==null)return;await DisplaySettings.instance.setTextScale(v);if(sheet.mounted)Navigator.pop(sheet);if(mounted)setState((){});})),const SizedBox(height:8)])));}
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.name, this.state, this.detail); final String name, state, detail;
  @override Widget build(BuildContext context) => Container(height: 40, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))), child: Row(children: [SizedBox(width: 58, child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), SizedBox(width: 58, child: Text(state, style: const TextStyle(fontSize: 10, color: AppColors.coral))), Expanded(child: Text(detail, style: const TextStyle(fontSize: 10, color: AppColors.secondary)))]));
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text); final String text;
  @override Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)));
}
