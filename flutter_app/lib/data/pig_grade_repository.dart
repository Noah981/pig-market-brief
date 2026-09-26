import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api/kape_api_client.dart';

class PigGradeSnapshot{
  const PigGradeSnapshot({required this.date,required this.grades,required this.fromCache});
  final String date;final List<KapeGradePrice> grades;final bool fromCache;
}

class PigGradeRepository{
  PigGradeRepository({KapeApiClient? client}):_client=client??KapeApiClient();
  final KapeApiClient _client;static const _key='official_kape_pig_grades_v1';
  Future<PigGradeSnapshot?> cached()async{final raw=(await SharedPreferences.getInstance()).getString(_key);if(raw==null)return null;try{final j=jsonDecode(raw) as Map<String,dynamic>;return PigGradeSnapshot(date:j['date']?.toString()??'',fromCache:true,grades:(j['grades'] as List? ?? const []).whereType<Map>().map((x)=>KapeGradePrice(grade:x['grade'].toString(),price:(x['price'] as num).round(),count:(x['count'] as num?)?.round()??0)).toList());}catch(_){return null;}}
  Future<PigGradeSnapshot> refresh(String ymd)async{try{final grades=await _client.gradePricesFor(ymd);if(grades.isEmpty)throw const FormatException('grade data empty');final result=PigGradeSnapshot(date:ymd,grades:grades,fromCache:false);await (await SharedPreferences.getInstance()).setString(_key,jsonEncode({'date':ymd,'grades':grades.map((x)=>{'grade':x.grade,'price':x.price,'count':x.count}).toList()}));return result;}catch(_){final old=await cached();if(old!=null)return old;rethrow;}}
}
