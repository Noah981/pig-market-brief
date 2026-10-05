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
        return http.Response(jsonEncode({'price':5307,'previousPrice':5360,'change':-53,'changePct':-0.99,'date':'20260923','updatedAt':'2026-09-26T13:30:00+09:00','source':'축산물품질평가원','scope':'전국·탕박·등외제외·제주제외','formula':'축산유통정보 다봄 공표 대표값(재계산 없음)'}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'rows':[
        {'date':'20240101','price':4163,'resolution':'month'},{'date':'20250101','price':4731,'resolution':'month'},{'date':'20260101','price':4852,'resolution':'month'},
        {'date':'20260801','price':5816,'resolution':'month'},{'date':'20260918','price':6442},{'date':'20260922','price':5360},{'date':'20260923','price':5307}
      ]}),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    final repository=MarketRepository(client:client);
    final current=await repository.refresh();
    expect(current.price,5307);expect(current.previousPrice,5360);expect(current.change,-53);expect(current.seriesFor(0).points.last.date,'20260923');
    expect(current.seriesFor(2).points.map((x)=>x.date),containsAll(['1월','8월']));
    expect(current.seriesFor(2).points.last.value,closeTo(5703,0.1));
    expect(current.seriesFor(3).points.map((x)=>x.date),containsAll(['2024','2025','2026']));
    final cached=await repository.cached();expect(cached?.price,5307);expect(cached?.fromCache,isTrue);
  });
  test('잘못된 날짜와 비정상 수치를 공식 돈가로 표시하지 않는다',(){
    for(final value in [
      {'price':5000,'previousPrice':5100,'date':'20260230'},
      {'price':5000,'previousPrice':5100,'date':'20990101'},
      {'price':double.nan,'previousPrice':5100,'date':'20260923'},
    ]){expect(()=>MarketSnapshot.fromJson(value),throwsFormatException);}
    final value=MarketSnapshot.fromJson({'price':5000,'previousPrice':5100,'change':999,'changePct':50,'date':'20260923'});
    expect(value.change,-100);expect(value.changePct,closeTo(-100/5100*100,0.0001));
  });

  test('새 발표를 반영하고 휴일·이전 응답·연결 오류에는 기준일을 유지한다',()async{
    SharedPreferences.setMockInitialValues({});
    var date='20261001',price=6027,offline=false;
    final client=MockClient((request)async{
      if(offline||request.url.host=='www.ekapepia.com')return http.Response('',503);
      if(request.url.path.endsWith('pig-price.json'))return http.Response(jsonEncode({'price':price,'previousPrice':6000,'date':date,'scope':'전국·탕박·등외제외·제주제외','source':'축산물품질평가원'}),200);
      return http.Response(jsonEncode({'rows':[{'date':date,'price':price}]}),200);
    });
    final repository=MarketRepository(client:client);
    expect((await repository.refresh()).date,'20261001');
    expect((await repository.refresh()).date,'20261001');
    date='20261005';price=6100;
    final next=await repository.refresh();expect(next.date,'20261005');expect(next.price,6100);
    date='20261001';price=6027;expect((await repository.refresh()).price,6100);
    offline=true;final saved=await repository.refresh();expect(saved.price,6100);expect(saved.fromCache,true);
  });

}
