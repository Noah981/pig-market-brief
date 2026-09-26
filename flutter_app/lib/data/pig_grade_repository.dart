import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/kape_api_client.dart';

class PigGradeSnapshot{
  const PigGradeSnapshot({required this.date,required this.grades,required this.history,required this.fromCache});
  final String date;final List<KapeGradePrice> grades,history;final bool fromCache;
  KapeGradePrice? previous(String grade){final rows=history.where((x)=>x.grade==grade&&x.date!=date).toList();return rows.isEmpty?null:rows.last;}
}

class PigGradeRepository{
  PigGradeRepository({KapeApiClient? client}):_client=client??KapeApiClient();
  final KapeApiClient _client;static const _key='official_kape_pig_grades_v1';
  KapeGradePrice _row(Map x)=>KapeGradePrice(grade:x['grade'].toString(),price:(x['price'] as num).round(),count:(x['count'] as num?)?.round()??0,date:x['date']?.toString()??'');
  Future<PigGradeSnapshot?> cached()async{final raw=(await SharedPreferences.getInstance()).getString(_key);if(raw==null)return null;try{final j=jsonDecode(raw) as Map<String,dynamic>;final history=(j['history'] as List? ?? j['grades'] as List? ?? const []).whereType<Map>().map(_row).toList();final date=j['date']?.toString()??'';return PigGradeSnapshot(date:date,fromCache:true,grades:history.where((x)=>x.date==date).toList(),history:history);}catch(_){return null;}}
  Future<PigGradeSnapshot> refresh(String ymd)async{try{final history=await _client.gradeHistory(ymd);if(history.isEmpty)throw const FormatException('grade data empty');final date=history.last.date,grades=history.where((x)=>x.date==date).toList();final result=PigGradeSnapshot(date:date,grades:grades,history:history,fromCache:false);Map<String,Object> row(KapeGradePrice x)=>{'grade':x.grade,'price':x.price,'count':x.count,'date':x.date};await (await SharedPreferences.getInstance()).setString(_key,jsonEncode({'date':date,'history':history.map(row).toList()}));return result;}catch(_){final old=await cached();if(old!=null)return old;rethrow;}}
}
