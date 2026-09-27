import 'package:dondonhae/data/live_market_driver_builder.dart';
import 'package:dondonhae/data/market_repository.dart';
import 'package:dondonhae/data/pig_grade_repository.dart';
import 'package:dondonhae/services/api/kape_api_client.dart';
import 'package:flutter_test/flutter_test.dart';

void main(){
  test('현재·직전 다봄 실측값으로 돈가 변동 지표를 만든다',(){
    const market=MarketSnapshot(price:5307,previousPrice:5360,change:-53,changePct:-.99,date:'20260923',updatedAt:'2026-09-23T19:10:00+09:00',source:'축산유통정보 다봄',scope:'전국·탕박·등외제외·제주제외',history:[],fromCache:false);
    const previous=KapeAuctionStatus(date:'20260922',totalCount:800,castratedCount:320,femaleCount:460,averageCarcassWeight:90);
    const current=KapeAuctionStatus(date:'20260923',totalCount:883,castratedCount:344,femaleCount:520,averageCarcassWeight:91.3);
    const grades=PigGradeSnapshot(date:'20260923',grades:[],history:[],fromCache:false,auctionStatus:current,auctionHistory:[previous,current]);
    final result=LiveMarketDriverBuilder.build(market:market,grades:grades);
    expect(result.factors.map((x)=>x.title),['전일 대비 돈가 하락','경락두수 증가','평균 도체중 증가','경락 총중량 증가']);
    expect(result.factors[1].detail,contains('+10.4%'));
    expect(result.factors.every((x)=>x.source=='축산유통정보 다봄'),isTrue);
    expect(result.factors.first.direction,'down');
  });
}
