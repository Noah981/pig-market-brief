import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'app_header.dart';

class FarmHeroSection extends StatelessWidget {
  const FarmHeroSection({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 140 * (MediaQuery.textScalerOf(context).scale(1) / 1.15).clamp(1, 1.6),
        child: Stack(fit: StackFit.expand, children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(20), bottomRight: Radius.circular(20)),
            child: Image.asset('assets/images/pig_hero.jpg', fit: BoxFit.cover, alignment: Alignment.centerRight,
              errorBuilder: (_, __, ___) => Container(color: AppColors.lightCoral)),
          ),
          DecoratedBox(decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white.withValues(alpha: .96), Colors.white.withValues(alpha: .34), Colors.transparent]))),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Align(alignment: Alignment.topCenter, child: AppHeader())),
          const Positioned(right: 17, bottom: 12, child: Text('건강한 돼지,\n더 큰 내일', textAlign: TextAlign.right, style: TextStyle(fontSize: 13, height: 1.15, fontWeight: FontWeight.w900,letterSpacing:-.5))),
        ]),
      );
}
