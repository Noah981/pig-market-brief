import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CacheEnvelope {
  const CacheEnvelope({required this.payload,required this.source,required this.sourceTimestamp,required this.fetchedAt,required this.lastSuccessfulUpdate});
  final Map<String,dynamic> payload;final String source,sourceTimestamp,fetchedAt,lastSuccessfulUpdate;
  Map<String,dynamic> toJson()=>{'schemaVersion':1,'payload':payload,'source':source,'sourceTimestamp':sourceTimestamp,'fetchedAt':fetchedAt,'lastSuccessfulUpdate':lastSuccessfulUpdate};
  factory CacheEnvelope.fromJson(Map<String,dynamic> json)=>CacheEnvelope(payload:(json['payload'] as Map).cast<String,dynamic>(),source:json['source']?.toString()??'',sourceTimestamp:json['sourceTimestamp']?.toString()??'',fetchedAt:json['fetchedAt']?.toString()??'',lastSuccessfulUpdate:json['lastSuccessfulUpdate']?.toString()??'');
}

class JsonCacheStore {
  const JsonCacheStore();
  Future<CacheEnvelope?> read(String key)async{final raw=(await SharedPreferences.getInstance()).getString(key);if(raw==null)return null;try{return CacheEnvelope.fromJson(jsonDecode(raw) as Map<String,dynamic>);}catch(_){return null;}}
  Future<void> write(String key,CacheEnvelope value)async{await (await SharedPreferences.getInstance()).setString(key,jsonEncode(value.toJson()));}
}
