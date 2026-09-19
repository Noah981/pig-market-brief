import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/disease_repository.dart';
import '../models/disease_models.dart';
import '../theme/app_theme.dart';
import '../widgets/korea_disease_map.dart';
import 'section_pages.dart';

class DiseasePage extends StatefulWidget{const DiseasePage({super.key});@override State<DiseasePage> createState()=>_DiseasePageState();}
class _DiseasePageState extends State<DiseasePage>{
  final _repository=DiseaseRepository();DiseaseFeed? _feed;int _tab=0;double? _lat,_lng;String _location='위치 설정';String? _message;
  @override void initState(){super.initState();_load();}
  Future<void> _load()async{try{final cached=await _repository.cached();if(mounted)setState(()=>_feed=cached);}catch(_){}await _refresh();}
  Future<void> _refresh()async{try{final value=await _repository.refresh();if(mounted)setState(()=>_feed=value);}catch(_){if(mounted)setState(()=>_message='통신이 원활하지 않아 마지막 저장 정보를 표시합니다.');}}
  List<DiseaseAlert> get _items=>(_feed?.items??const []).where((x)=>x.scope==(_tab==0?'국내':'국외')).toList();
  Future<void> _useGps()async{
    if(!await Geolocator.isLocationServiceEnabled()){setState(()=>_message='위치 서비스가 꺼져 있습니다. 지역을 직접 선택해주세요.');return;}
    var permission=await Geolocator.checkPermission();if(permission==LocationPermission.denied)permission=await Geolocator.requestPermission();
    if(permission==LocationPermission.denied||permission==LocationPermission.deniedForever){setState(()=>_message='위치 권한 없이도 지역을 직접 선택할 수 있습니다.');return;}
    final p=await Geolocator.getCurrentPosition(locationSettings:const LocationSettings(accuracy:LocationAccuracy.medium,timeLimit:Duration(seconds:10)));
    if(mounted)setState((){_lat=p.latitude;_lng=p.longitude;_location='현재 위치';_message=null;});
  }
  void _pickRegion(){
    const regions=<String,(double,double)>{'경북 김천':(36.139,128.114),'경북 상주':(36.410,128.159),'경북 문경':(36.586,128.186),'경북 성주':(35.919,128.283),'경북 고령':(35.726,128.263),'경북 칠곡':(35.995,128.401),'대구 군위':(36.242,128.573),'대구 달성':(35.774,128.431)};
    showModalBottomSheet(context:context,showDragHandle:true,builder:(context)=>SafeArea(child:ListView(shrinkWrap:true,children:[const ListTile(title:Text('지역을 선택하세요',style:TextStyle(fontWeight:FontWeight.w900))),...regions.entries.map((x)=>ListTile(title:Text(x.key),onTap:(){setState((){_location=x.key;_lat=x.value.$1;_lng=x.value.$2;_message=null;});Navigator.pop(context);})),])));
  }
  @override Widget build(BuildContext context)=>PageShell(title:'질병 정보',subtitle:'공식 확인과 공개정보 신호를 구분해 보여드립니다',child:Column(children:[
    _tabs(),const SizedBox(height:10),_counts(),const SizedBox(height:10),
    if(_message!=null)Container(width:double.infinity,margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(11)),child:Text(_message!,style:const TextStyle(fontSize:9.5,color:AppColors.coral))),
    if(_tab==0)...[_locationBar(),const SizedBox(height:8),Container(padding:const EdgeInsets.fromLTRB(8,8,8,6),decoration:appCard(radius:16),child:KoreaDiseaseMap(items:_items,onTap:_detail,userLatitude:_lat,userLongitude:_lng))]
    else Container(width:double.infinity,padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:const Row(children:[Icon(Icons.public,color:AppColors.blue),SizedBox(width:9),Expanded(child:Text('해외 정보는 국가가 확인된 항목만 표시합니다.\n해외 발생을 국내 지도에 표시하지 않습니다.',style:TextStyle(fontSize:10.5,height:1.45)))])),
    const SizedBox(height:16),Row(children:[const Expanded(child:Text('최근 확인 정보',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900))),Text(_updated(),style:const TextStyle(fontSize:8,color:AppColors.secondary))]),const SizedBox(height:5),
    if(_items.isEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:30),child:Text('현재 확인된 항목이 없습니다.\n새로운 공식 발표가 확인되면 업데이트합니다.',textAlign:TextAlign.center,style:TextStyle(fontSize:11,height:1.5,color:AppColors.secondary)))
    else ..._items.take(12).map(_row),
  ]));
  Widget _tabs()=>Container(height:38,padding:const EdgeInsets.all(3),decoration:BoxDecoration(color:const Color(0xFFF4F4F6),borderRadius:BorderRadius.circular(16)),child:Row(children:List.generate(2,(i)=>Expanded(child:InkWell(onTap:()=>setState(()=>_tab=i),child:Container(alignment:Alignment.center,decoration:BoxDecoration(color:_tab==i?AppColors.coral:Colors.transparent,borderRadius:BorderRadius.circular(13)),child:Text(i==0?'국내':'해외',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:_tab==i?Colors.white:AppColors.secondary))))))));
  Widget _counts(){final names=['ASF','구제역','PED','PRRS'];return Row(children:names.map((name){final official=_items.where((x)=>x.disease==name&&x.isOfficial).length;final signal=_items.where((x)=>x.disease==name&&!x.isOfficial).length;return Expanded(child:Container(margin:const EdgeInsets.symmetric(horizontal:2),padding:const EdgeInsets.symmetric(vertical:7),decoration:BoxDecoration(color:const Color(0xFFF8F8FA),borderRadius:BorderRadius.circular(12)),child:Column(children:[Text(name,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w800)),Text('공식 $official · 확인 $signal',style:TextStyle(fontSize:7,color:official>0?AppColors.coral:AppColors.secondary))])));}).toList());}
  Widget _locationBar()=>Row(children:[Expanded(child:OutlinedButton.icon(onPressed:_pickRegion,icon:const Icon(Icons.map_outlined,size:17),label:Text(_location,overflow:TextOverflow.ellipsis),style:OutlinedButton.styleFrom(minimumSize:const Size(0,42),foregroundColor:const Color(0xFF4B5A70),side:const BorderSide(color:AppColors.divider)))),const SizedBox(width:7),FilledButton.icon(onPressed:_useGps,icon:const Icon(Icons.my_location,size:16),label:const Text('GPS'),style:FilledButton.styleFrom(minimumSize:const Size(94,42),backgroundColor:AppColors.blue))]);
  Widget _row(DiseaseAlert x){final distance=_distance(x);return InkWell(onTap:()=>_detail(x),child:Container(padding:const EdgeInsets.symmetric(vertical:10),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AppColors.divider))),child:Row(children:[Container(width:44,padding:const EdgeInsets.symmetric(vertical:5),decoration:BoxDecoration(color:x.isOfficial?AppColors.lightCoral:const Color(0xFFFFF1DC),borderRadius:BorderRadius.circular(20)),child:Text(x.disease,textAlign:TextAlign.center,style:TextStyle(fontSize:8,fontWeight:FontWeight.w800,color:x.isOfficial?AppColors.coral:const Color(0xFFB36A00)))),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.summary,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w700)),Text('${x.scope}${x.region==null?'':' · ${x.region}'} · ${x.level}${distance==null?'':' · ${distance.toStringAsFixed(0)}km'}',style:const TextStyle(fontSize:8,color:AppColors.secondary))])),const Icon(Icons.chevron_right,size:18,color:AppColors.secondary)])));}
  void _detail(DiseaseAlert x)=>showModalBottomSheet(context:context,showDragHandle:true,isScrollControlled:true,builder:(context)=>SafeArea(child:Padding(padding:const EdgeInsets.fromLTRB(20,0,20,20),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${x.disease} · ${x.scope}',style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:8),Text(x.level,style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:x.isOfficial?AppColors.coral:const Color(0xFFB36A00))),const SizedBox(height:10),Text(x.summary,style:const TextStyle(fontSize:12,height:1.55)),const SizedBox(height:12),Text('지역: ${x.region??(x.scope=='국외'?x.countryCode:'지역 확인 중')}\n발표: ${_date(x.publishedAt)}\n출처: ${x.source}${_distance(x)==null?'':'\n설정 위치와 약 ${_distance(x)!.toStringAsFixed(0)}km'}',style:const TextStyle(fontSize:10.5,height:1.55,color:AppColors.secondary)),const SizedBox(height:14),SizedBox(width:double.infinity,height:46,child:FilledButton(onPressed:x.sourceUrl.isEmpty?null:()async{final uri=Uri.tryParse(x.sourceUrl);if(uri!=null)await launchUrl(uri,mode:LaunchMode.externalApplication);},style:FilledButton.styleFrom(backgroundColor:AppColors.coral),child:const Text('원문 확인'))),const SizedBox(height:8),const Text('공개정보·확인중 항목은 공식 확진으로 해석하지 마세요.',style:TextStyle(fontSize:9,color:AppColors.secondary))]))));
  double? _distance(DiseaseAlert x){if(_lat==null||_lng==null||x.latitude==null||x.longitude==null)return null;const r=6371.0;final dLat=_rad(x.latitude!-_lat!),dLng=_rad(x.longitude!-_lng!);final a=math.sin(dLat/2)*math.sin(dLat/2)+math.cos(_rad(_lat!))*math.cos(_rad(x.latitude!))*math.sin(dLng/2)*math.sin(dLng/2);return r*2*math.atan2(math.sqrt(a),math.sqrt(1-a));}
  double _rad(double value)=>value*math.pi/180;
  String _date(String value)=>value.length>=10?value.substring(0,10):value;
  String _updated(){final value=_feed?.updatedAt??'';return value.length>=10?'업데이트 ${value.substring(0,10)}':'';}
}
