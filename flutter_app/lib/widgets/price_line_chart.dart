import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../models/dashboard_models.dart';

class PriceLineChart extends StatelessWidget {
  const PriceLineChart({super.key, required this.series});
  final PriceSeries series;
  @override
  Widget build(BuildContext context) {
    final values=series.values;
    if(values.length<2)return const SizedBox(height:102,child:Center(child:Text('해당 기간의 공식 이력을 확인 중입니다.',style:TextStyle(fontSize:9,color:AppColors.secondary))));
    final low=values.reduce((a,b)=>a<b?a:b),high=values.reduce((a,b)=>a>b?a:b);
    final gap=(high-low).abs()<100?400.0:(high-low)*.28;
    return SizedBox(height: 102, child: LineChart(LineChartData(
    minY:(low-gap).clamp(0,double.infinity), maxY:high+gap,
    gridData: FlGridData(show: true, horizontalInterval: 1000, verticalInterval: 1, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1), getDrawingVerticalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
    borderData: FlBorderData(show: false),
    titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles:true,reservedSize:32,interval:(high+gap-(low-gap))/3,getTitlesWidget:(v,_)=>Text(_number(v),style:const TextStyle(fontSize:7,color:AppColors.secondary)))),
      bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles:true,interval:1,reservedSize:20,getTitlesWidget:(v,_){final i=v.toInt();if(i<0||i>=series.points.length)return const SizedBox();final step=series.points.length>6?2:1;return i%step==0||i==series.points.length-1?Padding(padding:const EdgeInsets.only(top:3),child:Text(_label(series.points[i].date),style:const TextStyle(fontSize:7,color:AppColors.secondary))):const SizedBox();}))),
    lineTouchData: const LineTouchData(enabled: true),
    lineBarsData: [LineChartBarData(spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])), color: AppColors.coral, barWidth: 2.5, isCurved: false,
      dotData: FlDotData(show: true, getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(radius: index == values.length-1 ? 5 : 3, color: index == values.length-1 ? Colors.white : AppColors.coral, strokeWidth: index == values.length-1 ? 3 : 0, strokeColor: AppColors.coral)),
      belowBarData: BarAreaData(show: true, gradient: LinearGradient(begin: Alignment.topCenter,end: Alignment.bottomCenter,colors:[AppColors.lightCoral.withValues(alpha:.8),AppColors.lightCoral.withValues(alpha:.12)])))],
  )));
  }
  String _label(String value){if(RegExp(r'^\d{8}$').hasMatch(value))return '${int.parse(value.substring(4,6))}/${int.parse(value.substring(6,8))}';return value;}
  String _number(double value)=>value.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
}
