import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/disease_models.dart';
import '../theme/app_theme.dart';

class DiseaseSummaryCard extends StatelessWidget {
  const DiseaseSummaryCard({super.key,required this.type,required this.count,required this.selected,required this.verified,required this.onTap});
  final DiseaseType type;
  final int count;
  final bool selected,verified;
  final VoidCallback onTap;
  @override Widget build(BuildContext context){
    final color=switch(type){DiseaseType.asf||DiseaseType.fmd=>AppColors.coral,DiseaseType.ped=>const Color(0xFF9964CB),DiseaseType.prrs=>const Color(0xFF56BEB9)};
    return InkWell(key:ValueKey('disease_card_${type.name}'),onTap:onTap,borderRadius:BorderRadius.circular(11),child:Container(
      padding:const EdgeInsets.fromLTRB(8,9,6,8),decoration:BoxDecoration(color:selected?const Color(0xFFFFF0F4):Colors.white,borderRadius:BorderRadius.circular(11),border:Border.all(color:selected?AppColors.coral:Colors.transparent,width:1),boxShadow:[BoxShadow(color:Colors.black.withValues(alpha:.025),blurRadius:12,offset:const Offset(0,3))]),
      child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Row(children:[SizedBox(width:21,height:21,child:CustomPaint(painter:_DiseaseSymbol(type,color))),const SizedBox(width:5),Expanded(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(type.label,style:const TextStyle(fontSize:12,fontWeight:FontWeight.w900))))]),
        const SizedBox(height:2),Text('${type.legalGroup} 법정질병',maxLines:1,style:const TextStyle(fontSize:7,color:AppColors.secondary)),
        const SizedBox(height:5),Text(verified||count>0?'$count건':'—',style:TextStyle(fontSize:16,height:1.1,fontWeight:FontWeight.w900,color:count>0?AppColors.coral:AppColors.text)),
        const SizedBox(height:3),Row(children:[Expanded(child:FittedBox(fit:BoxFit.scaleDown,alignment:Alignment.centerLeft,child:Text(count>0?'최근 1년':verified?'조회 자료 없음':'조회 확인 중',style:const TextStyle(fontSize:7.5,color:AppColors.secondary,fontWeight:FontWeight.w600)))),const Icon(Icons.chevron_right,size:13,color:AppColors.secondary)]),
      ])));
  }
}
class _DiseaseSymbol extends CustomPainter{
  const _DiseaseSymbol(this.type,this.color);final DiseaseType type;final Color color;
  @override void paint(Canvas c,Size s){c.save();c.scale(s.width/24,s.height/24);final p=Paint()..color=color;
    switch(type){
      case DiseaseType.asf:
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(3,6,17,11),const Radius.circular(4)),p);
        for(final x in [5.0,15.0]){c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(x,14,3,6),const Radius.circular(1)),p);}
        c.drawRRect(RRect.fromRectAndRadius(const Rect.fromLTWH(18,8,5,6),const Radius.circular(1)),p);
        c.drawPath(Path()..moveTo(17,7)..lineTo(18,2)..lineTo(22,7)..close(),p);
        c.drawArc(const Rect.fromLTWH(0,7,6,7),0,math.pi*1.5,false,Paint()..color=color..style=PaintingStyle.stroke..strokeWidth=1.5);
      case DiseaseType.fmd:
        c.drawPath(Path()..moveTo(10,3)..cubicTo(5,4,1,13,2,19)..cubicTo(3,24,10,21,10,17)..close(),p);
        c.drawPath(Path()..moveTo(14,3)..cubicTo(19,4,23,13,22,19)..cubicTo(21,24,14,21,14,17)..close(),p);
        c.drawLine(const Offset(12,0),const Offset(12,11),Paint()..color=color..strokeWidth=2);
      case DiseaseType.ped:case DiseaseType.prrs:
        c.drawCircle(const Offset(12,12),7,p);
        for(var i=0;i<8;i++){final a=i*math.pi/4;final tip=Offset(12+10*math.cos(a),12+10*math.sin(a));c.drawLine(const Offset(12,12),tip,Paint()..color=color..strokeWidth=2);c.drawCircle(tip,1.6,p);}
        for(final point in [const Offset(9,9),const Offset(15,10),const Offset(11,15)]){c.drawCircle(point,1.5,Paint()..color=Colors.white.withValues(alpha:.85));}
    }
    c.restore();
  }
  @override bool shouldRepaint(covariant _DiseaseSymbol old)=>old.type!=type||old.color!=color;
}
