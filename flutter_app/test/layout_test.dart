import 'dart:io';
import 'dart:convert';

import 'package:dondonhae/app.dart';
import 'package:dondonhae/settings/display_settings.dart';
import 'package:dondonhae/pages/section_pages.dart';
import 'package:dondonhae/pages/market_detail_pages.dart';
import 'package:dondonhae/pages/today_care_page.dart';
import 'package:dondonhae/pages/disease_page.dart';
import 'package:dondonhae/data/market_repository.dart';
import 'package:dondonhae/data/pig_grade_repository.dart';
import 'package:dondonhae/services/api/kape_api_client.dart';
import 'package:dondonhae/data/weather_farm_repository.dart';
import 'package:dondonhae/models/dashboard_models.dart';
import 'package:dondonhae/models/disease_models.dart';
import 'package:dondonhae/models/weather_farm_models.dart';
import 'package:dondonhae/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> renderAt(WidgetTester tester, double width, String name) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DondonhaeApp());
  await tester.pumpAndSettle();
  await tester.pump(const Duration(milliseconds:800));
  expect(tester.takeException(), isNull);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/home_$name.png'));
}

Future<void> renderPage(WidgetTester tester, Widget page, String name) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner:false,theme:AppTheme.light,home:page));
  await tester.pump(const Duration(milliseconds:800));
  expect(tester.takeException(), isNull);
  await expectLater(find.byType(MaterialApp),matchesGoldenFile('goldens/$name.png'));
}

MarketSnapshot actualMarketFixture(){final price=(jsonDecode(File('../docs/data/pig-price.json').readAsStringSync()) as Map).cast<String,dynamic>();final source=(jsonDecode(File('../docs/data/pig-price-history.json').readAsStringSync()) as Map).cast<String,dynamic>();final rows=(source['rows'] as List).whereType<Map<String,dynamic>>().map((x)=>PricePoint(x['date'].toString(),(x['price'] as num).toDouble(),resolution:x['resolution']?.toString()??'day')).toList();return MarketSnapshot.fromJson(price,fromCache:true,history:rows);}

Commodity actualCommodity(String id){final platform=(jsonDecode(File('../docs/data/platform.json').readAsStringSync()) as Map).cast<String,dynamic>();final row=(platform['markets'] as List).whereType<Map<String,dynamic>>().firstWhere((x)=>x['name']==id);final names={'corn':'옥수수','soybean_meal':'대두박','usd_krw':'달러 환율','wti':'국제 유가 (WTI)'};final value=(row['value'] as num).toDouble();return Commodity(names[id]!,value.toStringAsFixed(value>=1000?1:2),row['unit'].toString(),(row['changePct'] as num?)?.toDouble(),Icons.show_chart,id:id,source:row['source']?.toString()??'',asOf:row['date']?.toString()??'',frequency:row['frequency']?.toString()??'',basis:row['basis']?.toString()??'',history:(row['history'] as List? ?? const []).whereType<Map<String,dynamic>>().map((x)=>CommodityPoint(x['date'].toString(),(x['value'] as num).toDouble())).toList());}
PigGradeSnapshot fixtureGrades()=>PigGradeSnapshot(date:'20260926',fromCache:true,grades:const [KapeGradePrice(grade:'1+',price:5880,count:4300,date:'20260926'),KapeGradePrice(grade:'1',price:5600,count:6100,date:'20260926'),KapeGradePrice(grade:'2',price:5180,count:3900,date:'20260926'),KapeGradePrice(grade:'등외',price:4280,count:400,date:'20260926')],history:const [KapeGradePrice(grade:'1+',price:5800,count:4200,date:'20260925'),KapeGradePrice(grade:'1+',price:5880,count:4300,date:'20260926'),KapeGradePrice(grade:'1',price:5520,count:6000,date:'20260925'),KapeGradePrice(grade:'1',price:5600,count:6100,date:'20260926'),KapeGradePrice(grade:'2',price:5200,count:3800,date:'20260925'),KapeGradePrice(grade:'2',price:5180,count:3900,date:'20260926'),KapeGradePrice(grade:'등외',price:4300,count:410,date:'20260925'),KapeGradePrice(grade:'등외',price:4280,count:400,date:'20260926')]);
const fixtureAnalysis=MarketAnalysis(summary:'공식 경락·공급 지표를 함께 확인한 결과입니다.',updatedAt:'2026-09-26',factors:[MarketFactor('경락두수 변화','확인','전 거래일 공식 경락두수와 비교합니다.',source:'축산물품질평가원',sourceDate:'2026-09-26')],sources:[MarketSource('축산물품질평가원','공식 축산유통정보','https://www.ekapepia.com')]);
const fixtureDisease=DiseaseAlert(id:'visual-fmd',type:DiseaseType.fmd,source:'농림축산검역본부',countryCode:'KR',evidence:DiseaseEvidence.official,status:'발생',summary:'충청남도 보령시 천북면 공식 발생',sourceUrl:'https://www.mafra.go.kr',occurrenceDate:'2026-09-26',province:'충청남도',cityCounty:'보령시',town:'천북면',latitude:36.45,longitude:126.58);

void main() {
  setUpAll(() async {
    final bytes=await File('assets/fonts/NotoSansKR.ttf').readAsBytes();
    await (FontLoader('NotoSansKR')..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    final flutterRoot=Platform.environment['FLUTTER_ROOT'];
    if(flutterRoot!=null){
      final iconFile=File('$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf');
      if(await iconFile.exists()){
        final iconBytes=await iconFile.readAsBytes();
        await (FontLoader('MaterialIcons')..addFont(Future.value(ByteData.sublistView(iconBytes)))).load();
      }
    }
  });
  setUp(() {
    final price=jsonDecode(File('../docs/data/pig-price.json').readAsStringSync());
    final history=jsonDecode(File('../docs/data/pig-price-history.json').readAsStringSync());
    SharedPreferences.setMockInitialValues({
      'official_dabom_producer_pig_price_v4':jsonEncode({'price':price,'history':history}),
      'verified_commodity_market_v1':File('../docs/data/platform.json').readAsStringSync(),
      'verified_disease_feed_v3':File('../docs/data/disease-alerts.json').readAsStringSync(),
    });
  });
  testWidgets('홈 360dp 오버플로 없음', (tester) => renderAt(tester, 360, '360'));
  testWidgets('홈 390dp 오버플로 없음', (tester) => renderAt(tester, 390, '390'));
  testWidgets('홈 412dp 오버플로 없음', (tester) => renderAt(tester, 412, '412'));
  testWidgets('시황 390dp 시안 비교 이미지', (tester) async {
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_1')));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull);
    await expectLater(find.byType(MaterialApp),matchesGoldenFile('goldens/market_390.png'));
  });
  testWidgets('오늘관리 390dp 시안 비교 이미지',(tester)async{
    await renderPage(tester,TodayCarePage(guide:WeatherFarmRepository.fallback,onRefresh:()async{}),'today_390');
  });
  testWidgets('질병 전체 390dp 시안 비교 이미지',(tester)async{
    await renderPage(tester,const DiseasePage(),'disease_390');
  });
  testWidgets('질병 선택 필터 390dp 시안 비교 이미지',(tester)async{
    tester.view.devicePixelRatio=1;tester.view.physicalSize=const Size(390,844);addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(debugShowCheckedModeBanner:false,theme:AppTheme.light,home:const DiseasePage()));
    await tester.pump(const Duration(milliseconds:800));
    await tester.tap(find.text('구제역').first);await tester.pumpAndSettle();
    expect(find.text('구제역만 보기 ▼'),findsOneWidget);expect(tester.takeException(),isNull);
    await expectLater(find.byType(MaterialApp),matchesGoldenFile('goldens/disease_filter_390.png'));
  });
  testWidgets('질병 알림 설정 390dp 시안 비교 이미지',(tester)async{
    await renderPage(tester,const DiseaseNotificationSettingsPage(),'disease_settings_390');
  });
  testWidgets('돈가 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,PigPriceDetailPage(snapshot:actualMarketFixture(),analysis:null,loadGrades:false),'pig_detail_390');});
  for(final id in const ['corn','soybean_meal','usd_krw','wti']){
    testWidgets('$id 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,CommodityDetailPage(item:actualCommodity(id)),'${id}_detail_390');});
  }
  testWidgets('3개년 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,ThreeYearPigPricePage(snapshot:actualMarketFixture()),'three_year_390');});
  testWidgets('가격 요인 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,const MarketDriverDetailPage(analysis:fixtureAnalysis),'driver_detail_390');});
  testWidgets('등급별 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,GradePriceTrendPage(snapshot:fixtureGrades()),'grade_detail_390');});
  testWidgets('질병 발생 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,const DiseaseEventDetailPage(event:fixtureDisease,distanceKm:8.4,userLatitude:36.52,userLongitude:127.0),'disease_detail_390');});
  testWidgets('건강 신호 상세 390dp 시안 비교 이미지',(tester)async{await renderPage(tester,const HealthSignalDetailPage(risk:FarmHealthRisk('호흡기 질환 주의','주의','기온 변화와 습도 조건을 확인하세요.','기침·재채기·복식호흡')),'health_signal_detail_390');});
  testWidgets('가짜 0값 없이 아래로 당겨 새로고침을 제공한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    await tester.pumpAndSettle();
    expect(find.text('0원'), findsNothing);
    expect(find.text('전국 돈가'), findsWidgets);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('하단 메뉴가 실제 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    for (final item in const [(1, '시황'), (2, '질병'), (3, '오늘 관리'), (4, '돈돈해님')]) {
      await tester.tap(find.byKey(ValueKey('nav_${item.$1}')));
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsWidgets);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('날씨 카드가 질병·환기·수의사 통합 화면으로 이동한다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('weather_farm_guide')));await tester.pumpAndSettle();
    expect(find.text('오늘 주의할 건강 신호'),findsOneWidget);
    expect(find.text('오늘의 환기·점검 포인트'),findsOneWidget);
    expect(find.text('수의사 연결'),findsOneWidget);
    expect(find.text('약품·예방 정보'),findsOneWidget);
    expect(find.text('9월에 주의할 질환군'),findsOneWidget);
    expect(find.textContaining('PRRS'),findsWidgets);
    final risk=find.text('호흡기 질환 관찰');await tester.ensureVisible(risk);await tester.tap(risk);await tester.pumpAndSettle();
    expect(find.text('건강 신호 상세'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('홈 가격 변동 카드가 근거 상세로 이동한다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();await tester.pump(const Duration(milliseconds:800));
    await tester.tap(find.text('돈가 변동 이유'));await tester.pumpAndSettle();
    expect(find.text('가격 요인 상세'),findsOneWidget);expect(tester.takeException(),isNull);
  });
  testWidgets('돈가와 원료 카드가 상세 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('nav_1')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const ValueKey('market_pig')));
    await tester.tap(find.byKey(const ValueKey('market_pig')));
    await tester.pumpAndSettle();
    expect(find.text('전국 돈가 상세'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final commodityCard = find.byKey(const ValueKey('market_corn'));
    await tester.ensureVisible(commodityCard);
    await tester.pumpAndSettle();
    await tester.tap(commodityCard);
    await tester.pumpAndSettle();
    expect(find.text('옥수수 상세'), findsOneWidget);
    expect(find.text('가격 움직임 주요 요인'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('돈가 기간 탭은 데이터가 없어도 실제 선택이 가능하다', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    for(final tab in const ['주간','월간','연간']){await tester.tap(find.text(tab));await tester.pump();expect(find.text(tab),findsOneWidget);expect(tester.takeException(),isNull);}
    expect(tester.takeException(),isNull);
  });
  testWidgets('시황 구조와 질병 지도가 실제로 이동하고 표시된다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('nav_1')));await tester.pumpAndSettle();
    expect(find.text('시황'),findsWidgets);expect(find.text('최근 7일 추이'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav_2')));await tester.pumpAndSettle();
    expect(find.byType(CustomPaint),findsWidgets);expect(tester.takeException(),isNull);
  });
  testWidgets('설정에서 글자 크기를 변경하고 저장한다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'initial app');
    await tester.tap(find.byKey(const ValueKey('nav_4')));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'more page');
    await tester.tap(find.text('글자 크기'));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'text size sheet');
    await tester.tap(find.text('크게'));await tester.pumpAndSettle();
    expect(tester.takeException(),isNull,reason:'scale change');
    expect(DisplaySettings.instance.textScale,1.15);
    expect((await SharedPreferences.getInstance()).getDouble('display_text_scale'),1.15);
    await DisplaySettings.instance.setTextScale(1);
    expect(tester.takeException(),isNull);
  });
  testWidgets('홈 큰글씨 모드는 120%로 확대되고 다시 꺼진다',(tester)async{
    tester.view.physicalSize=const Size(360,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('large_text_mode_button')));await tester.pumpAndSettle();
    expect(DisplaySettings.instance.largeTextMode,isTrue);
    expect(DisplaySettings.instance.textScale,1.2);
    expect(find.text('기본 글씨'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const ValueKey('large_text_mode_button')));await tester.pumpAndSettle();
    expect(DisplaySettings.instance.largeTextMode,isFalse);
  });
  testWidgets('새 설치의 기본 글자 크기는 100%다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    expect(DisplaySettings.instance.selectedTextScale,1.0);expect(tester.takeException(),isNull);
  });
  for(final width in const [360.0,390.0,412.0]){
    testWidgets('큰글씨 상세 화면 ${width.toInt()}dp 배경·상단·오버플로 정상',(tester)async{
      tester.view.physicalSize=Size(width,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home:MediaQuery(data:MediaQueryData(size:Size(width,844),textScaler:const TextScaler.linear(1.55)),child:const PageShell(title:'내 지역 지원사업',subtitle:'경상북도 경주시 기준 공식 공고',child:Column(children:[SizedBox(height:52,child:OutlinedButton(onPressed:null,child:Text('경상북도 경주시 · 지역 변경'))),SizedBox(height:10),Card(child:Padding(padding:EdgeInsets.all(24),child:Text('현재 연결된 신규 공식 공고가 없습니다.',textAlign:TextAlign.center))),SizedBox(height:12),SizedBox(height:52,child:OutlinedButton(onPressed:null,child:Text('공식 공고 새로고침')))])))));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('내 지역 지원사업')).dy,greaterThanOrEqualTo(14));
      expect(find.byType(SafeArea),findsWidgets);
      expect(tester.takeException(),isNull);
    });
  }
}
