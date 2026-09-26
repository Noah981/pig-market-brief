import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../settings/display_settings.dart';

class AppHeader extends StatefulWidget {
  const AppHeader({super.key});

  @override
  State<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends State<AppHeader> {
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    _now = DateTime.now();
    _clock = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  String _currentDateTime() {
    final now = _now;
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    String twoDigits(int value) => value.toString().padLeft(2, '0');
    return '${now.year}년 ${now.month}월 ${now.day}일 '
        '(${weekdays[now.weekday - 1]}) '
        '${twoDigits(now.hour)}:${twoDigits(now.minute)}';
  }
  @override
  Widget build(BuildContext context) {final settings=DisplaySettings.instance;return SizedBox(
        height: settings.largeTextMode?108:settings.textScale>1?96:84,
        child: Row(children: [
          ClipRRect(borderRadius:BorderRadius.circular(12),child:Image.asset('assets/images/dondonhae_symbol.png',width:44,height:44,fit:BoxFit.cover)),
          const SizedBox(width: 9),
          Expanded(child:Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            RichText(text: const TextSpan(style: TextStyle(fontFamily:'NotoSansKR',fontSize: 22, fontWeight: FontWeight.w900,letterSpacing:-1), children: [TextSpan(text: '돈돈', style: TextStyle(color: AppColors.text)), TextSpan(text: '해', style: TextStyle(color: AppColors.coral))])),
            const Text('양돈의 오늘을 든든하게', style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w600)),
            const SizedBox(height:3),
            SizedBox(height:settings.largeTextMode?34:30,child:OutlinedButton.icon(key:const ValueKey('large_text_mode_button'),onPressed:()=>settings.setLargeTextMode(!settings.largeTextMode),icon:Icon(settings.largeTextMode?Icons.text_decrease:Icons.text_increase,size:13),label:FittedBox(child:Text(settings.largeTextMode?'기본 글씨':'큰글씨 모드')),style:OutlinedButton.styleFrom(padding:const EdgeInsets.symmetric(horizontal:7),minimumSize:Size(0,settings.largeTextMode?34:30),tapTargetSize:MaterialTapTargetSize.shrinkWrap,textStyle:const TextStyle(fontSize:9,fontWeight:FontWeight.w900),foregroundColor:AppColors.coral,side:const BorderSide(color:AppColors.coral)))),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            if(!settings.largeTextMode)Text(_currentDateTime(), style: const TextStyle(fontSize: 8, color: Color(0xFF3E4350))),
            if(!settings.largeTextMode)const SizedBox(height: 2),
            const Badge(smallSize: 6, child: Icon(Icons.notifications, size: 20, color: Color(0xFF24344D))),
          ]),
        ]),
      );}
}
