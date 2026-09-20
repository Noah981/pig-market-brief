import 'package:flutter/services.dart';
import '../models/dashboard_models.dart';

abstract final class PriceWidgetBridge{
 static const _channel=MethodChannel('dondonhae/price_widget');
 static Future<void> update({required int price,required int previousPrice,required int change,required double changePct,required String date,required String updatedAt,required List<PricePoint> history})async{
  try{await _channel.invokeMethod('updatePrice',{'price':price,'previousPrice':previousPrice,'change':change,'changePct':changePct,'date':date,'updatedAt':updatedAt,'history':history.map((x)=>x.value.round()).toList()});}catch(_){}
 }
 static void listenForOpen({required void Function() price,required void Function() disease}){_channel.setMethodCallHandler((call)async{if(call.method=='openPrice')price();if(call.method=='openDisease')disease();});}
}
