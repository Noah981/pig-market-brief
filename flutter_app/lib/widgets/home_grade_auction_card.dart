import 'package:flutter/material.dart';
import '../data/pig_grade_repository.dart';
import '../services/api/kape_api_client.dart';
import '../theme/app_theme.dart';

class HomeGradeAuctionCard extends StatelessWidget {
  const HomeGradeAuctionCard({super.key,required this.snapshot,required this.onTap});
  final PigGradeSnapshot? snapshot;
  final VoidCallback onTap;

  @override Widget build(BuildContext context){
    final rows={for(final row in snapshot?.grades??const <KapeGradePrice>[])_normal(row.grade):row};
    final count=rows.values.fold<int>(0,(sum,row)=>sum+row.count);
    return Material(color:Colors.white,borderRadius:BorderRadius.circular(18),child:InkWell(
      key:const ValueKey('home_grade_auction'),onTap:onTap,borderRadius:BorderRadius.circular(18),
      child:Padding(padding:const EdgeInsets.fromLTRB(12,12,12,13),child:Column(children:[
        Row(children:[const Icon(Icons.workspace_premium_rounded,color:AppColors.coral,size:20),const SizedBox(width:6),const Expanded(child:Text('등급별 경락가격',style:TextStyle(fontSize:16,fontWeight:FontWeight.w900))),const Text('(원/kg)  ',style:TextStyle(fontSize:9,color:AppColors.secondary)),Text(_date(snapshot?.date),style:const TextStyle(fontSize:8,color:AppColors.secondary))]),
        const SizedBox(height:10),
        Row(children:['1+','1','2','등외'].map((grade)=>Expanded(child:_GradeCell(grade:grade,row:rows[grade],previous:snapshot?.previous(grade)))).toList()),
        const Divider(height:22,color:AppColors.divider),
        Row(children:[const Icon(Icons.business_center_rounded,color:AppColors.coral,size:17),const SizedBox(width:6),const Expanded(child:Text('오늘 경락 현황',style:TextStyle(fontSize:13,fontWeight:FontWeight.w900))),Text(_date(snapshot?.date),style:const TextStyle(fontSize:8,color:AppColors.secondary))]),
        const SizedBox(height:10),
        Row(children:[
          Expanded(child:_StatusCell(icon:Icons.savings_rounded,label:'경락두수',value:count>0?'${_number(count)}두':'정보 없음')),
          const Expanded(child:_StatusCell(icon:Icons.scale_rounded,label:'평균 도체중',value:'정보 없음')),
          const Expanded(child:_StatusCell(icon:Icons.male_rounded,label:'거세',value:'정보 없음')),
          const Expanded(child:_StatusCell(icon:Icons.female_rounded,label:'암퇘지',value:'정보 없음')),
        ]),
      ])),
    ));
  }
  static String _normal(String value){final v=value.trim().toUpperCase().replaceAll('등급','');if(v=='1PLUS'||v=='1++')return '1+';if(v.contains('등외'))return '등외';return v;}
  static String _date(String? value)=>value!=null&&RegExp(r'^\d{8}$').hasMatch(value)?'${value.substring(4,6)}.${value.substring(6,8)} 기준':'공식 데이터 확인 중';
  static String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
}

class _GradeCell extends StatelessWidget{
  const _GradeCell({required this.grade,required this.row,required this.previous});final String grade;final KapeGradePrice? row,previous;
  @override Widget build(BuildContext context){final change=row!=null&&previous!=null&&previous!.price>0?(row!.price-previous!.price)/previous!.price*100:null;final up=(change??0)>=0;return Container(margin:const EdgeInsets.symmetric(horizontal:3),padding:const EdgeInsets.symmetric(horizontal:4,vertical:8),decoration:BoxDecoration(color:const Color(0xFFFFFBFC),borderRadius:BorderRadius.circular(11),border:Border.all(color:AppColors.divider)),child:Column(children:[Text(grade,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w800)),const SizedBox(height:3),FittedBox(child:Text(row==null?'정보 없음':HomeGradeAuctionCard._number(row!.price),style:const TextStyle(fontSize:13,fontWeight:FontWeight.w900))),const SizedBox(height:2),Text(change==null?'공식값 대기':'${up?'▲':'▼'} ${change.abs().toStringAsFixed(1)}%',style:TextStyle(fontSize:7.5,fontWeight:FontWeight.w800,color:change==null?AppColors.secondary:up?AppColors.coral:AppColors.blue)),const SizedBox(height:5),ClipRRect(borderRadius:BorderRadius.circular(4),child:LinearProgressIndicator(minHeight:4,value:row==null?0:(row!.price/8000).clamp(0,1),backgroundColor:AppColors.divider,valueColor:AlwaysStoppedAnimation(up?AppColors.coral:AppColors.blue))) ]));}
}
class _StatusCell extends StatelessWidget{const _StatusCell({required this.icon,required this.label,required this.value});final IconData icon;final String label,value;@override Widget build(BuildContext context)=>Column(children:[Icon(icon,size:18,color:label=='경락두수'?AppColors.coral:AppColors.blue),const SizedBox(height:3),Text(label,maxLines:1,style:const TextStyle(fontSize:8,color:AppColors.secondary)),const SizedBox(height:2),FittedBox(child:Text(value,style:const TextStyle(fontSize:10,fontWeight:FontWeight.w900)))]);}
