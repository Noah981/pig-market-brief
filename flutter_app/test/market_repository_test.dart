import 'dart:convert';
import 'package:dondonhae/data/market_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  test('공식 돈가와 날짜순 그래프를 저장한다',()async{
    SharedPreferences.setMockInitialValues({});
    final client=MockClient((request)async{
      if(request.url.path.endsWith('pig-price.json')){
        return http.Response(jsonEncode({'price':6442,'previousPrice':6740,'change':-298,'changePct':-4.42,'date':'20260918','updatedAt':'2026-09-19T07:00:30+09:00','source':'축산물품질평가원','scope':'전국·탕박·등외제외·제주제외'}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'rows':[
        {'date':'20240101','price':4163,'resolution':'month'},{'date':'20250101','price':4731,'resolution':'month'},{'date':'20260101','price':4852,'resolution':'month'},
        {'date':'20260801','price':5816,'resolution':'month'},{'date':'20260916','price':6900},{'date':'20260917','price':6740},{'date':'20260918','price':6442}
      ]}),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    final repository=MarketRepository(client:client);
    final current=await repository.refresh();
    expect(current.price,6442);expect(current.change,-298);expect(current.seriesFor(0).points.last.date,'20260918');
    expect(current.seriesFor(2).points.map((x)=>x.date),containsAll(['1월','8월']));
    expect(current.seriesFor(2).points.last.value,closeTo(6694,0.1));
    expect(current.seriesFor(3).points.map((x)=>x.date),containsAll(['2024','2025','2026']));
    final cached=await repository.cached();expect(cached?.price,6442);expect(cached?.fromCache,isTrue);
  });
}
