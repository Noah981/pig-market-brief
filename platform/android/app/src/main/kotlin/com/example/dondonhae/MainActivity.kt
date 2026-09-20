package com.example.dondonhae

import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity(){
 private var channel:MethodChannel?=null
 override fun getInitialRoute():String?=when{intent?.getBooleanExtra("open_price",false)==true->"/price";intent?.getBooleanExtra("open_disease",false)==true->"/disease";else->super.getInitialRoute()}
 override fun configureFlutterEngine(flutterEngine:FlutterEngine){
  super.configureFlutterEngine(flutterEngine)
  channel=MethodChannel(flutterEngine.dartExecutor.binaryMessenger,"dondonhae/price_widget")
  channel?.setMethodCallHandler{call,result->
   if(call.method=="updatePrice"){
    val args=call.arguments as? Map<*,*>
    PriceWidgetStore.saveAndRender(this,args)
    result.success(null)
   }else result.notImplemented()
  }
 }
 override fun onNewIntent(intent:Intent){super.onNewIntent(intent);setIntent(intent);if(intent.getBooleanExtra("open_price",false))channel?.invokeMethod("openPrice",null);if(intent.getBooleanExtra("open_disease",false))channel?.invokeMethod("openDisease",null)}
}
