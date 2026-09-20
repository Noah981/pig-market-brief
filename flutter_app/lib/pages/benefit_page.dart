import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/benefit_repository.dart';
import '../models/benefit_models.dart';
import '../settings/farm_location_settings.dart';
import '../theme/app_theme.dart';
import '../widgets/farm_location_picker.dart';
import 'section_pages.dart';

class BenefitPage extends StatefulWidget{const BenefitPage({super.key});@override State<BenefitPage> createState()=>_BenefitPageState();}
class _BenefitPageState extends State<BenefitPage>{final _repository=BenefitRepository();BenefitFeed? _feed;bool _loading=false;
 @override void initState(){super.initState();FarmLocationSettings.instance.addListener(_changed);_load();}
 @override void dispose(){FarmLocationSettings.instance.removeListener(_changed);super.dispose();}
 void _changed(){if(mounted)setState((){});}
 Future<void> _load()async{try{final cached=await _repository.cached();if(mounted)setState(()=>_feed=cached);}catch(_){}await _refresh();}
 Future<void> _refresh()async{if(_loading)return;if(mounted)setState(()=>_loading=true);try{final fresh=await _repository.refresh();if(mounted)setState(()=>_feed=fresh);}catch(_){}finally{if(mounted)setState(()=>_loading=false);}}
 @override Widget build(BuildContext context){final location=FarmLocationSettings.instance.location;final items=(_feed?.items??const<BenefitNotice>[]).where((x){final r=x.region;return r.isEmpty||r.contains('전국')||r.contains(location.province)||r.contains(location.cityCounty);}).toList();return PageShell(title:'내 지역 지원사업',subtitle:'${location.label} 기준 공식 공고',child:Column(children:[
  SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:()async{await showFarmLocationPicker(context);},icon:const Icon(Icons.location_on_outlined),label:Text('${location.label} · 지역 변경'))),const SizedBox(height:10),
  if(_loading)const LinearProgressIndicator(minHeight:2,color:AppColors.coral),if(_loading)const SizedBox(height:8),
  if(items.isEmpty)Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:18,vertical:28),decoration:appCard(radius:18),child:Column(children:[const Icon(Icons.campaign_outlined,size:35,color:AppColors.secondary),const SizedBox(height:9),const Text('현재 연결된 신규 공식 공고가 없습니다.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${location.label}에 맞는 공고가 확인되면 이곳에 표시합니다.\n임의의 사업이나 지원금액은 표시하지 않습니다.',textAlign:TextAlign.center,style:const TextStyle(fontSize:9.5,height:1.5,color:AppColors.secondary))]))
  else ...items.map(_card),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_refresh,icon:const Icon(Icons.refresh),label:const Text('공식 공고 새로고침'))),const SizedBox(height:8),Align(alignment:Alignment.centerLeft,child:Text(_feed?.status.isNotEmpty==true?_feed!.status:'공식 지원사업 데이터 연결 검증 대기',style:const TextStyle(fontSize:8.5,height:1.45,color:AppColors.secondary)))
 ]));}
 Widget _card(BenefitNotice x)=>InkWell(onTap:()async{final u=Uri.tryParse(x.url);if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);},child:Container(width:double.infinity,margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${x.region} · ${x.agency}',style:const TextStyle(fontSize:9,color:AppColors.secondary)),const SizedBox(height:5),Text('대상: ${x.target}\n지원: ${x.support}\n마감: ${x.deadline==null?'공식 원문 확인':x.deadline!.toIso8601String().substring(0,10)}',style:const TextStyle(fontSize:9.5,height:1.5)),const SizedBox(height:6),const Align(alignment:Alignment.centerRight,child:Text('공식 공고 확인  ›',style:TextStyle(fontSize:9.5,color:AppColors.coral,fontWeight:FontWeight.w800)))])));
}
