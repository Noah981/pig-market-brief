import 'package:flutter/services.dart';

/// Keeps Android launcher widgets in sync with the same repository caches used
/// by the Flutter screens. Unsupported platforms safely ignore the channel.
class WidgetUpdateService {
  WidgetUpdateService._();
  static const _channel=MethodChannel('dondonhae/widgets');

  static Future<void> updateAll()async{
    try{await _channel.invokeMethod<void>('updateWidgets');}catch(_){}
  }

  static Future<String?> initialRoute()async{
    try{return await _channel.invokeMethod<String>('getInitialRoute');}catch(_){return null;}
  }
}
