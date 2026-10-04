import 'package:flutter/material.dart';

class PriceSeries {
  final String label;
  final List<PricePoint> points;
  const PriceSeries(this.label, this.points);
  List<double> get values => points.map((x) => x.value).toList(growable: false);
}

class PricePoint {
  const PricePoint(this.date, this.value, {this.resolution = 'day'});
  final String date;
  final double value;
  final String resolution;
}

class TodoItem {
  TodoItem(this.title, this.type, this.due, this.color, {this.done = false});
  final String title;
  final String type;
  final String due;
  final Color color;
  bool done;
}

class Commodity {
  const Commodity(this.name, this.value, this.unit, this.change, this.icon,
      {this.id = '', this.source = '', this.asOf = '', this.frequency = '',
      this.basis = '', this.url = '', this.history = const [],this.analysisSummary='',
      this.analysisUpdatedAt='',this.analysisConfidence='',this.analysisFactors=const [],
      this.analysisSources=const [],this.previousValue,this.previousDate='',this.updatedAt='',this.status='LIVE'});
  final String name;
  final String value;
  final String unit;
  final double? change;
  final IconData icon;
  final String id;
  final String source;
  final String asOf;
  final String frequency;
  final String basis;
  final String url;
  final List<CommodityPoint> history;
  final String analysisSummary;
  final String analysisUpdatedAt;
  final String analysisConfidence;
  final List<MarketFactor> analysisFactors;
  final List<MarketSource> analysisSources;
  final double? previousValue;
  final String previousDate,updatedAt,status;
  bool get hasQuote => double.tryParse(value)?.isFinite == true && (double.tryParse(value) ?? 0) > 0;
  String get shortName => name.replaceAll('\n', ' ');
  String get periodLabel => frequency == 'monthly' ? '월평균' : '일간 공표';
  String get basisLabel {
    final digits=asOf.replaceAll(RegExp(r'[^0-9]'),'');
    if(digits.length<8)return '기준일 확인 필요';
    return frequency=='monthly'?'${digits.substring(0,4)}.${digits.substring(4,6)} 월평균':'${digits.substring(4,6)}.${digits.substring(6,8)} 기준';
  }
  String get comparisonLabel => change==null?'비교 자료 없음':change==0?'— 0.0%':'${change!>0?'▲ +':'▼ −'}${change!.abs().toStringAsFixed(1)}%';
  Commodity copyWith({String? status}) => Commodity(name,value,unit,change,icon,id:id,source:source,asOf:asOf,frequency:frequency,basis:basis,url:url,history:history,analysisSummary:analysisSummary,analysisUpdatedAt:analysisUpdatedAt,analysisConfidence:analysisConfidence,analysisFactors:analysisFactors,analysisSources:analysisSources,previousValue:previousValue,previousDate:previousDate,updatedAt:updatedAt,status:status??this.status);

}

class CommodityPoint {
  const CommodityPoint(this.date, this.value);
  final String date;
  final double value;
}

class MarketFactor {
  const MarketFactor(this.title, this.status, this.detail,{this.source='',this.sourceDate='',this.direction='neutral'});
  final String title,status,detail,source,sourceDate,direction;
}

class MarketAnalysis {
  const MarketAnalysis({
    required this.summary,
    required this.factors,
    required this.updatedAt,
    this.sources = const [],
  });
  final String summary;
  final List<MarketFactor> factors;
  final String updatedAt;
  final List<MarketSource> sources;
}

class MarketSource {
  const MarketSource(this.name, this.label, this.url);
  final String name, label, url;
}

class NoticeItem {
  const NoticeItem(this.category, this.title, this.date, this.color);
  final String category;
  final String title;
  final String date;
  final Color color;
}
