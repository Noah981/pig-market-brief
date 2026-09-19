import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class MarketSnapshot {
  const MarketSnapshot({required this.price,required this.previousPrice,required this.change,required this.changePct,required this.date,required this.updatedAt,required this.source,required this.scope,required this.history,required this.fromCache});
  final int price,previousPrice,change;
  final double changePct;
  final String date,updatedAt,source,scope;
  final List<double> history;
  final bool fromCache;

  MarketSnapshot copyWith({List<double>? history,bool? fromCache})=>MarketSnapshot(price:price,previousPrice:previousPrice,change:change,changePct:changePct,date:date,updatedAt:updatedAt,source:source,scope:scope,history:history??this.history,fromCache:fromCache??this.fromCache);
  factory MarketSnapshot.fromJson(Map<String,dynamic> j,{bool fromCache=false}){
    final price=(j['price'] as num?)?.round()??0;
    final previous=(j['previousPrice'] as num?)?.round()??0;
    if(price<=0||previous<=0)throw const FormatException('Invalid official pig price');
    return MarketSnapshot(price:price,previousPrice:previous,change:(j['change'] as num?)?.round()??price-previous,changePct:(j['changePct'] as num?)?.toDouble()??0,date:j['date']?.toString()??'',updatedAt:j['updatedAt']?.toString()??'',source:j['source']?.toString()??'축산물품질평가원',scope:j['scope']?.toString()??'전국·탕박·등외제외·제주제외',history:const [],fromCache:fromCache);
  }
}

class MarketRepository {
  static const bundledSnapshot=MarketSnapshot(price:6442,previousPrice:6740,change:-298,changePct:-4.42,date:'20260918',updatedAt:'2026-09-19T07:00:30+09:00',source:'축산물품질평가원',scope:'전국·탕박·등외제외·제주제외',history:[5800,6200,6700,6850,7000,6900,6740,6442],fromCache:true);
  static const _priceUrl='https://noah981.github.io/pig-market-brief/data/pig-price.json';
  static const _historyUrl='https://noah981.github.io/pig-market-brief/data/pig-price-history.json';
  // v1에는 다봄 공표 대표값이 아닌 pigGrade 자체 계산값이 저장될 수
  // 있었으므로 재사용하지 않는다.
  static const _cacheKey='official_dabom_producer_pig_price_v2';
  final http.Client _client;
  MarketRepository({http.Client? client}):_client=client??http.Client();

  Future<MarketSnapshot?> cached()async{
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString(_cacheKey);if(raw==null)return bundledSnapshot;
    try{return MarketSnapshot.fromJson(jsonDecode(raw) as Map<String,dynamic>,fromCache:true);}catch(_){return bundledSnapshot;}
  }
  Future<MarketSnapshot> refresh()async{
    final stamp=DateTime.now().millisecondsSinceEpoch;
    final responses=await Future.wait([_client.get(Uri.parse('$_priceUrl?v=$stamp')).timeout(const Duration(seconds:12)),_client.get(Uri.parse('$_historyUrl?v=$stamp')).timeout(const Duration(seconds:12))]);
    if(responses.any((r)=>r.statusCode!=200))throw Exception('Official data unavailable');
    final priceJson=jsonDecode(utf8.decode(responses[0].bodyBytes)) as Map<String,dynamic>;
    final historyJson=jsonDecode(utf8.decode(responses[1].bodyBytes)) as Map<String,dynamic>;
    var snapshot=MarketSnapshot.fromJson(priceJson);
    final rows=(historyJson['rows'] as List? ?? const []).whereType<Map<String,dynamic>>().where((r)=>r['resolution']!='month'&&r['price'] is num).toList()..sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
    final history=rows.reversed.take(8).toList().reversed.map((r)=>(r['price'] as num).toDouble()).toList();
    snapshot=snapshot.copyWith(history:history.length>=2?history:[snapshot.previousPrice.toDouble(),snapshot.price.toDouble()]);
    final prefs=await SharedPreferences.getInstance();await prefs.setString(_cacheKey,jsonEncode(priceJson));
    return snapshot;
  }
}
