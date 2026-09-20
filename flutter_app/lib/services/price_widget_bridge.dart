import 'package:flutter/services.dart';

abstract final class PriceWidgetBridge{
 static const _channel=MethodChannel('dondonhae/price_widget');
 static Future<void> update({required int price,required int previousPrice,required int change,required double changePct,required String date,required String updatedAt})async{
  try{await _channel.invokeMethod('updatePrice',{'price':price,'previousPrice':previousPrice,'change':change,'changePct':changePct,'date':date,'updatedAt':updatedAt});}catch(_){}
 }
 static void listenForPriceOpen(void Function() open){_channel.setMethodCallHandler((call)async{if(call.method=='openPrice')open();});}
}
