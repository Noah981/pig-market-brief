import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dondonhae/pages/benefit_page.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dondonhae/data/benefit_repository.dart';
void main(){
 TestWidgetsFlutterBinding.ensureInitialized();
 final raw=jsonEncode({'benefits':[
  {'id':'pig','title':'양돈농가 시설 지원','url':'https://www.mafra.go.kr/','region':'전국'},
  {'id':'cow','title':'한우농가 사료 지원','url':'https://www.mafra.go.kr/','region':'전국'},
  {'id':'exclude','title':'축산농가 사료 지원','target':'양돈 제외','url':'https://www.mafra.go.kr/','region':'전국'}]});
 test('Old offline cache is filtered to pig programmes',()async{
  SharedPreferences.setMockInitialValues({'benefit_feed_v1':raw});
  expect((await BenefitRepository().cached()).items.map((x)=>x.id),['pig']);
 });
 test('Live feed rejects unrelated livestock before display and cache',()async{
  SharedPreferences.setMockInitialValues({});
  final repository=BenefitRepository(client:MockClient((_)async=>http.Response(raw,200,headers:{'content-type':'application/json; charset=utf-8'})));
  expect((await repository.refresh(notify:false)).items.map((x)=>x.id),['pig']);
  expect((await repository.cached()).items.map((x)=>x.id),['pig']);
 });
 testWidgets('Official guideline is shown when no dated application is available',(tester)async{
  final data=jsonEncode({'benefits':[{'id':'g','title':'2026년 축사시설현대화사업 시행지침','url':'https://www.mafra.go.kr/','region':'전국','target':'양돈농가 포함','support':'축사 신축·개보수 지원 지침','applicationPeriod':'관할 시·군·구 접수 일정 확인'}]});
  SharedPreferences.setMockInitialValues({'benefit_feed_v1':data});
  final repository=BenefitRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(data),200)));
  tester.view.physicalSize=const Size(412,1100);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:BenefitPage(repository:repository)));await tester.pumpAndSettle();
  expect(find.text('2026년 축사시설현대화사업 시행지침'),findsOneWidget);expect(find.text('기간 확인'),findsOneWidget);expect(tester.takeException(),isNull);
 });
 testWidgets('Budget conditional application is visible with original period',(tester)async{
  final data=jsonEncode({'benefits':[{'id':'b','title':'양돈농가 시설 지원','url':'https://www.mafra.go.kr/','region':'전국','target':'양돈농가','support':'시설 지원','applicationPeriod':'예산 소진시까지'}]});
  SharedPreferences.setMockInitialValues({'benefit_feed_v1':data});
  final repository=BenefitRepository(client:MockClient((_)async=>http.Response.bytes(utf8.encode(data),200)));
  tester.view.physicalSize=const Size(412,1100);tester.view.devicePixelRatio=1;
  addTearDown(tester.view.resetPhysicalSize);addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(home:BenefitPage(repository:repository)));await tester.pumpAndSettle();
  expect(find.text('양돈농가 시설 지원'),findsOneWidget);expect(find.text('예산 소진시까지'),findsOneWidget);expect(find.text('접수 확인'),findsOneWidget);expect(tester.takeException(),isNull);
 });
}
