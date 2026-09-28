import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/widget_update_service.dart';

class TodoRecord{
  const TodoRecord({required this.id,required this.title,required this.date,this.done=false,this.priority=0,this.createdAt='' });
  final String id,title,date,createdAt;
  final bool done;
  final int priority;
  Map<String,Object?> toJson()=>{'id':id,'title':title,'date':date,'done':done,'priority':priority,'createdAt':createdAt};
  factory TodoRecord.fromJson(Map<String,dynamic> x)=>TodoRecord(id:x['id']?.toString()??'',title:x['title']?.toString()??'',date:x['date']?.toString()??'',done:x['done']==true,priority:(x['priority'] as num?)?.round()??0,createdAt:x['createdAt']?.toString()??'');
}

class TodoRepository{
  static const cacheKey='widget_tasks_v1';
  Future<List<TodoRecord>> all()async{
    final raw=(await SharedPreferences.getInstance()).getString(cacheKey);
    if(raw==null)return const [];
    try{return (jsonDecode(raw) as List).whereType<Map>().map((x)=>TodoRecord.fromJson(x.cast<String,dynamic>())).where((x)=>x.title.trim().isNotEmpty).toList();}catch(_){return const [];}
  }
  Future<List<TodoRecord>> today([DateTime? value])async{
    final now=value??DateTime.now(),ymd='${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}';
    final rows=(await all()).where((x)=>x.date==ymd&&!x.done).toList()..sort((a,b){final p=b.priority.compareTo(a.priority);return p!=0?p:a.createdAt.compareTo(b.createdAt);});
    return rows;
  }
  Future<void> save(List<TodoRecord> rows)async{await (await SharedPreferences.getInstance()).setString(cacheKey,jsonEncode(rows.map((x)=>x.toJson()).toList()));await WidgetUpdateService.updateAll();}
}
