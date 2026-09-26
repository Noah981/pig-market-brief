import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PeriodTabBar extends StatelessWidget {
  const PeriodTabBar({super.key, required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) => Container(
        height: 25,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(color: const Color(0xFFF7F7F9), borderRadius: BorderRadius.circular(24)),
        child: Row(children: List.generate(4, (i) => Expanded(child: InkWell(
          borderRadius: BorderRadius.circular(22), onTap: () => onChanged(i),
          child: AnimatedContainer(duration: const Duration(milliseconds: 180), alignment: Alignment.center,
            decoration: BoxDecoration(color: i == selected ? AppColors.lightCoral : Colors.transparent, borderRadius: BorderRadius.circular(22)),
            child: Text(['일간','주간','월간','연간'][i], style: TextStyle(fontSize: 9, fontWeight: i == selected ? FontWeight.w800 : FontWeight.w500, color: i == selected ? AppColors.coral : AppColors.secondary))),
        )))),
      );
}
