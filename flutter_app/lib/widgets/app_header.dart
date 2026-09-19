import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AppHeader extends StatelessWidget {
  const AppHeader({super.key});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 66,
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(border: Border.all(color: AppColors.coral, width: 3), shape: BoxShape.circle),
            child: const Icon(Icons.savings_outlined, color: AppColors.coral, size: 27),
          ),
          const SizedBox(width: 9),
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
            RichText(text: const TextSpan(style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900), children: [TextSpan(text: '돈', style: TextStyle(color: AppColors.text)), TextSpan(text: '돈해', style: TextStyle(color: AppColors.coral))])),
            const Text('양돈의 오늘을 든든하게', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ]),
          const Spacer(),
          const Column(crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
            Text('2025년 9월 18일 (목) 07:32', style: TextStyle(fontSize: 9.5, color: AppColors.secondary)),
            SizedBox(height: 5),
            Badge(smallSize: 7, child: Icon(Icons.notifications, size: 25, color: Color(0xFF24344D))),
          ]),
        ]),
      );
}
