import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class TodoSummaryCard extends StatelessWidget {
  const TodoSummaryCard({super.key,required this.items,required this.onToggle});
  final List<TodoItem> items;
  final ValueChanged<int> onToggle;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(13),decoration:appCard(color:const Color(0xFFFFF1F5),radius:21),child:Column(children:[
    Row(children:[Container(padding:const EdgeInsets.all(9),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(12)),child:const Icon(Icons.calendar_month,color:AppColors.coral,size:25)),const SizedBox(width:8),const Expanded(child:Text('오늘 할 일',style:TextStyle(fontSize:19,fontWeight:FontWeight.w900))),Container(width:34,height:34,alignment:Alignment.center,decoration:const BoxDecoration(color:AppColors.coral,shape:BoxShape.circle),child:Text('${items.where((e)=>!e.done).length}',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w900))),const Icon(Icons.chevron_right,color:AppColors.coral,size:20)]),
    const SizedBox(height:10),const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('전체 4',style:TextStyle(fontSize:10.5,color:AppColors.coral,fontWeight:FontWeight.w800)),Text('주간 1',style:TextStyle(fontSize:10.5,color:AppColors.secondary)),Text('3주 1',style:TextStyle(fontSize:10.5,color:AppColors.secondary)),Text('사료 1',style:TextStyle(fontSize:10.5,color:AppColors.secondary))]),const SizedBox(height:6),
    ...List.generate(items.length,(i){final x=items[i];return SizedBox(height:34,child:Row(children:[SizedBox(width:28,height:28,child:Checkbox(value:x.done,onChanged:(_)=>onToggle(i),activeColor:const Color(0xFF667184),side:const BorderSide(color:Color(0xFF788394),width:1.5))),Expanded(child:Text(x.title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:11.5,color:x.done?AppColors.secondary:AppColors.text,decoration:x.done?TextDecoration.lineThrough:null))),Container(padding:const EdgeInsets.symmetric(horizontal:7,vertical:4),decoration:BoxDecoration(color:x.color,borderRadius:BorderRadius.circular(9)),child:Text(x.type,style:const TextStyle(fontSize:9.5,fontWeight:FontWeight.w700))),const SizedBox(width:7),Text(x.due,style:const TextStyle(fontSize:9.5,color:AppColors.secondary))]));}),
  ]));
}
