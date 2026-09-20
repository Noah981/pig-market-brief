import 'package:flutter/material.dart';
import '../models/disease_models.dart';

class KoreaDiseaseMap extends StatelessWidget {
  const KoreaDiseaseMap({super.key,required this.items,required this.onTap,this.userLatitude,this.userLongitude});
  final List<DiseaseAlert> items;final ValueChanged<DiseaseAlert> onTap;final double? userLatitude,userLongitude;
  @override Widget build(BuildContext context)=>AspectRatio(aspectRatio:420/535,child:ClipRRect(borderRadius:BorderRadius.circular(12),child:Material(color:Colors.white,child:InkWell(onTap:items.isEmpty?null:()=>onTap(items.first),child:Image.asset('assets/images/korea_disease_reference.png',fit:BoxFit.contain,filterQuality:FilterQuality.high)))));
}
