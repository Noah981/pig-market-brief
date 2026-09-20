import 'package:dondonhae/core/data/cache_store.dart';
import 'package:dondonhae/core/data/data_state.dart';
import 'package:dondonhae/core/network/external_source.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main(){
  setUp(()=>SharedPreferences.setMockInitialValues({}));
  test('EMPTY와 ERROR를 분리하고 마지막 정상 데이터를 유지한다',(){const empty=DataState<int>.empty();const error=DataState<int>.error('network',lastGood:6442);expect(empty.status,DataStatus.empty);expect(error.status,DataStatus.error);expect(error.data,6442);expect(error.hasUsableData,isTrue);});
  test('캐시에 출처와 기준시각 및 마지막 성공시각을 함께 저장한다',()async{const store=JsonCacheStore();final value=CacheEnvelope(payload:const {'price':6442},source:'축산물품질평가원',sourceTimestamp:'2026-09-18',fetchedAt:'2026-09-20T10:00:00+09:00',lastSuccessfulUpdate:'2026-09-20T10:00:00+09:00');await store.write('price',value);final loaded=await store.read('price');expect(loaded?.payload['price'],6442);expect(loaded?.source,'축산물품질평가원');expect(loaded?.lastSuccessfulUpdate,isNotEmpty);});
  test('기관별 승인 상태와 Secret 이름만 관리하고 실제 키는 포함하지 않는다',(){expect(SourceRegistry.sources.map((x)=>x.id),containsAll(['kape','kma','mois_disease','ecos','kamis']));expect(SourceRegistry.sources.where((x)=>x.availability==SourceAvailability.approvalPending),isNotEmpty);expect(SourceRegistry.sources.every((x)=>!x.secretName.contains('=')&&!x.secretName.contains(' ')),isTrue);});
}
