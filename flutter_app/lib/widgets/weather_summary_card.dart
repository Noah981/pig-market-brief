import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class WeatherSummaryCard extends StatelessWidget {
  const WeatherSummaryCard({super.key});
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(10),decoration:appCard(color:AppColors.lightBlue,radius:18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Text('🌤️',style:TextStyle(fontSize:27)),const SizedBox(width:5),const Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('오늘 날씨',style:TextStyle(fontSize:15,fontWeight:FontWeight.w900)),Row(crossAxisAlignment:CrossAxisAlignment.end,children:[Text('22°C',style:TextStyle(fontSize:27,height:1,fontWeight:FontWeight.w900)),SizedBox(width:3),Padding(padding:EdgeInsets.only(bottom:2),child:Text('맑음',style:TextStyle(fontSize:8)))])])),const Icon(Icons.location_on,color:AppColors.blue,size:13),const Text('내 위치',style:TextStyle(fontSize:7,color:AppColors.secondary))]),
    const SizedBox(height:8),const Text('최고 28°  |  최저 18°',style:TextStyle(fontSize:10,color:AppColors.secondary)),const SizedBox(height:8),Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[_WeatherFact(Icons.water_drop,'습도','65%'),_WeatherFact(Icons.umbrella,'강수','10%'),_WeatherFact(Icons.air,'바람','2m/s')])),const Spacer(),Container(width:double.infinity,padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:AppColors.lightCoral,borderRadius:BorderRadius.circular(10)),child:const Row(children:[Icon(Icons.thermostat,color:AppColors.coral,size:16),SizedBox(width:5),Expanded(child:Text('낮 기온이 높습니다.\n돈사 온도를 확인하세요.',style:TextStyle(fontSize:7.5,height:1.3,color:AppColors.coral,fontWeight:FontWeight.w700))) ])),
  ]));
}
class _WeatherFact extends StatelessWidget {const _WeatherFact(this.icon,this.label,this.value);final IconData icon;final String label,value;@override Widget build(BuildContext context)=>Column(children:[Icon(icon,color:AppColors.blue,size:13),Text(label,style:const TextStyle(fontSize:6.5,color:AppColors.secondary)),Text(value,style:const TextStyle(fontSize:7.5,fontWeight:FontWeight.w700))]);}
