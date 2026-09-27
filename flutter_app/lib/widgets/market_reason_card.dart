import 'package:flutter/material.dart';

import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class MarketReasonCard extends StatelessWidget {
  const MarketReasonCard({super.key, required this.analysis, required this.onTap});
  final MarketAnalysis? analysis;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final factors = analysis?.factors.take(4).toList() ?? const <MarketFactor>[];
    return Material(
      color: const Color(0xFFFFF0F4),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10,10,10,9),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.trending_down_rounded, color: AppColors.coral, size: 22),
              SizedBox(width: 5),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('돈가 변동 이유', maxLines: 1, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w900)),
                ),
              ),
              SizedBox(width: 2),
              Icon(Icons.chevron_right, color: AppColors.coral, size: 18),
            ]),
            const SizedBox(height: 7),
            if (factors.isEmpty)
              const Expanded(child: Center(child: Text('공식 자료를 확인하고 있습니다.', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, color: AppColors.secondary))))
            else
              ...factors.map((x) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                      Container(width:27,height:27,decoration:BoxDecoration(color:Colors.white.withValues(alpha:.78),borderRadius:BorderRadius.circular(8)),child:Icon(_icon(x.title),size:17,color:_color(x))),
                      const SizedBox(width: 6),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(x.title, maxLines: 1, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w900))),
                        Text(x.detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 7.4, height: 1.25, color: AppColors.secondary)),
                      ])),
                      const SizedBox(width:3),Icon(x.direction=='up'?Icons.arrow_upward_rounded:x.direction=='down'?Icons.arrow_downward_rounded:Icons.arrow_forward_rounded,size:16,color:_color(x)),
                    ]),
                  )),
            const Spacer(),
            Container(height:30,alignment:Alignment.center,decoration:BoxDecoration(border:Border.all(color:AppColors.coral.withValues(alpha:.55)),borderRadius:BorderRadius.circular(9)),child:const Text('근거와 출처 자세히 보기  ›',style:TextStyle(fontSize:8.5,color:AppColors.coral,fontWeight:FontWeight.w900))),
          ]),
        ),
      ),
    );
  }
  static Color _color(MarketFactor x)=>x.direction=='down'?AppColors.blue:x.direction=='up'?AppColors.coral:AppColors.secondary;
  static IconData _icon(String title){if(title.contains('경락두수'))return Icons.local_shipping_rounded;if(title.contains('도체중'))return Icons.scale_rounded;if(title.contains('총중량'))return Icons.inventory_2_rounded;return Icons.analytics_rounded;}
}
