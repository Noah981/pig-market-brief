import 'package:dondonhae/app.dart';
import 'package:dondonhae/settings/display_settings.dart';
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));
  testWidgets('홈 360dp 오버플로 없음', (tester) => renderAt(tester, 360, '360'));
  testWidgets('홈 390dp 오버플로 없음', (tester) => renderAt(tester, 390, '390'));
  testWidgets('홈 412dp 오버플로 없음', (tester) => renderAt(tester, 412, '412'));
  testWidgets('공식 기본값과 아래로 당겨 새로고침을 제공한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    await tester.pumpAndSettle();
    expect(find.text('6,442'), findsOneWidget);
    expect(find.byType(RefreshIndicator), findsOneWidget);
  });
  testWidgets('하단 메뉴가 실제 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    for (final item in const [(1, '시황'), (2, '질병 정보'), (3, '오늘 관리'), (4, '돈돈해님')]) {
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

    await tester.tap(find.text('돈가 변동 이유'));
    await tester.pumpAndSettle();
    expect(find.text('전국 돈가 상세'), findsOneWidget);
    await tester.pageBack();
    await tester.pumpAndSettle();

    final commodityCard = find.byKey(const ValueKey('commodity_corn'));
    await tester.scrollUntilVisible(commodityCard,300,scrollable:find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    await tester.tap(commodityCard);
    await tester.pumpAndSettle();
    expect(find.text('옥수수 상세'), findsOneWidget);
    expect(find.text('왜 오르내리나요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('돈가 기간 탭마다 날짜축이 실제로 바뀐다', (tester) async {
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    expect(find.text('9/18'),findsOneWidget);
    await tester.tap(find.text('월간'));await tester.pump();
    expect(find.text('8월'),findsWidgets);
    await tester.tap(find.text('연간'));await tester.pump();
    expect(find.text('2026'),findsOneWidget);
    expect(tester.takeException(),isNull);
  });
  testWidgets('국제정세 제목과 질병 지도가 실제로 이동하고 표시된다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    final header=find.byKey(const ValueKey('international_market_header'));await tester.scrollUntilVisible(header,300,scrollable:find.byType(Scrollable).first);await tester.tap(header);await tester.pumpAndSettle();
    expect(find.text('국제정세 해석'),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('nav_2')));await tester.pumpAndSettle();
    expect(find.byType(Image),findsWidgets);expect(tester.takeException(),isNull);
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
    expect(DisplaySettings.instance.textScale,1.55);
    expect(find.text('기본 글씨'),findsOneWidget);
    expect(tester.takeException(),isNull);
    await tester.tap(find.byKey(const ValueKey('large_text_mode_button')));await tester.pumpAndSettle();
    expect(DisplaySettings.instance.largeTextMode,isFalse);
  });
  testWidgets('새 설치의 기본 글자 크기는 매우 크게 130%다',(tester)async{
    tester.view.physicalSize=const Size(390,844);tester.view.devicePixelRatio=1;addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());await tester.pumpAndSettle();
    expect(DisplaySettings.instance.selectedTextScale,1.3);expect(tester.takeException(),isNull);
  });
}
