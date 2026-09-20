import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../models/dashboard_models.dart';
import '../services/price_widget_bridge.dart';
import '../core/network/api_environment.dart';
import '../core/data/data_state.dart';

class MarketSnapshot {
  const MarketSnapshot({required this.price,required this.previousPrice,required this.change,required this.changePct,required this.date,required this.previousDate,required this.updatedAt,required this.source,required this.scope,required this.history,required this.fromCache,this.monthAverage,this.yearAverage});
  final int price,previousPrice,change; final double changePct;
  final String date,previousDate,updatedAt,source,scope; final List<PricePoint> history; final bool fromCache;
  final int? monthAverage,yearAverage;
  factory MarketSnapshot.fromJson(Map<String,dynamic> j,{bool fromCache=false,List<PricePoint> history=const []}){
    final price=(j['price'] as num?)?.round()??0,previous=(j['previousPrice'] as num?)?.round()??0;
    final date=j['date']?.toString()??'',previousDate=j['previousDate']?.toString()??'';
    final source=j['source']?.toString()??'',scope=j['scope']?.toString()??'',unit=j['unit']?.toString()??'';
    if(price<=0||previous<=0||!RegExp(r'^\d{8}$').hasMatch(date)||source!='축산물품질평가원'||!scope.contains('등외제외')||!scope.contains('제주제외')||(unit.isNotEmpty&&unit!='원/kg'))throw const FormatException('Invalid official pig price snapshot');
    final change=price-previous,changePct=double.parse((change/previous*100).toStringAsFixed(2));
    return MarketSnapshot(price:price,previousPrice:previous,change:change,changePct:changePct,date:date,previousDate:previousDate,updatedAt:j['updatedAt']?.toString()??'',source:source,scope:scope,history:history,fromCache:fromCache,monthAverage:(j['monthAverage'] as num?)?.round(),yearAverage:(j['yearAverage'] as num?)?.round());
  }
  PriceSeries seriesFor(int period){
    final daily=history.where((x)=>x.resolution!='month').toList();
    final monthly=_monthly();
    if(period==1)return PriceSeries('1개월',daily.length>22?daily.sublist(daily.length-22):daily);
    if(period==2)return PriceSeries('1년',monthly.length>12?monthly.sublist(monthly.length-12):monthly);
    if(period==3)return PriceSeries('3년',monthly.length>36?monthly.sublist(monthly.length-36):monthly);
    return PriceSeries('7일',daily.length>7?daily.sublist(daily.length-7):daily);
  }
  List<PricePoint> _monthly(){
    final grouped=<String,List<double>>{};
    final official=history.where((x)=>x.resolution=='month').toList();
    for(final x in official){if(x.date.length>=6)grouped[x.date.substring(0,6)]=[x.value];}
    final officialMonths=grouped.keys.toSet();
    for(final x in history.where((x)=>x.resolution!='month')){if(x.date.length>=6&&!officialMonths.contains(x.date.substring(0,6)))grouped.putIfAbsent(x.date.substring(0,6),()=>[]).add(x.value);}
    final keys=grouped.keys.toList()..sort();
    return keys.map((k){final v=grouped[k]!;return PricePoint('${k}01',v.reduce((a,b)=>a+b)/v.length,resolution:'month');}).toList();
  }
}

class MarketRepository {
  static final _priceUrl='${ApiEnvironment.publicDataBaseUrl}/pig-price.json',_historyUrl='${ApiEnvironment.publicDataBaseUrl}/pig-price-history.json';static const _cacheKey='official_dabom_producer_pig_price_v3';
  final http.Client _client; MarketRepository({http.Client? client}):_client=client??http.Client();
  Future<MarketSnapshot?> cached()async{
    final raw=(await SharedPreferences.getInstance()).getString(_cacheKey);
    if(raw==null){
      try{
        final price=jsonDecode(await rootBundle.loadString('assets/data/pig-price.json'));
        final history=jsonDecode(await rootBundle.loadString('assets/data/pig-price-history.json'));
        return _decode({'price':price,'history':history},fromCache:true);
      }catch(_){return null;}
    }
    try{return _decode(jsonDecode(raw) as Map<String,dynamic>,fromCache:true);}catch(_){return null;}
  }
  Future<MarketSnapshot> refresh()async{
    final stamp=DateTime.now().millisecondsSinceEpoch;
    final responses=await Future.wait([_client.get(Uri.parse('$_priceUrl?v=$stamp')).timeout(const Duration(seconds:12)),_client.get(Uri.parse('$_historyUrl?v=$stamp')).timeout(const Duration(seconds:12))]);
    if(responses.any((r)=>r.statusCode!=200))throw Exception('Official data unavailable');
    final combined=<String,dynamic>{'price':jsonDecode(utf8.decode(responses[0].bodyBytes)),'history':jsonDecode(utf8.decode(responses[1].bodyBytes))};
    final value=_decode(combined);await (await SharedPreferences.getInstance()).setString(_cacheKey,jsonEncode(combined));await PriceWidgetBridge.update(price:value.price,previousPrice:value.previousPrice,change:value.change,changePct:value.changePct,date:value.date,updatedAt:value.updatedAt,history:value.seriesFor(0).points);return value;
  }
  Future<DataState<MarketSnapshot>> loadState()async{final cachedValue=await cached();try{final value=await refresh();final fetched=DateTime.now();final sourceTime=DateTime.tryParse(value.updatedAt);final meta=DataMeta(source:value.source,sourceTimestamp:sourceTime,fetchedAt:fetched,lastSuccessfulUpdate:fetched,isStale:false);return DataState.success(value,meta);}catch(error){if(cachedValue==null)return DataState.error(error);final sourceTime=DateTime.tryParse(cachedValue.updatedAt);final stale=sourceTime==null||DateTime.now().difference(sourceTime.toLocal())>const Duration(hours:36);final meta=DataMeta(source:cachedValue.source,sourceTimestamp:sourceTime,fetchedAt:DateTime.now(),lastSuccessfulUpdate:sourceTime,isStale:stale);return stale?DataState.stale(cachedValue,meta):DataState.error(error,lastGood:cachedValue,meta:meta);}}
  MarketSnapshot _decode(Map<String,dynamic> combined,{bool fromCache=false}){
    final price=((combined['price'] as Map?)?.cast<String,dynamic>())??combined;
    final history=((combined['history'] as Map?)?.cast<String,dynamic>())??const <String,dynamic>{};
    final rows=(history['rows'] as List? ?? const []).whereType<Map<String,dynamic>>().where((x)=>x['verified']==true&&x['price'] is num&&x['date']?.toString().length==8).map((x)=>PricePoint(x['date'].toString(),(x['price'] as num).toDouble(),resolution:x['resolution']?.toString()??'day')).toList()..sort((a,b)=>a.date.compareTo(b.date));
    return MarketSnapshot.fromJson(price,fromCache:fromCache,history:rows);
  }
}
