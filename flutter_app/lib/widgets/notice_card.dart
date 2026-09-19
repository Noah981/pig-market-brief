import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class NoticeCard extends StatelessWidget {
  const NoticeCard({super.key,required this.items});
  final List<NoticeItem> items;
  void _open(BuildContext context,NoticeItem x)=>showModalBottomSheet(context:context,showDragHandle:true,builder:(_)=>Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.start,children:[Text(x.category,style:const TextStyle(color:AppColors.coral,fontWeight:FontWeight.w800)),const SizedBox(height:12),Text(x.title,style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:12),Text(x.date,style:const TextStyle(color:AppColors.secondary)),const SizedBox(height:24)])));
  @override Widget build(BuildContext context)=>Container(padding:const EdgeInsets.fromLTRB(13,12,13,11),decoration:appCard(radius:20),child:Column(children:[const Row(children:[Icon(Icons.campaign,color:AppColors.coral,size:22),SizedBox(width:7),Expanded(child:Text('양돈 이슈 & 공지',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),Text('더보기 ›',style:TextStyle(fontSize:11,color:AppColors.secondary))]),const SizedBox(height:7),...items.map((x)=>InkWell(onTap:()=>_open(context,x),child:Padding(padding:const EdgeInsets.symmetric(vertical:4),child:Row(children:[Container(width:42,alignment:Alignment.center,padding:const EdgeInsets.symmetric(vertical:3),decoration:BoxDecoration(color:x.color,borderRadius:BorderRadius.circular(8)),child:Text(x.category,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))),const SizedBox(width:8),Expanded(child:Text(x.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:10.5))),const SizedBox(width:7),Text(x.date,style:const TextStyle(fontSize:9,color:AppColors.secondary))])))]));
}
