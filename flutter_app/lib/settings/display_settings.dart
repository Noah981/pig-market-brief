import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance=DisplaySettings._();
  static const _key='display_text_scale';
  static const _largeKey='display_large_text_mode';
  static const _designMigrationKey='display_large_default_v3';
  double _textScale=1.3;
  bool _largeTextMode=false;
  double get textScale=>_largeTextMode?1.55:_textScale;
  double get selectedTextScale=>_textScale;
  bool get largeTextMode=>_largeTextMode;

  Future<void> load()async{
    final prefs=await SharedPreferences.getInstance();
    if(!(prefs.getBool(_designMigrationKey)??false)){
      await prefs.setDouble(_key,1.3);
      await prefs.setBool(_largeKey,false);
      await prefs.setBool(_designMigrationKey,true);
    }
    final value=prefs.getDouble(_key)??1.3;
    _textScale=value.clamp(.85,1.3).toDouble();
    _largeTextMode=prefs.getBool(_largeKey)??false;
    notifyListeners();
  }

  Future<void> setTextScale(double value)async{
    _textScale=value.clamp(.85,1.3).toDouble();
    notifyListeners();
    await (await SharedPreferences.getInstance()).setDouble(_key,_textScale);
  }

  Future<void> setLargeTextMode(bool value)async{
    _largeTextMode=value;
    notifyListeners();
    await (await SharedPreferences.getInstance()).setBool(_largeKey,value);
  }
}
