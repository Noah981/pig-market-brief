import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_header.dart';

class FarmHeroSection extends StatelessWidget {
  const FarmHeroSection({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 126,
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            child: Image.asset('assets/images/pig_hero.png', fit: BoxFit.cover, alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => Container(color: AppColors.lightCoral)),
          ),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: .96), Colors.white.withValues(alpha: .34), Colors.transparent]))),
          const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.topCenter, child: AppHeader())),
          const Positioned(right: 13, bottom: 9, child: Text('건강한 돼지,\n더 큰 내일', textAlign: TextAlign.right, style: TextStyle(fontSize: 11, height: 1.2, fontWeight: FontWeight.w900))),
        ]),
      );
}
