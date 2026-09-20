import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/benefit_models.dart';
import '../services/notification_service.dart';
import '../settings/farm_location_settings.dart';
import '../core/network/api_environment.dart';

class BenefitRepository{
 BenefitRepository({http.Client? client}):_client=client??http.Client();final http.Client _client;
 static final _url='${ApiEnvironment.publicDataBaseUrl}/platform.json';static const _cache='benefit_feed_v1',_seen='benefit_seen_ids_v1';
 Future<BenefitFeed> cached()async{final p=await SharedPreferences.getInstance();final raw=p.getString(_cache)??await rootBundle.loadString('assets/data/platform.json');return _parse(raw,true);}
 Future<BenefitFeed> refresh({bool notify=true})async{final response=await _client.get(Uri.parse('$_url?v=${DateTime.now().millisecondsSinceEpoch}')).timeout(const Duration(seconds:15));if(response.statusCode!=200)throw Exception('benefits unavailable');final raw=utf8.decode(response.bodyBytes),feed=_parse(raw,false);final p=await SharedPreferences.getInstance();if(notify)await _notifyNew(feed,p);await p.setString(_cache,raw);return feed;}
 BenefitFeed _parse(String raw,bool cached){final json=jsonDecode(raw) as Map<String,dynamic>;final items=(json['benefits'] as List? ?? const[]).whereType<Map<String,dynamic>>().map(BenefitNotice.fromJson).where((x)=>x.id.isNotEmpty&&x.title.isNotEmpty&&x.url.startsWith('https://')).toList();final status=(json['sourceStatus'] as List? ?? const[]).whereType<Map<String,dynamic>>().map((x)=>'${x['agency']}: ${x['status']}').join('\n');return BenefitFeed(items:items,status:status,fromCache:cached);}
 Future<void> _notifyNew(BenefitFeed feed,SharedPreferences p)async{final previous=p.getStringList(_seen);final ids=feed.items.map((x)=>x.id).toSet();if(previous!=null){final location=FarmLocationSettings.instance.location;for(final x in feed.items.where((x)=>!previous.contains(x.id)&&_matches(x,location)).take(3)){await NotificationService.instance.newBenefit(location.label,x.title);}}await p.setStringList(_seen,ids.toList());}
 bool _matches(BenefitNotice x,FarmLocation l)=>x.region.isEmpty||x.region.contains('전국')||x.region.contains(l.province)||x.region.contains(l.cityCounty);
}
