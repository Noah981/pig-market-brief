import 'package:dondonhae/app.dart';
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
  testWidgets('하단 메뉴가 실제 화면으로 이동한다', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const DondonhaeApp());
    for (final item in const [(1, '시황'), (2, '질병 정보'), (3, '농장점검'), (4, '돈돈해님')]) {
      await tester.tap(find.byKey(ValueKey('nav_${item.$1}')));
      await tester.pumpAndSettle();
      expect(find.text(item.$2), findsWidgets);
      expect(tester.takeException(), isNull);
    }
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

    final commodityCard = find.byKey(const ValueKey('commodity_corn')).first;
    await tester.ensureVisible(commodityCard);
    await tester.pumpAndSettle();
    await tester.tap(commodityCard);
    await tester.pumpAndSettle();
    expect(find.text('옥수수 상세'), findsOneWidget);
    expect(find.text('왜 오르내리나요?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
