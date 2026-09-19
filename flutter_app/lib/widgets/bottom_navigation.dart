import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({super.key,required this.index,required this.onSelected});
  final int index;final ValueChanged<int> onSelected;
  @override Widget build(BuildContext context)=>DecoratedBox(decoration:const BoxDecoration(color:Colors.white,border:Border(top:BorderSide(color:AppColors.divider))),child:SafeArea(top:false,child:SizedBox(height:64,child:Row(children:[_item(0,Icons.home_rounded,'홈'),_item(1,Icons.bar_chart_rounded,'시황'),_item(2,Icons.health_and_safety_rounded,'질병'),_item(3,Icons.fact_check_rounded,'농장점검'),_item(4,Icons.grid_view_rounded,'더보기')]))));
  Widget _item(int i,IconData icon,String label){final active=index==i;return Expanded(child:Semantics(button:true,label:label,selected:active,child:InkWell(key:ValueKey('nav_$i'),onTap:()=>onSelected(i),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:active?AppColors.coral:const Color(0xFF626B7C),size:21),const SizedBox(height:3),Text(label,maxLines:1,style:TextStyle(fontSize:9,color:active?AppColors.coral:const Color(0xFF626B7C),fontWeight:active?FontWeight.w800:FontWeight.w600))]))));}
}
