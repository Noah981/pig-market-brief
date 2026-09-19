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
  const Commodity(this.name, this.value, this.unit, this.change, this.icon);
  final String name;
  final String value;
  final String unit;
  final double? change;
  final IconData icon;
}

class NoticeItem {
  const NoticeItem(this.category, this.title, this.date, this.color);
  final String category;
  final String title;
  final String date;
  final Color color;
}
