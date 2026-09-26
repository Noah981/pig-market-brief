import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/dashboard_models.dart';

class MarketSnapshot {
  const MarketSnapshot({required this.price,required this.previousPrice,required this.change,required this.changePct,required this.date,required this.updatedAt,required this.source,required this.scope,required this.history,required this.fromCache});
  final int price,previousPrice,change; final double changePct;
  final String date,updatedAt,source,scope; final List<PricePoint> history; final bool fromCache;
  factory MarketSnapshot.fromJson(Map<String,dynamic> j,{bool fromCache=false,List<PricePoint> history=const []}){
    final price=(j['price'] as num?)?.round()??0,previous=(j['previousPrice'] as num?)?.round()??0;
    if(price<=0||previous<=0)throw const FormatException('Invalid official pig price');
    return MarketSnapshot(price:price,previousPrice:previous,change:(j['change'] as num?)?.round()??price-previous,changePct:(j['changePct'] as num?)?.toDouble()??0,date:j['date']?.toString()??'',updatedAt:j['updatedAt']?.toString()??'',source:j['source']?.toString()??'축산물품질평가원',scope:j['scope']?.toString()??'전국·탕박·등외제외·제주제외',history:history,fromCache:fromCache);
  }
  PriceSeries seriesFor(int period){
    final daily=history.where((x)=>x.resolution!='month').toList();
    final monthly=_monthly();
    if(period==1)return PriceSeries('주간',_weekly(daily));
    if(period==2)return PriceSeries('월간',monthly.length>8?monthly.sublist(monthly.length-8):monthly);
    if(period==3)return PriceSeries('연간',_annual());
    return PriceSeries('일간',daily.length>8?daily.sublist(daily.length-8):daily);
  }
  PriceSeries detailSeries(int period){
    final daily=history.where((x)=>x.resolution!='month').toList();
    final monthly=_monthly();
    List<PricePoint> tail(List<PricePoint> rows,int count)=>rows.length>count?rows.sublist(rows.length-count):rows;
    if(period==0)return PriceSeries('7일',tail(daily,7));
    if(period==1)return PriceSeries('1개월',tail(daily,30));
    if(period==2)return PriceSeries('1년',tail(monthly,12));
    return PriceSeries('3년',tail(monthly,36));
  }
  List<PricePoint> _monthly(){
    final grouped=<String,List<double>>{};
    final official=history.where((x)=>x.resolution=='month').toList();
    for(final x in official){if(x.date.length>=6)grouped[x.date.substring(0,6)]=[x.value];}
    final officialMonths=grouped.keys.toSet();
    for(final x in history.where((x)=>x.resolution!='month')){if(x.date.length>=6&&!officialMonths.contains(x.date.substring(0,6)))grouped.putIfAbsent(x.date.substring(0,6),()=>[]).add(x.value);}
    final keys=grouped.keys.toList()..sort();
    return keys.map((k){final v=grouped[k]!;return PricePoint('${int.parse(k.substring(4,6))}월',v.reduce((a,b)=>a+b)/v.length);}).toList();
  }
  List<PricePoint> _weekly(List<PricePoint> input){
    final result=<PricePoint>[];
    for(var end=input.length;end>0&&result.length<8;end-=7){
      final start=(end-7).clamp(0,end),chunk=input.sublist(start,end),raw=chunk.last.date;
      final value=chunk.map((x)=>x.value).reduce((a,b)=>a+b)/chunk.length;
      final day=int.tryParse(raw.substring(6,8))??1;
      result.insert(0,PricePoint('${int.parse(raw.substring(4,6))}월${((day-1)~/7)+1}주',value));
    }
    return result;
  }
  List<PricePoint> _annual(){
    final grouped=<String,List<double>>{};
    final source=history.any((x)=>x.resolution=='month')?history.where((x)=>x.resolution=='month'):history;
    for(final x in source){if(x.date.length>=4)grouped.putIfAbsent(x.date.substring(0,4),()=>[]).add(x.value);}
    final years=grouped.keys.toList()..sort();
    final result=years.map((y){final v=grouped[y]!;return PricePoint(y,v.reduce((a,b)=>a+b)/v.length);}).toList();
    return result.length>4?result.sublist(result.length-4):result;
  }
}

class MarketRepository {
  static const bundledSnapshot=MarketSnapshot(price:5307,previousPrice:5360,change:-53,changePct:-0.99,date:'20260923',updatedAt:'2026-09-26T13:30:00+09:00',source:'축산물품질평가원',scope:'전국·탕박·등외제외·제주제외',history:[
    PricePoint('20230901',5166,resolution:'month'),PricePoint('20240101',4163,resolution:'month'),PricePoint('20240901',5464,resolution:'month'),PricePoint('20250101',4731,resolution:'month'),PricePoint('20250901',5906,resolution:'month'),PricePoint('20260101',4852,resolution:'month'),PricePoint('20260801',5816,resolution:'month'),
    PricePoint('20260909',5800),PricePoint('20260910',6200),PricePoint('20260911',6700),PricePoint('20260914',6850),PricePoint('20260915',7000),PricePoint('20260916',6900),PricePoint('20260917',6740),PricePoint('20260918',6442),PricePoint('20260922',5360),PricePoint('20260923',5307),
  ],fromCache:true);
  static const _priceUrl='https://noah981.github.io/pig-market-brief/data/pig-price.json',_historyUrl='https://noah981.github.io/pig-market-brief/data/pig-price-history.json',_cacheKey='official_dabom_producer_pig_price_v4';
  final http.Client _client;
  MarketRepository({http.Client? client}):_client=client??http.Client();
  Future<MarketSnapshot?> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null){
      try{
        final price=jsonDecode(await rootBundle.loadString('assets/data/pig-price.json'));
        final history=jsonDecode(await rootBundle.loadString('assets/data/pig-price-history.json'));
        return _decode({'price':price,'history':history},fromCache:true);
      }catch(_){return bundledSnapshot;}
    }
    try{return _decode(jsonDecode(raw) as Map<String,dynamic>,fromCache:true);}catch(_){return bundledSnapshot;}
  }
  Future<MarketSnapshot> refresh()async{
    // 대표 돈가는 raw pigGrade를 기기에서 재계산하지 않는다. Actions가
    // 다봄 메인의 공표 카드를 검증·수집한 JSON만 사용한다.
    final stamp=DateTime.now().millisecondsSinceEpoch;
    final responses=await Future.wait([_client.get(Uri.parse('$_priceUrl?v=$stamp')).timeout(const Duration(seconds:12)),_client.get(Uri.parse('$_historyUrl?v=$stamp')).timeout(const Duration(seconds:12))]);
    if(responses.any((r)=>r.statusCode!=200))throw Exception('Official data unavailable');
    final combined=<String,dynamic>{'price':jsonDecode(utf8.decode(responses[0].bodyBytes)),'history':jsonDecode(utf8.decode(responses[1].bodyBytes))};
    final value=_decode(combined);await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode(combined));return value;
  }
  MarketSnapshot _decode(Map<String,dynamic> combined,{bool fromCache=false}){
    final price=((combined['price'] as Map?)?.cast<String,dynamic>())??combined;
    final history=((combined['history'] as Map?)?.cast<String,dynamic>())??const <String,dynamic>{};
    final rows=(history['rows'] as List? ?? const []).whereType<Map<String,dynamic>>().where((x)=>x['price'] is num&&x['date']?.toString().length==8).map((x)=>PricePoint(x['date'].toString(),(x['price'] as num).toDouble(),resolution:x['resolution']?.toString()??'day')).toList()..sort((a,b)=>a.date.compareTo(b.date));
    return MarketSnapshot.fromJson(price,fromCache:fromCache,history:rows.isEmpty?bundledSnapshot.history:rows);
  }
}
