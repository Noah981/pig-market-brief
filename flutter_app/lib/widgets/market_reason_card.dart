import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class MarketReasonCard extends StatelessWidget {
  const MarketReasonCard({super.key, required this.analysis, required this.onTap});
  final MarketAnalysis? analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final factors = analysis?.factors.take(2).toList() ?? const <MarketFactor>[];
    return Material(
      color: const Color(0xFFFFF0F4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(11),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.trending_down_rounded, color: AppColors.coral, size: 25),
              SizedBox(width: 6),
              Expanded(child: Text('돈가 변동 이유', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900))),
              Icon(Icons.chevron_right, color: AppColors.coral, size: 20),
            ]),
            const SizedBox(height: 10),
            if (factors.isEmpty)
              const Expanded(child: Center(child: Text('공식 자료를 확인하고 있습니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: AppColors.secondary))))
            else
              ...factors.map((x) => Padding(
                    padding: const EdgeInsets.only(bottom: 9),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Container(margin: const EdgeInsets.only(top: 3), width: 6, height: 6, decoration: const BoxDecoration(color: AppColors.coral, shape: BoxShape.circle)),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(x.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                        Text(x.detail, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 8, height: 1.35, color: AppColors.secondary)),
                      ])),
                    ]),
                  )),
            const Spacer(),
            const Text('근거와 출처 자세히 보기', style: TextStyle(fontSize: 8.5, color: AppColors.coral, fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}
