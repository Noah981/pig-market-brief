import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance=DisplaySettings._();
  static const _key='display_text_scale_v2';
  static const _largeKey='display_large_text_mode_v2';
  double _textScale=1.15;
  bool _largeTextMode=false;
  // 40~60대 사용자가 처음 실행해도 바로 읽기 쉬운 크기를 기본값으로
  // 사용한다. 큰글씨 모드는 레이아웃을 밀어내지 않는 범위까지만 확대한다.
  double get textScale=>_largeTextMode?1.45:_textScale;
  double get selectedTextScale=>_textScale;
  bool get largeTextMode=>_largeTextMode;

  Future<void> load()async{
    final prefs=await SharedPreferences.getInstance();
    final value=prefs.getDouble(_key)??1.15;
    _textScale=value.clamp(1.15,1.45).toDouble();
    _largeTextMode=prefs.getBool(_largeKey)??false;
    notifyListeners();
  }

  Future<void> setTextScale(double value)async{
    _textScale=value.clamp(1.15,1.45).toDouble();
    notifyListeners();
    await (await SharedPreferences.getInstance()).setDouble(_key,_textScale);
  }

  Future<void> setLargeTextMode(bool value)async{
    _largeTextMode=value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_largeKey,value);
  }
}
