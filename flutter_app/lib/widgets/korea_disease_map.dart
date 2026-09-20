import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/disease_models.dart';

/// 해상도에 관계없이 선명한 대한민국 벡터 지도와 실제 발생 좌표를 겹쳐 그린다.
class KoreaDiseaseMap extends StatelessWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;
  final ValueChanged<DiseaseAlert> onTap;
  final double? userLatitude,userLongitude;
  List<DiseaseAlert> get points=>items.where((x)=>x.isOfficial&&x.hasMapPoint).toList(growable:false);

  @override Widget build(BuildContext context)=>AspectRatio(aspectRatio:420/535,child:ClipRRect(borderRadius:BorderRadius.circular(18),child:Material(color:Colors.white,child:LayoutBuilder(builder:(context,size)=>GestureDetector(behavior:HitTestBehavior.opaque,onTapUp:(event)=>_handleTap(event.localPosition,Size(size.maxWidth,size.maxHeight)),child:CustomPaint(key:const ValueKey('korea_disease_vector_map'),painter:_KoreaMapPainter(items:points,userLatitude:userLatitude,userLongitude:userLongitude),child:const SizedBox.expand()))))));

  void _handleTap(Offset tap,Size size){DiseaseAlert? selected;double nearest=double.infinity;for(final item in points){final p=_MapProjection.position(item.latitude!,item.longitude!,size);final distance=(p-tap).distance;if(distance<nearest){nearest=distance;selected=item;}}if(selected!=null&&nearest<=math.max(24,size.width*.065))onTap(selected);}
}

abstract final class _MapProjection {
  static const minLat=33.0,maxLat=38.75,minLng=125.55,maxLng=129.75;
  static Offset position(double lat,double lng,Size size){final x=((lng-minLng)/(maxLng-minLng)).clamp(0.0,1.0);final y=((maxLat-lat)/(maxLat-minLat)).clamp(0.0,1.0);return Offset(size.width*(.12+x*.76),size.height*(.055+y*.83));}
}

class _KoreaMapPainter extends CustomPainter {
  const _KoreaMapPainter({required this.items,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;final double? userLatitude,userLongitude;
  @override void paint(Canvas canvas,Size size){
    final map=Path()..moveTo(size.width*.39,size.height*.035)..cubicTo(size.width*.55,size.height*.025,size.width*.65,size.height*.08,size.width*.67,size.height*.17)..cubicTo(size.width*.71,size.height*.23,size.width*.78,size.height*.30,size.width*.76,size.height*.39)..cubicTo(size.width*.83,size.height*.47,size.width*.78,size.height*.56,size.width*.82,size.height*.66)..cubicTo(size.width*.80,size.height*.76,size.width*.69,size.height*.81,size.width*.64,size.height*.89)..cubicTo(size.width*.54,size.height*.94,size.width*.47,size.height*.88,size.width*.38,size.height*.91)..cubicTo(size.width*.29,size.height*.87,size.width*.30,size.height*.78,size.width*.22,size.height*.72)..cubicTo(size.width*.17,size.height*.64,size.width*.20,size.height*.55,size.width*.13,size.height*.48)..cubicTo(size.width*.16,size.height*.39,size.width*.22,size.height*.34,size.width*.22,size.height*.25)..cubicTo(size.width*.25,size.height*.18,size.width*.34,size.height*.13,size.width*.39,size.height*.035)..close();
    canvas.drawShadow(map,const Color(0x22000000),8,true);canvas.drawPath(map,Paint()..color=const Color(0xFFE9EAED)..style=PaintingStyle.fill..isAntiAlias=true);canvas.drawPath(map,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.8..isAntiAlias=true);_regions(canvas,size,map);_labels(canvas,size);
    for(final item in items){_dot(canvas,_MapProjection.position(item.latitude!,item.longitude!,size),const Color(0xFFF72F62),size.width*.013);}
    if(userLatitude!=null&&userLongitude!=null)_dot(canvas,_MapProjection.position(userLatitude!,userLongitude!,size),const Color(0xFF1685E8),size.width*.017);_legend(canvas,size);
  }
  void _regions(Canvas canvas,Size size,Path clip){canvas.save();canvas.clipPath(clip);final p=Paint()..color=Colors.white..strokeWidth=1.25..style=PaintingStyle.stroke..isAntiAlias=true;final lines=[[const Offset(.25,.22),const Offset(.69,.20)],[const Offset(.20,.34),const Offset(.73,.32)],[const Offset(.16,.47),const Offset(.78,.43)],[const Offset(.18,.60),const Offset(.79,.57)],[const Offset(.23,.72),const Offset(.72,.69)],[const Offset(.31,.82),const Offset(.66,.80)],[const Offset(.38,.08),const Offset(.38,.88)],[const Offset(.55,.06),const Offset(.57,.88)]];for(final l in lines){final path=Path()..moveTo(l[0].dx*size.width,l[0].dy*size.height)..cubicTo((l[0].dx+.08)*size.width,(l[0].dy+.04)*size.height,(l[1].dx-.08)*size.width,(l[1].dy-.04)*size.height,l[1].dx*size.width,l[1].dy*size.height);canvas.drawPath(path,p);}canvas.restore();}
  void _labels(Canvas canvas,Size size){const labels=<String,Offset>{'서울':Offset(.35,.23),'경기':Offset(.34,.34),'강원':Offset(.61,.24),'충북':Offset(.48,.42),'충남':Offset(.30,.47),'경북':Offset(.65,.51),'전북':Offset(.34,.61),'경남':Offset(.58,.70),'전남':Offset(.30,.76),'제주':Offset(.27,.92)};for(final e in labels.entries){_text(canvas,e.key,Offset(e.value.dx*size.width,e.value.dy*size.height),size.width*.037,const Color(0xFF363A43),FontWeight.w800);}}
  void _dot(Canvas canvas,Offset p,Color color,double radius){canvas.drawCircle(p,radius*2.05,Paint()..color=color.withValues(alpha:.16));canvas.drawCircle(p,radius,Paint()..color=color..isAntiAlias=true);canvas.drawCircle(p,radius,Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.5..isAntiAlias=true);}
  void _legend(Canvas canvas,Size size){final y=size.height*.955;_dot(canvas,Offset(size.width*.53,y),const Color(0xFFF72F62),size.width*.012);_text(canvas,'발생 지역',Offset(size.width*.63,y),size.width*.032,const Color(0xFF555A65),FontWeight.w700);_dot(canvas,Offset(size.width*.78,y),const Color(0xFF1685E8),size.width*.012);_text(canvas,'내 위치',Offset(size.width*.87,y),size.width*.032,const Color(0xFF777B85),FontWeight.w700);}
  void _text(Canvas canvas,String value,Offset center,double fontSize,Color color,FontWeight weight){final tp=TextPainter(text:TextSpan(text:value,style:TextStyle(fontSize:fontSize,color:color,fontWeight:weight)),textDirection:TextDirection.ltr)..layout();tp.paint(canvas,Offset(center.dx-tp.width/2,center.dy-tp.height/2));}
  @override bool shouldRepaint(covariant _KoreaMapPainter old)=>old.items!=items||old.userLatitude!=userLatitude||old.userLongitude!=userLongitude;
}
