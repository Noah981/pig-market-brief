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
        return http.Response(jsonEncode({'price':6442,'previousDate':'20260917','previousPrice':6740,'change':999,'changePct':99,'date':'20260918','updatedAt':'2026-09-19T07:00:30+09:00','source':'축산물품질평가원','scope':'전국·탕박·등외제외·제주제외','unit':'원/kg','monthAverage':6067,'yearAverage':5638}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'rows':[
        {'date':'20240101','price':4163,'resolution':'month','verified':true},{'date':'20250101','price':4731,'resolution':'month','verified':true},{'date':'20260101','price':4852,'resolution':'month','verified':true},
        {'date':'20260801','price':5816,'resolution':'month','verified':true},{'date':'20260910','price':6200,'verified':true},{'date':'20260911','price':6700,'verified':true},{'date':'20260914','price':6850,'verified':true},{'date':'20260915','price':7000,'verified':true},{'date':'20260916','price':6900,'verified':true},{'date':'20260917','price':6740,'verified':true},{'date':'20260918','price':6442,'verified':true}
      ]}),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    final repository=MarketRepository(client:client);
    final current=await repository.refresh();
    expect(current.price,6442);expect(current.change,-298);expect(current.changePct,-4.42);expect(current.previousDate,'20260917');
    expect(current.seriesFor(0).points.length,7);expect(current.seriesFor(0).points.last.date,'20260918');
    expect(current.seriesFor(1).points.last.date,'20260918');
    expect(current.seriesFor(1).points.first.date,'20260910');
    expect(current.seriesFor(2).points.map((x)=>x.date),containsAll(['20260101','20260801']));
    expect(current.seriesFor(2).points.last.date,'20260901');
    expect(current.seriesFor(3).points.map((x)=>x.date),containsAll(['20240101','20250101','20260101']));
    expect(current.seriesFor(3).points.first.date,'20240101');
    expect(current.monthAverage,6067);expect(current.yearAverage,5638);
    final cached=await repository.cached();expect(cached?.price,6442);expect(cached?.fromCache,isTrue);
  });

  test('0원 또는 다른 기준 돈가는 거부한다',(){
    expect(()=>MarketSnapshot.fromJson({'price':0,'previousPrice':6740,'date':'20260918','source':'축산물품질평가원','scope':'전국·탕박·등외제외·제주제외'}),throwsFormatException);
    expect(()=>MarketSnapshot.fromJson({'price':6442,'previousPrice':6740,'date':'20260918','source':'임의 출처','scope':'전국'}),throwsFormatException);
  });
}
