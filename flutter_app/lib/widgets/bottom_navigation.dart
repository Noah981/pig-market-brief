import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class BottomNavigation extends StatelessWidget {
  const BottomNavigation({super.key,required this.index,required this.onSelected,required this.onAdd});
  final int index;final ValueChanged<int> onSelected;final VoidCallback onAdd;
  @override Widget build(BuildContext context)=>BottomAppBar(height:84,padding:const EdgeInsets.symmetric(horizontal:8),color:Colors.white,surfaceTintColor:Colors.white,child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[_item(0,Icons.home,'홈'),_item(1,Icons.bar_chart,'시황'),Expanded(child:InkWell(onTap:onAdd,child:Column(mainAxisAlignment:MainAxisAlignment.end,children:[Transform.translate(offset:const Offset(0,-8),child:Container(width:58,height:58,decoration:const BoxDecoration(shape:BoxShape.circle,gradient:LinearGradient(colors:[Color(0xFFFF7B9D),AppColors.coral]),boxShadow:[BoxShadow(color:Color(0x44F72F62),blurRadius:10,offset:Offset(0,4))]),child:const Icon(Icons.add,color:Colors.white,size:31))),const Text('할 일 추가',style:TextStyle(fontSize:10,color:AppColors.secondary))]))),_item(3,Icons.fact_check,'농장점검'),_item(4,Icons.grid_view,'더보기')]));
  Widget _item(int i,IconData icon,String label){final active=index==i;return Expanded(child:InkWell(onTap:()=>onSelected(i),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[Icon(icon,color:active?AppColors.coral:const Color(0xFF626B7C),size:25),const SizedBox(height:5),Text(label,style:TextStyle(fontSize:10,color:active?AppColors.coral:const Color(0xFF626B7C),fontWeight:active?FontWeight.w800:FontWeight.w500))])));}
}
