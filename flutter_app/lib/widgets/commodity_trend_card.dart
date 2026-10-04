import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';
import 'commodity_quote_card.dart';
class CommodityTrendCard extends StatelessWidget {
  const CommodityTrendCard({super.key,required this.items,this.onTap,this.onHeaderTap});
  final List<Commodity> items;final ValueChanged<Commodity>? onTap;final VoidCallback? onHeaderTap;
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(14),decoration:appCard(color:const Color(0xFFFAF7F6),radius:22),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    InkWell(key:const ValueKey('international_market_header'),onTap:onHeaderTap,child:const Row(children:[Expanded(child:Text('원료 · 유가 · 환율',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),Icon(Icons.arrow_forward_rounded,size:20,color:AppColors.coral)])),
    const SizedBox(height:4),const Text('공식 기준일과 발표 주기를 함께 확인하세요',style:TextStyle(fontSize:11,color:AppColors.secondary)),const SizedBox(height:12),
    SizedBox(height:224 * MediaQuery.textScalerOf(context).scale(1).clamp(1,1.6),child:ListView.separated(scrollDirection:Axis.horizontal,itemCount:items.length,separatorBuilder:(_,__)=>const SizedBox(width:10),itemBuilder:(context,i)=>SizedBox(width:170,child:CommodityQuoteCard(key:ValueKey('commodity_${items[i].id}'),item:items[i],onTap:()=>onTap?.call(items[i]))))),
  ]));
}
