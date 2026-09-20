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
  if(items.isEmpty)Container(width:double.infinity,padding:const EdgeInsets.symmetric(horizontal:18,vertical:28),decoration:appCard(radius:18),child:Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.campaign_outlined,size:35,color:AppColors.secondary),const SizedBox(height:12),const Text('현재 연결된 신규 공식 공고가 없습니다.',textAlign:TextAlign.center,style:TextStyle(fontSize:12,height:1.35,fontWeight:FontWeight.w900)),const SizedBox(height:7),Text('${location.label}에 맞는 공고가 확인되면\n이곳에 표시합니다.\n임의의 사업이나 지원금액은 표시하지 않습니다.',textAlign:TextAlign.center,style:const TextStyle(fontSize:9.5,height:1.55,color:AppColors.secondary))]))
  else ...items.map(_card),const SizedBox(height:12),SizedBox(width:double.infinity,child:OutlinedButton.icon(onPressed:_refresh,icon:const Icon(Icons.refresh),label:const Text('공식 공고 새로고침'))),const SizedBox(height:8),Align(alignment:Alignment.centerLeft,child:Text(_feed?.status.isNotEmpty==true?_feed!.status:'공식 지원사업 데이터 연결 검증 대기',style:const TextStyle(fontSize:8.5,height:1.45,color:AppColors.secondary)))
 ]));}
 Widget _card(BenefitNotice x)=>InkWell(onTap:()=>Navigator.of(context).push(MaterialPageRoute(builder:(_)=>BenefitDetailPage(notice:x))),child:Container(width:double.infinity,margin:const EdgeInsets.only(bottom:9),padding:const EdgeInsets.all(14),decoration:appCard(radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.title,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900)),const SizedBox(height:5),Text('${x.region} · ${x.agency}',style:const TextStyle(fontSize:9,color:AppColors.secondary)),const SizedBox(height:5),Text('대상: ${x.target}\n지원: ${x.support}\n마감: ${x.deadline==null?'공식 원문 확인':x.deadline!.toIso8601String().substring(0,10)}',style:const TextStyle(fontSize:9.5,height:1.5)),const SizedBox(height:6),const Align(alignment:Alignment.centerRight,child:Text('지원사업 상세  ›',style:TextStyle(fontSize:9.5,color:AppColors.coral,fontWeight:FontWeight.w800)))])));
}

class BenefitDetailPage extends StatelessWidget{
 const BenefitDetailPage({super.key,required this.notice});final BenefitNotice notice;
 @override Widget build(BuildContext context)=>Scaffold(backgroundColor:AppColors.background,appBar:AppBar(backgroundColor:AppColors.background,surfaceTintColor:Colors.transparent,leading:IconButton(icon:const Icon(Icons.chevron_left,size:30),onPressed:()=>Navigator.pop(context)),title:const Text('축산 지원사업',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900)),actions:[Container(margin:const EdgeInsets.only(right:16),padding:const EdgeInsets.symmetric(horizontal:11,vertical:7),decoration:BoxDecoration(color:AppColors.lightBlue,borderRadius:BorderRadius.circular(18)),child:const Text('신청가능',style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:AppColors.blue))) ]),body:SafeArea(child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(22,12,22,28),child:Container(padding:const EdgeInsets.fromLTRB(20,22,20,20),decoration:appCard(radius:24),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Text(notice.title,style:const TextStyle(fontSize:22,height:1.35,fontWeight:FontWeight.w900)),const SizedBox(height:22),
  _line('신청기간',notice.deadline==null?'공식 공고에서 확인':'현재 접수 중 ~ ${_date(notice.deadline!)}'),
  _line('지원대상',notice.target),_line('지원내용',notice.support),
  _line('필요서류','신청서, 사업계획서, 증빙서류 등 공식 공고 확인'),
  _line('문의처',notice.agency),const SizedBox(height:24),
  SizedBox(width:double.infinity,height:54,child:FilledButton.icon(onPressed:()=>_open(),style:FilledButton.styleFrom(backgroundColor:AppColors.coral,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(14))),icon:const Icon(Icons.open_in_new,size:19),label:const Text('공고문 보기',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)))),const SizedBox(height:10),const Text('실제 신청 가능 여부와 제출서류는 담당기관의 공식 공고를 반드시 확인하세요.',style:TextStyle(fontSize:9,height:1.45,color:AppColors.secondary))
 ])))));
 Widget _line(String label,String value)=>Container(padding:const EdgeInsets.symmetric(vertical:13),decoration:const BoxDecoration(border:Border(bottom:BorderSide(color:AppColors.divider))),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:76,child:Text(label,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900))),Expanded(child:Text(value,style:const TextStyle(fontSize:11,height:1.45,color:Color(0xFF4B4F59))))]));
 String _date(DateTime x)=>'${x.year}.${x.month.toString().padLeft(2,'0')}.${x.day.toString().padLeft(2,'0')}';
 Future<void> _open()async{final u=Uri.tryParse(notice.url);if(u!=null)await launchUrl(u,mode:LaunchMode.externalApplication);}
}
