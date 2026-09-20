import 'package:flutter/material.dart';
import '../settings/farm_location_settings.dart';
import '../theme/app_theme.dart';

Future<void> showFarmLocationPicker(BuildContext context)async{
  final settings=FarmLocationSettings.instance;
  var province=settings.location.province;
  await showModalBottomSheet(context:context,isScrollControlled:true,showDragHandle:true,builder:(sheetContext)=>StatefulBuilder(builder:(context,setSheet)=>SafeArea(child:SizedBox(height:MediaQuery.sizeOf(context).height*.72,child:Column(children:[
    const ListTile(title:Text('농장 소재지 설정',style:TextStyle(fontWeight:FontWeight.w900)),subtitle:Text('날씨·주변 질병·지원사업에 같은 지역을 사용합니다.')),
    SizedBox(height:48,child:ListView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.symmetric(horizontal:12),children:FarmLocationSettings.locations.keys.map((x)=>Padding(padding:const EdgeInsets.only(right:6),child:ChoiceChip(label:Text(x),selected:x==province,selectedColor:AppColors.lightCoral,onSelected:(_)=>setSheet(()=>province=x)))).toList())),
    const Divider(),Expanded(child:ListView(children:FarmLocationSettings.locations[province]!.map((x)=>ListTile(title:Text(x.cityCounty),subtitle:Text(x.province),trailing:x.province==settings.location.province&&x.cityCounty==settings.location.cityCounty?const Icon(Icons.check,color:AppColors.coral):null,onTap:()async{await settings.setLocation(x);if(sheetContext.mounted)Navigator.pop(sheetContext);})).toList()))
  ])))));
}
