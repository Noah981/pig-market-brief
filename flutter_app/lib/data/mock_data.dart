import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

const priceSeries = [
  PriceSeries('일간', [5800, 6200, 6700, 6850, 7000, 6900, 6900, 6442]),
  PriceSeries('주간', [6150, 6280, 6400, 6510, 6470, 6550, 6500, 6442]),
  PriceSeries('월간', [5900, 6030, 6180, 6320, 6500, 6620, 6550, 6442]),
  PriceSeries('연간', [5700, 5880, 6100, 6350, 6600, 6800, 6640, 6442]),
];

List<TodoItem> mockTodos() => [
  TodoItem('사료 주문', '사료', '오늘', const Color(0xFFFFDCE6)),
  TodoItem('2그룹 이유', '3주', '오늘', AppColors.purple),
  TodoItem('분만사 환기 점검', '주간', '오늘', const Color(0xFFE9DDFF)),
  TodoItem('돈사 청소', '일반', '완료', const Color(0xFFE8ECF2), done: true),
];

const commodities = [
  Commodity('옥수수', '265.3', r'$/톤', 1.2, Icons.grass),
  Commodity('대두박', '423.7', r'$/톤', .8, Icons.eco),
  Commodity('국제유가\n(WTI)', '72.1', r'$/bbl', 1.6, Icons.local_gas_station),
  Commodity('환율\n(USD/KRW)', '1,335.2', '원', -.3, Icons.attach_money),
];

const notices = [
  NoticeItem('시황', '금일 전국 돈가 전일 대비 298원 하락 (6,442원/kg)', '2025. 09. 18', Color(0xFFFFDCE6)),
  NoticeItem('질병', '환절기 PRRS·PED 예방관리 강화 필요', '2025. 09. 17', Color(0xFFDCEFFF)),
  NoticeItem('정책', '저탄소 축산 인증 농가 인센티브 안내', '2025. 09. 16', Color(0xFFE2F5E9)),
];
