import 'package:dondonhae/app.dart';
import 'package:dondonhae/settings/display_settings.dart';
import 'package:dondonhae/pages/section_pages.dart';
import 'package:dondonhae/pages/market_detail_pages.dart';
import 'package:dondonhae/pages/today_care_page.dart';
import 'package:dondonhae/pages/disease_page.dart';
import 'package:dondonhae/data/market_repository.dart';
import 'package:dondonhae/data/commodity_repository.dart';
import 'package:dondonhae/data/weather_farm_repository.dart';
import 'package:dondonhae/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> renderAt(WidgetTester tester, double width, String name) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 844);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const DondonhaeApp());
  await tester.pumpAndSettle();
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
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
  testWidgets('질병 알림 설정 390dp 시안 비교 이미지',(tester)async{
    await renderPage(tester,const DiseaseNotificationSettingsPage(),'disease_settings_390');
  });
  testWidgets('돈가 상세 390dp 시안 비교 이미지',(tester)async{final market=await MarketRepository().cached();expect(market,isNotNull);await renderPage(tester,PigPriceDetailPage(snapshot:market,analysis:null,loadGrades:false),'pig_detail_390');});
  for(final id in const ['corn','soybean_meal','usd_krw','wti']){
    testWidgets('$id 상세 390dp 시안 비교 이미지',(tester)async{final items=await CommodityRepository().cached();await renderPage(tester,CommodityDetailPage(item:items.firstWhere((x)=>x.id==id)),'${id}_detail_390');});
  }
  testWidgets('3개년 상세 390dp 시안 비교 이미지',(tester)async{final market=await MarketRepository().cached();expect(market,isNotNull);await renderPage(tester,ThreeYearPigPricePage(snapshot:market!),'three_year_390');});
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
    expect(tester.takeException(),isNull);
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

    final commodityCard = find.text('옥수수').first;
    await tester.scrollUntilVisible(commodityCard,300,scrollable:find.byType(Scrollable).first);
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
    await tester.tap(find.byKey(const ValueKey('nav_4')));await tester.pumpAndSettle();
    await tester.tap(find.text('글자 크기'));await tester.pumpAndSettle();
    await tester.tap(find.text('크게'));await tester.pumpAndSettle();
    expect(DisplaySettings.instance.textScale,1.15);
    expect((await SharedPreferences.getInstance()).getDouble('display_text_scale'),1.15);
    await DisplaySettings.instance.setTextScale(1);
    expect(tester.takeException(),isNull);
  });
  testWidgets('홈 큰글씨 모드는 155%로 확대되고 다시 꺼진다',(tester)async{
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
