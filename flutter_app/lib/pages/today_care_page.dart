import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../data/weather_farm_repository.dart';
import '../models/weather_farm_models.dart';
import '../theme/app_theme.dart';
import 'section_pages.dart';
import '../settings/farm_location_settings.dart';
import '../widgets/farm_location_picker.dart';

class TodayCarePage extends StatefulWidget{
  const TodayCarePage({super.key,required this.guide,required this.onRefresh});
  final WeatherFarmGuide guide;final Future<void> Function() onRefresh;
  @override State<TodayCarePage> createState()=>_TodayCarePageState();
}
class _TodayCarePageState extends State<TodayCarePage>{
  String _vetName='담당 수의사',_vetPhone='';
  @override void initState(){super.initState();_loadVet();}
  Future<void> _loadVet()async{final p=await SharedPreferences.getInstance();if(mounted)setState((){_vetName=p.getString('farm_vet_name')??'담당 수의사';_vetPhone=p.getString('farm_vet_phone')??'';});}
  @override Widget build(BuildContext context){
    final w=widget.guide,repository=WeatherFarmRepository(),risks=repository.risks(w),seasonal=repository.seasonalDiseases(DateTime.now(),w);
    return PageShell(title:'오늘 관리',subtitle:'날씨에 맞춰 질병 신호와 환기·시설을 함께 확인하세요',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      _weather(w),const SizedBox(height:14),_title('${DateTime.now().month}월에 주의할 질환군',Icons.coronavirus_outlined),
      const Text('계절과 돈사 환경을 기준으로 미리 관찰할 질환군입니다. 전국 발생 순위나 진단 결과가 아닙니다.',style:TextStyle(fontSize:9.5,height:1.45,color:AppColors.secondary)),const SizedBox(height:8),
      ...seasonal.map(_seasonalDisease),
      const SizedBox(height:10),_title('오늘 주의할 건강 신호',Icons.health_and_safety_outlined),
      ...risks.map(_risk),const SizedBox(height:10),_title('오늘의 환기·점검 포인트',Icons.air),
      ...w.checks.take(6).toList().asMap().entries.map((x)=>_check(x.key+1,x.value)),
      const SizedBox(height:12),_vetCard(),const SizedBox(height:12),_title('약품·예방 정보',Icons.medication_outlined),
      const Text('증상에 따라 검토되는 약품 계열을 안내합니다. 특정 제품·투여량·치료방법을 추천하지 않습니다.',style:TextStyle(fontSize:9.5,height:1.45,color:AppColors.secondary)),const SizedBox(height:8),
      ...WeatherFarmRepository.medicines.map(_medicine),
      Container(width:double.infinity,padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFF1DC),borderRadius:BorderRadius.circular(14)),child:const Text('중요: 돈돈해의 정보는 수의학적 진단·처방을 대신하지 않습니다. 약품과 백신은 반드시 담당 수의사의 진단과 결정에 따라 사용하고, 제품 표시사항과 휴약기간을 준수하세요.',style:TextStyle(fontSize:9.5,height:1.5,fontWeight:FontWeight.w800,color:Color(0xFF8A5600)))),
      const SizedBox(height:10),const Text('호흡곤란, 고열, 집단 폐사, 혈변·심한 설사처럼 급격한 이상이 나타나면 앱 안내보다 먼저 담당 수의사와 방역기관에 연락하세요.',style:TextStyle(fontSize:9,height:1.45,color:AppColors.secondary)),
    ]));
  }
  Widget _weather(WeatherFarmGuide w)=>Container(padding:const EdgeInsets.all(14),decoration:appCard(color:AppColors.lightBlue,radius:18),child:Column(children:[
    Row(children:[const Text('🌤️',style:TextStyle(fontSize:30)),const SizedBox(width:8),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[InkWell(onTap:_pickRegion,child:Row(children:[Flexible(child:Text(FarmLocationSettings.instance.location.label,style:const TextStyle(fontSize:11,color:AppColors.secondary))),const Icon(Icons.expand_more,size:15,color:AppColors.secondary)])),Text('${w.tempMax.toStringAsFixed(0)}°C · ${w.condition}',style:const TextStyle(fontSize:23,fontWeight:FontWeight.w900))])),IconButton(onPressed:widget.onRefresh,icon:const Icon(Icons.refresh,color:AppColors.blue))]),
    const SizedBox(height:8),Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_fact('최저','${w.tempMin.toStringAsFixed(0)}°'),_fact('일교차','${w.diurnalRange.toStringAsFixed(0)}°'),_fact('최고습도','${w.humidity.toStringAsFixed(0)}%'),_fact('강수','${w.rainProbability.toStringAsFixed(0)}%')]),
    const SizedBox(height:8),Align(alignment:Alignment.centerLeft,child:Text('출처: ${w.source}${w.fromCache?' · 마지막 저장 데이터':''}',style:const TextStyle(fontSize:8,color:AppColors.secondary))),
  ]));
  Widget _fact(String a,String b)=>Column(children:[Text(a,style:const TextStyle(fontSize:8,color:AppColors.secondary)),Text(b,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w800))]);
  Widget _title(String text,IconData icon)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(children:[Icon(icon,size:20,color:AppColors.coral),const SizedBox(width:6),Text(text,style:const TextStyle(fontSize:14,fontWeight:FontWeight.w900))]));
  Widget _risk(FarmHealthRisk x)=>Container(margin:const EdgeInsets.only(bottom:8),padding:const EdgeInsets.all(12),decoration:appCard(radius:14),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Expanded(child:Text(x.title,style:const TextStyle(fontSize:11.5,fontWeight:FontWeight.w900))),Container(padding:const EdgeInsets.symmetric(horizontal:8,vertical:4),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(20)),child:Text(x.level,style:const TextStyle(fontSize:8,color:AppColors.coral,fontWeight:FontWeight.w800)))]),const SizedBox(height:5),Text(x.reason,style:const TextStyle(fontSize:9.5,height:1.45,color:AppColors.secondary)),const SizedBox(height:5),Text('관찰: ${x.signs}',style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))]));
  Widget _seasonalDisease(SeasonalDiseaseGuide x)=>ExpansionTile(tilePadding:const EdgeInsets.symmetric(horizontal:12),childrenPadding:const EdgeInsets.fromLTRB(12,0,12,12),collapsedShape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13),side:const BorderSide(color:AppColors.divider)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13),side:const BorderSide(color:AppColors.divider)),title:Text(x.name,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),subtitle:Text(x.signs,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8.5,color:AppColors.secondary)),children:[_detailLine('왜 지금 보나요?',x.whyNow),_detailLine('대표 증상',x.signs),_detailLine('구분할 점',x.differentiate),_detailLine('바로 연락할 때',x.urgency)]);
  Widget _detailLine(String title,String body)=>Padding(padding:const EdgeInsets.only(bottom:7),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[SizedBox(width:76,child:Text(title,style:const TextStyle(fontSize:9,fontWeight:FontWeight.w900,color:AppColors.coral))),Expanded(child:Text(body,style:const TextStyle(fontSize:9,height:1.4)))]));
  Widget _check(int n,String text)=>Container(margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(11),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(13),border:Border.all(color:AppColors.divider)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[CircleAvatar(radius:11,backgroundColor:AppColors.lightCoral,child:Text('$n',style:const TextStyle(fontSize:8,color:AppColors.coral,fontWeight:FontWeight.w900))),const SizedBox(width:8),Expanded(child:Text(text,style:const TextStyle(fontSize:10,height:1.45)))]));
  Widget _medicine(MedicineGuide x)=>ExpansionTile(tilePadding:const EdgeInsets.symmetric(horizontal:12),childrenPadding:const EdgeInsets.fromLTRB(12,0,12,12),collapsedShape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13),side:const BorderSide(color:AppColors.divider)),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(13),side:const BorderSide(color:AppColors.divider)),title:Text(x.category,style:const TextStyle(fontSize:11,fontWeight:FontWeight.w900)),subtitle:Text(x.use,style:const TextStyle(fontSize:8.5,color:AppColors.secondary)),children:[Text(x.caution,style:const TextStyle(fontSize:9.5,height:1.45))]);
  Widget _vetCard()=>Container(padding:const EdgeInsets.all(13),decoration:appCard(color:const Color(0xFFF4F8FF),radius:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('수의사 연결',style:TextStyle(fontSize:14,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(_vetPhone.isEmpty?'담당 수의사를 등록하면 이상 징후가 있을 때 바로 전화할 수 있습니다.':'$_vetName · $_vetPhone',style:const TextStyle(fontSize:9.5,color:AppColors.secondary)),const SizedBox(height:9),Row(children:[Expanded(child:OutlinedButton(onPressed:_editVet,child:Text(_vetPhone.isEmpty?'수의사 등록':'정보 수정'))),const SizedBox(width:7),Expanded(child:FilledButton.icon(onPressed:_vetPhone.isEmpty?null:_callVet,icon:const Icon(Icons.call,size:16),label:const Text('전화 상담'),style:FilledButton.styleFrom(backgroundColor:AppColors.blue)))]),const SizedBox(height:5),const Text('연결되는 수의사가 진료·처방을 결정합니다. 앱은 상담 결과나 치료 결과를 보증하지 않습니다.',style:TextStyle(fontSize:8,height:1.35,color:AppColors.secondary))]));
  Future<void> _callVet()async{final clean=_vetPhone.replaceAll(RegExp(r'[^0-9+]'),'');if(clean.isNotEmpty)await launchUrl(Uri.parse('tel:$clean'));}
  Future<void> _editVet()async{
    final name=TextEditingController(text:_vetName=='담당 수의사'?'':_vetName),phone=TextEditingController(text:_vetPhone);
    await showDialog(context:context,builder:(context)=>AlertDialog(title:const Text('담당 수의사 등록'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'이름 또는 동물병원')),TextField(controller:phone,keyboardType:TextInputType.phone,decoration:const InputDecoration(labelText:'전화번호'))]),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('취소')),FilledButton(onPressed:()async{final p=await SharedPreferences.getInstance();await p.setString('farm_vet_name',name.text.trim());await p.setString('farm_vet_phone',phone.text.trim());if(context.mounted)Navigator.pop(context);if(mounted)setState((){_vetName=name.text.trim().isEmpty?'담당 수의사':name.text.trim();_vetPhone=phone.text.trim();});},child:const Text('저장'))]));
  }
  Future<void> _pickRegion()async{await showFarmLocationPicker(context);if(mounted)setState((){});}
}
