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
        return http.Response(jsonEncode({'price':5499,'previousPrice':6097,'change':-598,'changePct':-9.81,'date':'20260918','updatedAt':'2026-09-19T07:00:30+09:00','source':'축산물품질평가원','scope':'전국·탕박·등외제외·제주제외'}),200,headers:{'content-type':'application/json; charset=utf-8'});
      }
      return http.Response(jsonEncode({'rows':[{'date':'20260916','price':6000},{'date':'20260917','price':6097},{'date':'20260918','price':5499}]}),200,headers:{'content-type':'application/json; charset=utf-8'});
    });
    final repository=MarketRepository(client:client);
    final current=await repository.refresh();
    expect(current.price,5499);expect(current.change,-598);expect(current.history,[6000,6097,5499]);
    final cached=await repository.cached();expect(cached?.price,5499);expect(cached?.fromCache,isTrue);
  });
}
