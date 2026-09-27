import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/kape_api_client.dart';

class PigGradeSnapshot{
  const PigGradeSnapshot({required this.date,required this.grades,required this.history,required this.fromCache,this.auctionStatus});
  final String date;final List<KapeGradePrice> grades,history;final bool fromCache;final KapeAuctionStatus? auctionStatus;
  KapeGradePrice? previous(String grade){final rows=history.where((x)=>x.grade==grade&&x.date!=date).toList();return rows.isEmpty?null:rows.last;}
}

class PigGradeRepository{
  PigGradeRepository({KapeApiClient? client}):_client=client??KapeApiClient();
  final KapeApiClient _client;static const _key='official_kape_pig_grades_v1';
  KapeGradePrice _row(Map x)=>KapeGradePrice(grade:x['grade'].toString(),price:(x['price'] as num).round(),count:(x['count'] as num?)?.round()??0,date:x['date']?.toString()??'');
  KapeAuctionStatus? _status(Map<String,dynamic> j){final x=j['auctionStatus'];if(x is! Map)return null;return KapeAuctionStatus(date:x['date']?.toString()??'',totalCount:(x['totalCount'] as num?)?.round()??0,castratedCount:(x['castratedCount'] as num?)?.round()??0,femaleCount:(x['femaleCount'] as num?)?.round()??0,averageCarcassWeight:(x['averageCarcassWeight'] as num?)?.toDouble());}
  Future<PigGradeSnapshot?> cached()async{final raw=(await SharedPreferences.getInstance()).getString(_key);if(raw==null)return null;try{final j=jsonDecode(raw) as Map<String,dynamic>;final history=(j['history'] as List? ?? j['grades'] as List? ?? const []).whereType<Map>().map(_row).toList();final date=j['date']?.toString()??'';return PigGradeSnapshot(date:date,fromCache:true,grades:history.where((x)=>x.date==date).toList(),history:history,auctionStatus:_status(j));}catch(_){return null;}}
  Future<PigGradeSnapshot> refresh(String ymd)async{try{
    final live=await _client.latestDabom(endYmd:ymd);
    final old=await cached();
    final byKey=<String,KapeGradePrice>{};
    for(final item in old?.history??const <KapeGradePrice>[]){byKey['${item.date}:${item.grade}']=item;}
    for(final item in live.grades){byKey['${item.date}:${item.grade}']=item;}
    final history=byKey.values.toList()..sort((a,b){final d=a.date.compareTo(b.date);return d!=0?d:a.grade.compareTo(b.grade);});
    final result=PigGradeSnapshot(date:live.date,grades:live.grades,history:history,fromCache:false,auctionStatus:live.auctionStatus);
    Map<String,Object?> row(KapeGradePrice x)=>{'grade':x.grade,'price':x.price,'count':x.count,'date':x.date};
    final status=live.auctionStatus;
    await (await SharedPreferences.getInstance()).setString(_key,jsonEncode({'date':live.date,'history':history.map(row).toList(),'auctionStatus':{'date':status.date,'totalCount':status.totalCount,'castratedCount':status.castratedCount,'femaleCount':status.femaleCount,'averageCarcassWeight':status.averageCarcassWeight}}));
    return result;
  }catch(_){final old=await cached();if(old!=null)return old;rethrow;}}
}
