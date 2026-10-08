import 'package:dondonhae/data/market_repository.dart';
import 'package:dondonhae/services/market_notification_coordinator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

MarketSnapshot quote(String date,int price,{bool cached=false})=>MarketSnapshot(
  price:price,previousPrice:6000,change:price-6000,
  changePct:(price-6000)/6000*100,date:date,updatedAt:date,
  source:'축산물품질평가원',scope:'전국·탕박·등외제외·제주제외',
  history:const [],fromCache:cached);

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('첫 조회·중복·오래된 응답·캐시는 알리지 않고 새 발표와 정정만 알린다',()async{
    final sent=<MarketSnapshot>[];
    Future<void> notify(MarketSnapshot value)async{sent.add(value);}
    Future<bool> process(MarketSnapshot value)=>MarketNotificationCoordinator.process(value,notify:notify);
    await process(quote('20261006',6000));
    await process(quote('20261006',6000));
    await process(quote('20261007',6100,cached:true));
    expect(sent,isEmpty);
    await process(quote('20261007',6100));
    await process(quote('2026-10-07',6100));
    await process(quote('20261006',6000));
    await process(quote('20261007',6150));
    expect(sent.map((x)=>x.price),[6100,6150]);
  });
  test('알림 실패는 다음 조회에서 재시도한다',()async{
    await MarketNotificationCoordinator.process(quote('20261006',6000));
    final next=quote('20261007',6100);
    await expectLater(MarketNotificationCoordinator.process(next,notify:(_)async{throw StateError('delivery');}),throwsStateError);
    var delivered=0;
    await MarketNotificationCoordinator.process(next,notify:(_)async{delivered++;});
    expect(delivered,1);
  });
}
