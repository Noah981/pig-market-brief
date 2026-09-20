import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../settings/farm_location_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/farm_location_picker.dart';
import 'section_pages.dart';

class BenefitPage extends StatefulWidget{const BenefitPage({super.key});@override State<BenefitPage> createState()=>_BenefitPageState();}
class _BenefitPageState extends State<BenefitPage>{List<Map<String,dynamic>> _all=const[];List<Map<String,dynamic>> _status=const[];
 @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_changed);_load();}
 @override void dispose(){FarmLocationSettings.instance.removeListener(_changed);super.dispose();}
 void _changed(){if(mounted)setState((){});}
 Future<void> _load()async{final raw=await rootBundle.loadString('assets/data/platform.json');final json=jsonDecode(raw) as Map<String,dynamic>;if(mounted)setState((){_all=(json['benefits'] as List? ?? const[]).whereType<Map<String,dynamic>>().toList();_status=(json['sourceStatus'] as List? ?? const[]).whereType<Map<String,dynamic>>().toList();});}
 @override Widget build(BuildContext context){final location=FarmLocationSettings.instance.location;final items=_all.where((x){final r=x['region']?.toString()??'';return r.isEmpty||r.contains('전국')||r.contains(location.province)||r.contains(location.cityCounty);}).toList();return PageShell(title:'내 지역 지원사업',subtitle:'${location.label} 기준 공식 공고',child:Column(children:[
  SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()async{await showFarmLocationPicker(context);},icon:const Icon(Icons.location_on_outlined),label:Text('${location.label} · 지역 변경'))),const SizedBox(height:10),
  if(items.isEmpty)Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:18,vertical:28),decoration:appCard(radius:18),child:Column(children:[const Icon(Icons.campaign_outlined,size:35,color:AppColors.secondary),const SizedBox(height:9),const Text('현재 연결된 신규 공식 공고가 없습니다.',style:TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${location.label}에 맞는 공고가 확인되면 이곳에 표시합니다.\n임의의 사업이나 지원금액은 표시하지 않습니다.',textAlign:TextAlign.center,style:const TextStyle(fontSize:9.5,height:1.5,color:AppColors.secondary))]))
  else ...items.map(_card),const SizedBox(height:12),Align(alignment:Alignment.centerLeft,child:Text(_status.isEmpty?'공식 지원사업 데이터 연결 검증 대기':_status.map((x)=>'${x['agency']}: ${x['status']}').join('\n'),style:const TextStyle(fontSize:8.5,height:1.45,color:AppColors.secondary)))
 ]));}
 Widget _card(Map<String,dynamic> x)=>InkWell(onTap:()async{final u=Uri.tryParse(x['url']?.toString()??'');if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);},child:Container(width:double.infinity,margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x['title']?.toString()??'',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${x['region']??''} · ${x['agency']??''}',style:const TextStyle(fontSize:9,color:AppColors.secondary)),const SizedBox(height:5),Text('대상: ${x['target']??'공식 원문 확인'}\n지원: ${x['support']??'공식 원문 확인'}\n마감: ${x['deadline']??'공식 원문 확인'}',style:const TextStyle(fontSize:9.5,height:1.5)),const SizedBox(height:6),const Align(alignment:Alignment.centerRight,child:Text('공식 공고 확인  ›',style:TextStyle(fontSize:9.5,color:AppColors.coral,fontWeight:FontWeight.w800)))])));
}
