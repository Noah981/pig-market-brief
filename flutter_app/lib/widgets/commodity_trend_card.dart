import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class CommodityTrendCard extends StatelessWidget {
  const CommodityTrendCard({super.key,required this.items,this.onTap});
  final List<Commodity> items;
  final ValueChanged<Commodity>? onTap;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(13,12,13,13),decoration:appCard(color:const Color(0xFFFFF3F6),radius:20),child:Column(children:[
    const Row(children:[Icon(Icons.bar_chart,color:AppColors.coral,size:24),SizedBox(width:7),Expanded(child:Text('국제정세 & 원료 동향',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),Icon(Icons.chevron_right,size:22)]),const SizedBox(height:10),
    SizedBox(height:112,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:7),itemBuilder:(context,i){final x=items[i];final up=(x.change??0)>=0;return Material(color:Colors.white,borderRadius:BorderRadius.circular(13),child:InkWell(key:ValueKey('commodity_${x.id}'),onTap:()=>onTap?.call(x),borderRadius:BorderRadius.circular(13),child:Container(width:105,padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[Icon(x.icon,size:22,color:i==0?AppColors.green:i==2?const Color(0xFF293249):const Color(0xFFE5A62B)),const SizedBox(width:5),Expanded(child:Text(x.name,style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800),maxLines:2))]),const Spacer(),Text('${x.value} ${x.unit}',style:const TextStyle(fontSize:10.5,fontWeight:FontWeight.w800),maxLines:1),const SizedBox(height:3),x.change==null?const Text('공식 데이터 연결 대기',style:TextStyle(fontSize:7.5,color:AppColors.secondary)):Text('${up?'▲':'▼'} ${x.change!.abs().toStringAsFixed(1)}%',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:up?AppColors.coral:AppColors.blue))]))));})),
  ]));
}
