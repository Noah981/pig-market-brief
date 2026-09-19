import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class TodoSummaryCard extends StatelessWidget {
  const TodoSummaryCard({super.key,required this.items,required this.onToggle});
  final List<TodoItem> items;
  final ValueChanged<int> onToggle;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(10),decoration:appCard(color:const Color(0xFFFFF1F5),radius:18),child:Column(children:[
    Row(children:[Container(padding:const EdgeInsets.all(7),decoration:BoxDecoration(color:Colors.white,borderRadius:BorderRadius.circular(10)),child:const Icon(Icons.calendar_month,color:AppColors.coral,size:19)),const SizedBox(width:6),const Expanded(child:Text('오늘\n할 일',style:TextStyle(fontSize:15,height:1.05,fontWeight:FontWeight.w900))),Container(width:29,height:29,alignment:Alignment.center,decoration:const BoxDecoration(color:AppColors.coral,shape:BoxShape.circle),child:Text('${items.where((e)=>!e.done).length}',style:const TextStyle(fontSize:11,color:Colors.white,fontWeight:FontWeight.w900))),const Icon(Icons.chevron_right,color:AppColors.coral,size:17)]),
    const SizedBox(height:8),const Row(mainAxisAlignment:MainAxisAlignment.spaceBetween,children:[Text('전체 4',style:TextStyle(fontSize:8.5,color:AppColors.coral,fontWeight:FontWeight.w800)),Text('주간 1',style:TextStyle(fontSize:8.5,color:AppColors.secondary)),Text('3주 1',style:TextStyle(fontSize:8.5,color:AppColors.secondary)),Text('사료 1',style:TextStyle(fontSize:8.5,color:AppColors.secondary))]),const SizedBox(height:4),
    ...List.generate(items.length,(i){final x=items[i];return Expanded(child:Row(children:[SizedBox(width:24,height:24,child:Transform.scale(scale:.78,child:Checkbox(value:x.done,onChanged:(_)=>onToggle(i),activeColor:const Color(0xFF667184),side:const BorderSide(color:Color(0xFF788394),width:1.5)))),Expanded(child:Text(x.title,maxLines:1,overflow:TextOverflow.ellipsis,style:TextStyle(fontSize:8.5,color:x.done?AppColors.secondary:AppColors.text,decoration:x.done?TextDecoration.lineThrough:null))),Container(padding:const EdgeInsets.symmetric(horizontal:5,vertical:3),decoration:BoxDecoration(color:x.color,borderRadius:BorderRadius.circular(8)),child:Text(x.type,style:const TextStyle(fontSize:7,fontWeight:FontWeight.w700)))]));}),
  ]));
}
