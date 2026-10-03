import 'package:flutter/services.dart';

/// Keeps Android launcher widgets in sync with the same repository caches used
/// by the Flutter screens. Unsupported platforms safely ignore the channel.
class WidgetUpdateService {
  WidgetUpdateService._();
  static const _channel=MethodChannel('dondonhae/widgets');
  static void Function(String)? onRoute;
  static bool _initialized=false;
  static void _initialize(){
    if(_initialized)return;
    _initialized=true;
    _channel.setMethodCallHandler((call)async{
      if(call.method=='openRoute'&&call.arguments is String){onRoute?.call(call.arguments as String);}
    });
  }

  static Future<void> updateAll()async{
    try{await _channel.invokeMethod<void>('updateWidgets');}catch(_){}
  }

  static Future<String?> initialRoute()async{
    _initialize();
    try{return await _channel.invokeMethod<String>('getInitialRoute');}catch(_){return null;}
  }
}
