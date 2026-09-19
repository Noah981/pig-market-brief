import 'package:flutter/material.dart';
import '../models/dashboard_models.dart';
import '../theme/app_theme.dart';

const priceSeries = [
  PriceSeries('일간', [PricePoint('09/09',5800),PricePoint('09/10',6200),PricePoint('09/11',6700),PricePoint('09/14',6850),PricePoint('09/15',7000),PricePoint('09/16',6900),PricePoint('09/17',6740),PricePoint('09/18',6442)]),
  PriceSeries('주간', [PricePoint('8월1주',6150),PricePoint('8월2주',6280),PricePoint('8월3주',6400),PricePoint('8월4주',6510),PricePoint('9월1주',6470),PricePoint('9월2주',6442)]),
  PriceSeries('월간', [PricePoint('2월',5088),PricePoint('3월',4894),PricePoint('4월',5603),PricePoint('5월',5862),PricePoint('6월',5835),PricePoint('7월',5675),PricePoint('8월',5816),PricePoint('9월',6442)]),
  PriceSeries('연간', [PricePoint('2024',4829),PricePoint('2025',5280),PricePoint('2026',5638)]),
];

List<TodoItem> mockTodos() => [
  TodoItem('사료 주문', '사료', '오늘', const Color(0xFFFFDCE6)),
  TodoItem('2그룹 이유', '3주', '오늘', AppColors.purple),
  TodoItem('분만사 환기 점검', '주간', '오늘', const Color(0xFFE9DDFF)),
  TodoItem('돈사 청소', '일반', '완료', const Color(0xFFE8ECF2), done: true),
];

const commodities = [
  Commodity('옥수수', '확인 중', '', null, Icons.grass, id:'corn'),
  Commodity('대두박', '확인 중', '', null, Icons.eco, id:'soybean_meal'),
  Commodity('소맥', '확인 중', '', null, Icons.grain, id:'wheat'),
  Commodity('대두', '확인 중', '', null, Icons.spa, id:'soybean'),
  Commodity('국제유가\n(WTI)', '확인 중', '', null, Icons.local_gas_station, id:'wti'),
  Commodity('환율\n(USD/KRW)', '확인 중', '', null, Icons.attach_money, id:'usd_krw'),
];

const notices = [
  NoticeItem('시황', '전국 돈가 전일 대비 298원 하락 (6,442원/kg)', '2026. 09. 18', Color(0xFFFFDCE6)),
  NoticeItem('질병', '공식 질병정보를 확인하고 있습니다', '2026. 09. 19', Color(0xFFDCEFFF)),
  NoticeItem('정책', '공식 지원사업 공고를 확인하고 있습니다', '2026. 09. 19', Color(0xFFE2F5E9)),
];
