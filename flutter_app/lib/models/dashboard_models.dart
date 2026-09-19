import 'package:flutter/material.dart';

class PriceSeries {
  final String label;
  final List<double> values;
  const PriceSeries(this.label, this.values);
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
      {this.id = '', this.source = '', this.asOf = ''});
  final String name;
  final String value;
  final String unit;
  final double? change;
  final IconData icon;
  final String id;
  final String source;
  final String asOf;
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
  });
  final String summary;
  final List<MarketFactor> factors;
  final String updatedAt;
}

class NoticeItem {
  const NoticeItem(this.category, this.title, this.date, this.color);
  final String category;
  final String title;
  final String date;
  final Color color;
}
