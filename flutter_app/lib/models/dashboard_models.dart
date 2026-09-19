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
      this.basis = '', this.url = '', this.history = const []});
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
}

class CommodityPoint {
  const CommodityPoint(this.date, this.value);
  final String date;
  final double value;
}

class MarketFactor {
  const MarketFactor(this.title, this.status, this.detail);
  final String title;
  final String status;
  final String detail;
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
