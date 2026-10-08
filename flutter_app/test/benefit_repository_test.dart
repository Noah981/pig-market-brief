import 'dart:convert';
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
}
