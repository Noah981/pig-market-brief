import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DisplaySettings extends ChangeNotifier {
  DisplaySettings._();
  static final DisplaySettings instance=DisplaySettings._();
  static const _key='display_text_scale';
  double _textScale=1;
  double get textScale=>_textScale;

  Future<void> load()async{
    final value=(await SharedPreferences.getInstance()).getDouble(_key)??1;
    _textScale=value.clamp(.85,1.3).toDouble();
    notifyListeners();
  }

  Future<void> setTextScale(double value)async{
    _textScale=value.clamp(.85,1.3).toDouble();
    notifyListeners();
    await (await SharedPreferences.getInstance()).setDouble(_key,_textScale);
  }
}
