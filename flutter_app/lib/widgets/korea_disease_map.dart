import 'package:flutter/material.dart';
import '../models/disease_models.dart';
import '../theme/app_theme.dart';

class KoreaDiseaseMap extends StatelessWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;final ValueChanged<DiseaseAlert> onTap;final double? userLatitude,userLongitude;
  @override Widget build(BuildContext context)=>AspectRatio(aspectRatio:1235/1536,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:LayoutBuilder(builder:(context,box)=>Stack(children:[
    Positioned.fill(child:Image.asset('assets/images/korea_admin_map.jpeg',fit:BoxFit.cover,filterQuality:FilterQuality.medium)),
    ...items.where((x)=>x.hasMapPoint).map((x){final p=_position(x.latitude!,x.longitude!,box.biggest);return Positioned(left:p.dx-13,top:p.dy-13,child:Tooltip(message:'${x.region} ${x.disease}',child:InkWell(onTap:()=>onTap(x),customBorder:const CircleBorder(),child:Container(width:26,height:26,decoration:BoxDecoration(color:x.isOfficial?AppColors.coral:const Color(0xFFFFA726),shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3),boxShadow:const [BoxShadow(color:Color(0x22000000),blurRadius:5)]),child:const Icon(Icons.priority_high,color:Colors.white,size:14)))));}),
    if(userLatitude!=null&&userLongitude!=null)Builder(builder:(_){final p=_position(userLatitude!,userLongitude!,box.biggest);return Positioned(left:p.dx-12,top:p.dy-12,child:Container(width:24,height:24,decoration:BoxDecoration(color:AppColors.blue,shape:BoxShape.circle,border:Border.all(color:Colors.white,width:3)),child:const Icon(Icons.person_pin_circle,color:Colors.white,size:14)));}),
    const Positioned(right:8,bottom:5,child:Text('● 공식 확인  ● 공개정보 확인 중  ● 내 위치',style:TextStyle(fontSize:7.5,color:AppColors.secondary))),
  ]))));
  Offset _position(double lat,double lng,Size size){final x=((lng-125.4)/(129.8-125.4)).clamp(0.0,1.0);final y=((38.7-lat)/(38.7-33.1)).clamp(0.0,1.0);return Offset(size.width*(.15+x*.70),size.height*(.03+y*.91));}
}
