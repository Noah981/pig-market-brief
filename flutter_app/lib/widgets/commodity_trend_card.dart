import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import '../settings/display_settings.dart';

class CommodityTrendCard extends StatelessWidget {
  const CommodityTrendCard({super.key,required this.items,this.onTap,this.onHeaderTap});
  final List<Commodity> items;
  final ValueChanged<Commodity>? onTap;
  final VoidCallback? onHeaderTap;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(13,12,13,13),decoration:appCard(color:const Color(0xFFFFF3F6),radius:20),child:Column(children:[
    InkWell(key:const ValueKey('international_market_header'),onTap:onHeaderTap,child:const SizedBox(height:38,child:Row(children:[Icon(Icons.bar_chart,color:AppColors.coral,size:24),SizedBox(width:7),Expanded(child:Text('국제정세 & 원료 동향',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),Icon(Icons.chevron_right,size:22)]))),const SizedBox(height:10),
    SizedBox(height:DisplaySettings.instance.largeTextMode?194:DisplaySettings.instance.textScale>=1.3?166:142,child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:8),itemBuilder:(context,i){final x=items[i];final up=(x.change??0)>=0;return Material(color:Colors.white,borderRadius:BorderRadius.circular(15),child:InkWell(key:ValueKey('commodity_${x.id}'),onTap:()=>onTap?.call(x),borderRadius:BorderRadius.circular(15),child:Container(width:DisplaySettings.instance.largeTextMode?160:DisplaySettings.instance.textScale>=1.3?142:126,padding:const EdgeInsets.fromLTRB(10,9,10,10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Center(child:Container(width:58,height:58,decoration:BoxDecoration(color:const Color(0xFFFFF4F7),borderRadius:BorderRadius.circular(18)),child:Icon(x.icon,size:40,color:i==0?AppColors.green:x.id=='wti'?const Color(0xFF2995D6):const Color(0xFFE5A62B)))),const SizedBox(height:7),Text(x.name,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900),maxLines:1,overflow:TextOverflow.ellipsis),const Spacer(),FittedBox(fit:BoxFit.scaleDown,child:Text('${x.value} ${x.unit}',style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900),maxLines:1)),const SizedBox(height:3),FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:x.change==null?const Text('공식 데이터 연결 대기',style:TextStyle(fontSize:8.5,color:AppColors.secondary)):Text('${up?'▲':'▼'} ${x.change!.abs().toStringAsFixed(1)}% · ${x.frequency=='monthly'?'월':'일'}',style:TextStyle(fontSize:10,fontWeight:FontWeight.w800,color:up?AppColors.coral:AppColors.blue)))]))));})),
  ]));
}
