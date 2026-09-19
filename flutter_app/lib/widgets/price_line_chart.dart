import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class PriceLineChart extends StatelessWidget {
  const PriceLineChart({super.key, required this.values});
  final List<double> values;
  @override
  Widget build(BuildContext context) => SizedBox(height: 145, child: LineChart(LineChartData(
    minY: 4000, maxY: 8000,
    gridData: FlGridData(show: true, horizontalInterval: 1000, verticalInterval: 1, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1), getDrawingVerticalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40, interval: 1000, getTitlesWidget: (v, _) => Text(v.toInt().toString().replaceFirst(RegExp(r'000$'), ',000'), style: const TextStyle(fontSize: 9, color: AppColors.secondary)))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, interval: 1, reservedSize: 25, getTitlesWidget: (v, _) { final i=v.toInt(); return i>=0&&i<8 ? Padding(padding: const EdgeInsets.only(top: 5), child: Text('9/${11+i}', style: const TextStyle(fontSize: 9, color: AppColors.secondary))) : const SizedBox();}))),
    lineTouchData: const LineTouchData(enabled: true),
    lineBarsData: [LineChartBarData(spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])), color: AppColors.coral, barWidth: 2.5, isCurved: false,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: index == values.length-1 ? 5 : 3, color: index == values.length-1 ? Colors.white : AppColors.coral, strokeWidth: index == values.length-1 ? 3 : 0, strokeColor: AppColors.coral)),
      belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[AppColors.lightCoral.withValues(alpha:.8),AppColors.lightCoral.withValues(alpha:.12)])))],
  )));
}
