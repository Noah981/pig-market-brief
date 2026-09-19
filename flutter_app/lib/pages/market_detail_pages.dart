import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../data/market_repository.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

class PigPriceDetailPage extends StatelessWidget {
  const PigPriceDetailPage({super.key, required this.snapshot, required this.analysis});
  final MarketSnapshot? snapshot;
  final MarketAnalysis? analysis;

  @override
  Widget build(BuildContext context) => _DetailScaffold(
        title: '전국 돈가 상세',
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _ValueCard(
            title: '생산자 돼지 경락가격 (제주 제외)',
            value: snapshot == null ? '확정 가격 확인 중' : '${_number(snapshot!.price)}원/kg',
            change: snapshot == null ? '' : '${snapshot!.change >= 0 ? '▲' : '▼'} ${_number(snapshot!.change.abs())}원 (${snapshot!.changePct.toStringAsFixed(2)}%)',
            up: (snapshot?.change ?? 0) >= 0,
          ),
          const SizedBox(height: 16),
          const Text('왜 움직였나요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          if (analysis == null || analysis!.factors.isEmpty)
            const _InfoBox('공식 가격과 수급 자료를 확인하고 있습니다.')
          else ...[
            Text(analysis!.summary, style: const TextStyle(fontSize: 12, height: 1.55, color: AppColors.secondary)),
            const SizedBox(height: 10),
            ...analysis!.factors.map((x) => _FactorTile(x)),
          ],
          const SizedBox(height: 12),
          _InfoBox(snapshot == null
              ? '출처: 축산물품질평가원 축산유통정보 다봄'
              : '출처: ${snapshot!.source}\n기준: ${snapshot!.scope}\n가격 기준일: ${_date(snapshot!.date)}'),
        ]),
      );

  String _number(int value) => value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',');
  String _date(String value) => value.length == 8 ? '${value.substring(0, 4)}.${value.substring(4, 6)}.${value.substring(6, 8)}' : value;
}

class CommodityDetailPage extends StatelessWidget {
  const CommodityDetailPage({super.key, required this.item});
  final Commodity item;

  @override
  Widget build(BuildContext context) {
    final drivers = _drivers(item.id);
    return _DetailScaffold(
      title: '${item.name.replaceAll('\n', ' ')} 상세',
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _ValueCard(
          title: item.name.replaceAll('\n', ' '),
          value: item.change == null ? '공식 데이터 연결 대기' : '${item.value} ${item.unit}',
          change: item.change == null ? '확인되지 않은 수치는 표시하지 않습니다.' : '${item.change! >= 0 ? '▲ 상승' : '▼ 하락'} ${item.change!.abs().toStringAsFixed(1)}% · ${item.frequency == 'monthly' ? '전월 대비' : '직전 발표 대비'}',
          up: (item.change ?? 0) >= 0,
        ),
        if (item.history.length >= 2) ...[
          const SizedBox(height: 14),
          _CommodityChart(points: item.history),
        ],
        const SizedBox(height: 16),
        const Text('왜 오르내리나요?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 5),
        const Text('아래는 가격 방향을 확인할 때 함께 보는 주요 변수입니다. 검증된 당일 원인이 확보되기 전에는 원인으로 단정하지 않습니다.', style: TextStyle(fontSize: 11, height: 1.5, color: AppColors.secondary)),
        const SizedBox(height: 10),
        ...drivers.map((x) => _FactorTile(MarketFactor(x.$1, '확인 요인', x.$2))),
        const SizedBox(height: 12),
        _InfoBox(item.source.isEmpty
            ? '데이터 출처 연결 검증 중\n값과 변동 이유가 공식 자료로 확인되면 자동 표시합니다.'
            : '출처: ${item.source}${item.asOf.isEmpty ? '' : '\n기준일: ${item.asOf}'}${item.basis.isEmpty ? '' : '\n기준: ${item.basis}'}\n갱신주기: ${item.frequency == 'monthly' ? '월간' : '일간'}'),
      ]),
    );
  }

  List<(String, String)> _drivers(String id) {
    switch (id) {
      case 'corn':
      case 'soybean_meal':
      case 'soybean':
      case 'wheat':
        return const [
          ('미국 선물시장', 'CBOT 선물가격과 거래 흐름을 확인합니다.'),
          ('작황과 공급', 'USDA 작황·재고·수출입 전망과 주요 산지 날씨를 확인합니다.'),
          ('원/달러 환율', '수입 원료의 원화 환산 비용에 영향을 줍니다.'),
          ('운임과 에너지', '해상운임과 유가 변화가 국내 도입 비용에 반영될 수 있습니다.'),
        ];
      case 'wti':
        return const [
          ('원유 재고', '미국 EIA 원유·휘발유 재고 변화를 확인합니다.'),
          ('산유국 공급', 'OPEC+ 감산·증산 발표와 실제 생산량을 확인합니다.'),
          ('지정학 상황', '주요 산유국과 수송로의 공급 차질 가능성을 확인합니다.'),
          ('세계 수요', '경기와 석유 수요 전망 변화를 함께 봅니다.'),
        ];
      default:
        return const [
          ('한국·미국 금리', '한국은행과 미국 연준의 기준금리 및 전망 차이를 확인합니다.'),
          ('달러 강도', '주요 통화 대비 달러 흐름을 확인합니다.'),
          ('무역과 위험선호', '수출입, 외국인 자금 흐름과 국제 금융시장 변동을 확인합니다.'),
          ('공식 고시환율', '공식 기준시점과 적용 환율 종류를 확인합니다.'),
        ];
    }
  }
}

class _CommodityChart extends StatelessWidget {
  const _CommodityChart({required this.points});
  final List<CommodityPoint> points;
  @override
  Widget build(BuildContext context) {
    final values = points.map((x) => x.value).toList();
    final low = values.reduce((a, b) => a < b ? a : b);
    final high = values.reduce((a, b) => a > b ? a : b);
    final padding = (high - low).abs() < 0.01 ? high * .08 : (high - low) * .16;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 7), decoration: appCard(radius: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('최근 흐름', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900)),
        const SizedBox(height: 12),
        SizedBox(height: 150, child: LineChart(LineChartData(
          minY: low - padding, maxY: high + padding,
          borderData: FlBorderData(show: false),
          gridData: FlGridData(show: true, drawVerticalLine: false, getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.divider, strokeWidth: 1)),
          titlesData: FlTitlesData(topTitles: const AxisTitles(), rightTitles: const AxisTitles(), leftTitles: const AxisTitles(), bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 22, interval: (points.length - 1) / 3, getTitlesWidget: (value, meta) {
            final index = value.round().clamp(0, points.length - 1);
            if (value != 0 && value < points.length - 2 && index % 3 != 0) return const SizedBox();
            final date = points[index].date;
            return Padding(padding: const EdgeInsets.only(top: 5), child: Text(date.length >= 7 ? date.substring(5, 7) + '/' + date.substring(8, 10) : date, style: const TextStyle(fontSize: 8, color: AppColors.secondary)));
          }))),
          lineTouchData: LineTouchData(enabled: true, touchTooltipData: LineTouchTooltipData(getTooltipItems: (spots) => spots.map((x) => LineTooltipItem(x.y.toStringAsFixed(x.y >= 1000 ? 1 : 2), const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800))).toList())),
          lineBarsData: [LineChartBarData(spots: List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i])), color: AppColors.coral, barWidth: 2.5, isCurved: true, dotData: const FlDotData(show: false), belowBarData: BarAreaData(show: true, color: AppColors.lightCoral.withValues(alpha: .55)))],
        ))),
      ]),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({required this.title, required this.child});
  final String title;
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900))),
        body: SafeArea(child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 430), child: ListView(padding: const EdgeInsets.all(20), children: [child])))),
      );
}

class _ValueCard extends StatelessWidget {
  const _ValueCard({required this.title, required this.value, required this.change, required this.up});
  final String title, value, change;
  final bool up;
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(18), decoration: appCard(radius: 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown, child: Text(value, style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900))),
          if (change.isNotEmpty) ...[const SizedBox(height: 4), Text(change, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: up ? AppColors.coral : AppColors.blue))],
        ]),
      );
}

class _FactorTile extends StatelessWidget {
  const _FactorTile(this.factor);
  final MarketFactor factor;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.divider)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4), decoration: BoxDecoration(color: AppColors.lightCoral, borderRadius: BorderRadius.circular(20)), child: Text(factor.status, style: const TextStyle(fontSize: 8, color: AppColors.coral, fontWeight: FontWeight.w800))),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(factor.title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900)), const SizedBox(height: 3), Text(factor.detail, style: const TextStyle(fontSize: 10.5, height: 1.5, color: AppColors.secondary))])),
        ]),
      );
}

class _InfoBox extends StatelessWidget {
  const _InfoBox(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Container(width: double.infinity, padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.lightBlue, borderRadius: BorderRadius.circular(14)), child: Text(text, style: const TextStyle(fontSize: 10.5, height: 1.5, color: AppColors.secondary)));
}
