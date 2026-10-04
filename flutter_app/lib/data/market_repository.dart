import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/dashboard_models.dart';

class MarketSnapshot {
  const MarketSnapshot({required this.price,required this.previousPrice,required this.change,required this.changePct,required this.date,required this.updatedAt,required this.source,required this.scope,required this.history,required this.fromCache});
  final int price,previousPrice,change; final double changePct;
  final String date,updatedAt,source,scope; final List<PricePoint> history; final bool fromCache;
  factory MarketSnapshot.fromJson(Map<String,dynamic> j,{bool fromCache=false,List<PricePoint> history=const []}){
    if(j['price'] is! num||j['previousPrice'] is! num||!(j['price'] as num).isFinite||!(j['previousPrice'] as num).isFinite)throw const FormatException('Nonfinite official pig price');
    final rawDate=j['date']?.toString()??'',digits=rawDate.replaceAll('-','');
    final parsed=digits.length==8?DateTime.tryParse('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}'):null;
    if(parsed==null||!parsed.toIso8601String().startsWith('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}')||parsed.isAfter(DateTime.now().toUtc().add(const Duration(hours:9))))throw const FormatException('Invalid observation date');
    final price=(j['price'] as num).round(),previous=(j['previousPrice'] as num).round();
    if(price<=0||previous<=0)throw const FormatException('Invalid official pig price');
    return MarketSnapshot(price:price,previousPrice:previous,change:price-previous,changePct:(price-previous)/previous*100,date:j['date']?.toString()??'',updatedAt:j['updatedAt']?.toString()??'',source:j['source']?.toString()??'축산물품질평가원',scope:j['scope']?.toString()??'전국·탕박·등외제외·제주제외',history:history,fromCache:fromCache);
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
  static const _priceUrl='https://noah981.github.io/pig-market-brief/data/pig-price.json',_historyUrl='https://noah981.github.io/pig-market-brief/data/pig-price-history.json',_dabomUrl='https://www.ekapepia.com/v3/web/main.do?userGroup=common',_cacheKey='official_dabom_producer_pig_price_v4';
  final http.Client _client;
  MarketRepository({http.Client? client}):_client=client??http.Client();
  Future<MarketSnapshot?> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null){
      try{return _decode({'price':jsonDecode(await rootBundle.loadString('assets/data/pig-price.json')),'history':jsonDecode(await rootBundle.loadString('assets/data/pig-price-history.json'))},fromCache:true);}catch(_){return null;}
    }
    try{return _decode(jsonDecode(raw) as Map<String,dynamic>,fromCache:true);}catch(_){return null;}
  }
  Future<MarketSnapshot> refresh()async{
    final stamp=DateTime.now().millisecondsSinceEpoch;
    Map<String,dynamic>? received;
    try{
      final responses=await Future.wait([_client.get(Uri.parse('$_priceUrl?v=$stamp')).timeout(const Duration(seconds:12)),_client.get(Uri.parse('$_historyUrl?v=$stamp')).timeout(const Duration(seconds:12))]);
      if(responses.every((r)=>r.statusCode==200)){
        final candidate=<String,dynamic>{'price':jsonDecode(utf8.decode(responses[0].bodyBytes)),'history':jsonDecode(utf8.decode(responses[1].bodyBytes))};
        _decode(candidate);received=candidate;
      }
    }catch(_){ /* The direct official source remains available independently. */ }
    var fresh=received!=null;
    final saved=(await SharedPreferences.getInstance()).getString(_cacheKey);
    final combined=received??(saved!=null?jsonDecode(saved) as Map<String,dynamic>:{'price':jsonDecode(await rootBundle.loadString('assets/data/pig-price.json')),'history':jsonDecode(await rootBundle.loadString('assets/data/pig-price-history.json'))});
    // GitHub snapshot보다 다봄 공식 카드가 최신이면 즉시 교체한다.
    // 대표 돈가는 raw 등급 API를 재계산하지 않고 다봄의 전국(등외·제주 제외)
    // 공표값을 그대로 사용한다.
    try{
      final official=await _fetchDabomHeadline();
      final current=((combined['price'] as Map)['date']??'').toString();
      if(official['date'].toString().compareTo(current)>=0){
        fresh=true;
        final rows=((combined['history'] as Map)['rows'] as List? ?? <dynamic>[]).whereType<Map>().map((x)=>x.cast<String,dynamic>()).toList();
        rows.removeWhere((x)=>x['date']==official['date']);
        rows.add({'date':official['date'],'price':official['price'],'resolution':'day','sourceType':'dabom-headline'});
        rows.sort((a,b)=>a['date'].toString().compareTo(b['date'].toString()));
        final previous=rows.where((x)=>x['date'].toString().compareTo(official['date'].toString())<0&&x['price'] is num&&x['resolution']!='month').lastOrNull;
        final previousPrice=(previous?['price'] as num?)?.round()??official['price'] as int;
        final price=official['price'] as int,change=price-previousPrice;
        combined['price']={...official,'previousPrice':previousPrice,'previousDate':previous?['date']??official['date'],'change':change,'changePct':previousPrice==0?0:change/previousPrice*100};
        combined['history']={'rows':rows};
      }
    }catch(_){/* 검증된 원격 snapshot 유지 */}
    final old=await cached();
    if(!fresh){if(old!=null)return old;throw const FormatException('Official data unavailable');}
    final incomingDate=((combined['price'] as Map)['date']??'').toString();
    if(old!=null&&old.date.compareTo(incomingDate)>0)return old;
    final value=_decode(combined);await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode(combined));return value;
  }
  Future<Map<String,dynamic>> _fetchDabomHeadline()async{
    final response=await _client.get(Uri.parse(_dabomUrl),headers:{'User-Agent':'Mozilla/5.0 Dondonhae/1.0','Accept-Language':'ko-KR,ko;q=0.9'}).timeout(const Duration(seconds:15));
    if(response.statusCode!=200)throw Exception('Dabom unavailable');
    final html=utf8.decode(response.bodyBytes,allowMalformed:true);
    final block=RegExp(r'<div class="main-menu-wrap">[\s\S]*?data-card="auctPig"[\s\S]*?<b>전국\(등외,\s*제주 제외\)</b>[\s\S]*?<em[^>]*>\s*([0-9,]+)\s*</em>[\s\S]*?<div class="main-menu-bottom">\s*<div><b>(\d{2})년\s*(\d{2})월\s*(\d{2})일</b>',caseSensitive:false).firstMatch(html);
    if(block==null)throw const FormatException('Dabom headline missing');
    final price=int.parse(block.group(1)!.replaceAll(',',''));
    if(price<1000||price>20000)throw const FormatException('Dabom price range');
    final date='20${block.group(2)}${block.group(3)}${block.group(4)}';
    return {'source':'축산물품질평가원','sourceUrl':_dabomUrl,'scope':'전국·탕박·등외제외·제주제외','formula':'축산유통정보 다봄 공표 대표값','date':date,'price':price,'updatedAt':DateTime.now().toIso8601String(),'status':'LIVE'};
  }
  MarketSnapshot _decode(Map<String,dynamic> combined,{bool fromCache=false}){
    final price=((combined['price'] as Map?)?.cast<String,dynamic>())??combined;
    final history=((combined['history'] as Map?)?.cast<String,dynamic>())??const <String,dynamic>{};
    final rows=(history['rows'] as List? ?? const []).whereType<Map<String,dynamic>>().where((x)=>x['price'] is num&&x['date']?.toString().length==8).map((x)=>PricePoint(x['date'].toString(),(x['price'] as num).toDouble(),resolution:x['resolution']?.toString()??'day')).toList()..sort((a,b)=>a.date.compareTo(b.date));
    return MarketSnapshot.fromJson(price,fromCache:fromCache,history:rows);
  }
}
