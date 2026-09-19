import 'package:flutter/material.dart';
import '../models/disease_models.dart';
import '../theme/app_theme.dart';

class KoreaDiseaseMap extends StatelessWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;final ValueChanged<DiseaseAlert> onTap;final double? userLatitude,userLongitude;
  @override Widget build(BuildContext context)=>AspectRatio(aspectRatio:.9,child:LayoutBuilder(builder:(context,box)=>Stack(children:[
    Positioned.fill(child:CustomPaint(painter:_KoreaPainter())),
    ...items.where((x)=>x.hasMapPoint).map((x){final p=_position(x.latitude!,x.longitude!,box.biggest);return Positioned(left:p.dx-13,top:p.dy-13,child:Tooltip(message:'${x.region} ${x.disease}',child:InkWell(onTap:()=>onTap(x),customBorder:const CircleBorder(),child:Container(width:26,height:26,decoration:BoxDecoration(color:x.isOfficial?AppColors.coral:const Color(0xFFFFA726),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3),boxShadow:const [BoxShadow(color:Color(0x22000000),blurRadius:5)]),child:const Icon(Icons.priority_high,color:Colors.white,size:14)))));}),
    if(userLatitude!=null&&userLongitude!=null)Builder(builder:(_){final p=_position(userLatitude!,userLongitude!,box.biggest);return Positioned(left:p.dx-12,top:p.dy-12,child:Container(width:24,height:24,decoration:BoxDecoration(color:AppColors.blue,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3)),child:const Icon(Icons.person_pin_circle,color:Colors.white,size:14)));}),
    const Positioned(right:8,bottom:5,child:Text('● 공식 확인  ● 공개정보 확인 중  ● 내 위치',style:TextStyle(fontSize:7.5,color:AppColors.secondary))),
  ])));
  Offset _position(double lat,double lng,Size size){final x=((lng-125.4)/(129.8-125.4)).clamp(0.0,1.0);final y=((38.7-lat)/(38.7-33.1)).clamp(0.0,1.0);return Offset(size.width*(.18+x*.67),size.height*(.05+y*.88));}
}

class _KoreaPainter extends CustomPainter{
  @override void paint(Canvas canvas,Size size){
    final fill=Paint()..color=const Color(0xFFE9EBEF);final line=Paint()..color=Colors.white..style=PaintingStyle.stroke..strokeWidth=1.4;
    final p=Path()..moveTo(size.width*.47,size.height*.03)..cubicTo(size.width*.35,size.height*.10,size.width*.38,size.height*.22,size.width*.30,size.height*.31)..cubicTo(size.width*.20,size.height*.42,size.width*.31,size.height*.51,size.width*.25,size.height*.61)..cubicTo(size.width*.18,size.height*.75,size.width*.35,size.height*.86,size.width*.45,size.height*.94)..cubicTo(size.width*.58,size.height*.89,size.width*.60,size.height*.78,size.width*.72,size.height*.69)..cubicTo(size.width*.82,size.height*.58,size.width*.72,size.height*.46,size.width*.77,size.height*.35)..cubicTo(size.width*.80,size.height*.22,size.width*.63,size.height*.17,size.width*.62,size.height*.08)..close();canvas.drawPath(p,fill);canvas.drawPath(p,line);
    for(final y in [.22,.36,.50,.64,.78])canvas.drawLine(Offset(size.width*.30,size.height*y),Offset(size.width*.72,size.height*(y+.03)),line);
    canvas.drawOval(Rect.fromCenter(center:Offset(size.width*.36,size.height*.97),width:size.width*.18,height:size.height*.045),fill);
  }
  @override bool shouldRepaint(covariant CustomPainter oldDelegate)=>false;
}
