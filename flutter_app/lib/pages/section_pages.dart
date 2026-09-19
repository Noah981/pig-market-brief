import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../data/market_repository.dart';

class PageShell extends StatelessWidget {
  const PageShell({super.key, required this.title, required this.subtitle, required this.child});
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 430),
        child: CustomScrollView(slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 18),
            sliver: SliverList.list(children: [
              if (title.isNotEmpty) Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
              if (subtitle.isNotEmpty) Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.secondary)),
              if (title.isNotEmpty) const SizedBox(height: 14),
              child,
            ]),
          ),
        ]),
      ),
    );
  }
}

class MarketOverviewPage extends StatelessWidget {
  const MarketOverviewPage({super.key,this.snapshot});
  final MarketSnapshot? snapshot;
  @override
  Widget build(BuildContext context) {
    final tiles = [
      _MarketTile('🐷','전국 돈가',snapshot==null?'확인 중':_number(snapshot!.price),snapshot==null?'':'원/kg',_change(snapshot),(snapshot?.change??-1)>=0),
      const _MarketTile('🌽', '옥수수', '연결 대기', '', '공식 데이터 확인 중', false),
      const _MarketTile('🫘', '대두박', '연결 대기', '', '공식 데이터 확인 중', false),
      const _MarketTile('＄', '달러 환율', '연결 대기', '', '공식 데이터 확인 중', false),
    ];
    final summaries = [
      ('돈가', '하락', '전일 대비 298원 (-4.42%)'),
      ('옥수수', '확인 중', '공식 데이터 연결 대기'),
      ('대두박', '확인 중', '공식 데이터 연결 대기'),
      ('환율', '확인 중', '공식 데이터 연결 대기'),
      ('유가', '확인 중', '공식 데이터 연결 대기'),
    ];
    return PageShell(
      title: '시황', subtitle: '지금, 시장의 흐름을 한눈에',
      child: Column(children: [
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.38,
          children: tiles,
        ),
        const SizedBox(height: 10),
        const SizedBox(height:104,child:_MarketTile('🛢️','국제 유가 (WTI)','연결 대기','','공식 데이터 확인 중',false,wide:true)),
        const SizedBox(height: 18),
        const _SectionTitle('시황 요약 (오늘)'),
        ...summaries.map((x) => _SummaryRow(x.$1, x.$2, x.$3)),
      ]),
    );
  }
  String _number(int value)=>value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'),(m)=>',');
  String _change(MarketSnapshot? s){if(s==null)return '공식 데이터 연결 중';return '${s.change>=0?'▲':'▼'} ${s.change.abs()}원 (${s.changePct.toStringAsFixed(2)}%)';}
}

class _MarketTile extends StatelessWidget {
  const _MarketTile(this.emoji, this.name, this.value, this.unit, this.change, this.up, {this.wide = false});
  final String emoji, name, value, unit, change;
  final bool up, wide;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13), decoration: appCard(radius: 15),
    child: Row(children: [
      Text(emoji, style: TextStyle(fontSize: wide ? 30 : 25)),
      const SizedBox(width: 9),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        Text(name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
        FittedBox(child: Text('$value $unit', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
        Text(change, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: up ? AppColors.coral : AppColors.blue)),
      ])),
      const Icon(Icons.chevron_right, color: AppColors.coral, size: 17),
    ]),
  );
}

class DiseasePage extends StatefulWidget {
  const DiseasePage({super.key});
  @override State<DiseasePage> createState() => _DiseasePageState();
}
class _DiseasePageState extends State<DiseasePage> {
  int tab = 0;
  @override
  Widget build(BuildContext context) {
    const outbreaks = ['공식 국내 발생정보를 확인하고 있습니다.'];
    return PageShell(
      title: '질병 정보', subtitle: '가축질병 상황을 빠르게 확인하세요',
      child: Column(children: [
        _Tabs(labels: const ['국내', '해외'], index: tab, onTap: (i) => setState(() => tab = i)),
        const SizedBox(height: 12),
        const Row(children: [Expanded(child: _Count('ASF', '2')), Expanded(child: _Count('구제역', '0')), Expanded(child: _Count('PED', '1')), Expanded(child: _Count('PRRS', '3'))]),
        const SizedBox(height: 12),
        Container(
          height: 285, decoration: appCard(radius: 16),
          child: const Stack(children: [
            Center(child: Icon(Icons.map_outlined, size: 210, color: Color(0xFFE5E6E9))),
            Positioned(left: 110, top: 70, child: Icon(Icons.circle, size: 10, color: AppColors.coral)),
            Positioned(right: 75, top: 100, child: Icon(Icons.circle, size: 10, color: AppColors.coral)),
            Positioned(right: 55, top: 180, child: Icon(Icons.circle, size: 10, color: AppColors.coral)),
            Positioned(right: 14, bottom: 13, child: Text('●  발생 지역\n●  내 위치', style: TextStyle(fontSize: 10, color: AppColors.coral))),
          ]),
        ),
        const SizedBox(height: 16),
        const _SectionTitle('최근 발생 현황'),
        ...outbreaks.map((x) => _ListRow(x)),
      ]),
    );
  }
}

class FarmCheckPage extends StatefulWidget {
  const FarmCheckPage({super.key});
  @override State<FarmCheckPage> createState() => _FarmCheckPageState();
}
class _FarmCheckPageState extends State<FarmCheckPage> {
  int tab = 0;
  final checks = List<bool>.filled(8, false);
  static const labels = ['온도 (적정 20~24℃)', '환기 상태', '급수 상태', '급이 상태', '돈방 상태', '분뇨 상태', '질병 이상 징후', '폐사 두수'];
  @override
  Widget build(BuildContext context) => PageShell(
    title: '농장점검', subtitle: '오늘도 건강한 농장을 위해',
    child: Column(children: [
      _Tabs(labels: const ['분만사', '자돈사', '육성사', '비육사'], index: tab, onTap: (i) => setState(() => tab = i)),
      const SizedBox(height: 13),
      Row(children: [const Expanded(child: Text('점검 항목 (분만사)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900))), Text(_today(), style: const TextStyle(fontSize: 9, color: AppColors.secondary))]),
      ...List.generate(checks.length, (i) => _CheckRow(label: labels[i], checked: checks[i], onTap: () => setState(() => checks[i] = !checks[i]))),
      const SizedBox(height: 8),
      TextField(maxLines: 2, decoration: InputDecoration(hintText: '특이사항이 있으면 입력하세요.', hintStyle: const TextStyle(fontSize: 10), filled: true, fillColor: const Color(0xFFF6F6F8), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none))),
      const SizedBox(height: 10),
      SizedBox(width: double.infinity, height: 44, child: FilledButton(onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('점검 내용이 저장되었습니다.'))), style: FilledButton.styleFrom(backgroundColor: AppColors.coral), child: const Text('저장하기', style: TextStyle(fontWeight: FontWeight.w800)))),
      const SizedBox(height: 16),
      const _SectionTitle('최근 점검 기록'),
      const _SummaryRow('9.17', '분만사', '이상 없음'),
      const _SummaryRow('9.16', '자돈사', '환기 점검 필요'),
      const _SummaryRow('9.15', '비육사', '이상 없음'),
    ]),
  );

  String _today() {
    final now = DateTime.now();
    const weekdays = ['월', '화', '수', '목', '금', '토', '일'];
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}.${two(now.month)}.${two(now.day)} (${weekdays[now.weekday - 1]})';
  }
}

class MorePage extends StatelessWidget {
  const MorePage({super.key});
  static const items = [
    ('내 농장', '등록된 농장 정보 관리', Icons.home_work_outlined),
    ('인증 정보', '깨끗한 축산농장 · 저탄소 · HACCP 등', Icons.health_and_safety_outlined),
    ('정부·지자체 지원사업', '내 지역 맞춤 지원사업 확인', Icons.account_balance_outlined),
    ('알림 설정', '돈가 · 질병 · 주문 · 지원사업 등', Icons.notifications_outlined),
    ('지역 설정', '내 지역: 대구 달성군', Icons.location_on_outlined),
    ('데이터 출처', '정보 제공 기관 안내', Icons.info_outline),
    ('공지사항', '앱 소식 및 업데이트', Icons.campaign_outlined),
    ('이용약관 / 개인정보처리방침', '', Icons.article_outlined),
    ('앱 정보', '버전 1.1.0', Icons.info),
  ];
  @override
  Widget build(BuildContext context) => PageShell(
    title: '', subtitle: '',
    child: Column(children: [
      const ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(radius: 24, backgroundColor: AppColors.lightCoral, child: Icon(Icons.person, color: Color(0xFF4B5A70))), title: Text('돈돈해님', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)), subtitle: Text('항상 감사합니다.', style: TextStyle(fontSize: 10)), trailing: Icon(Icons.settings_outlined)),
      const Divider(),
      ...items.map((x) => ListTile(minTileHeight: 57, contentPadding: EdgeInsets.zero, leading: Icon(x.$3, color: const Color(0xFF4B5A70), size: 21), title: Text(x.$1, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)), subtitle: x.$2.isEmpty ? null : Text(x.$2, style: const TextStyle(fontSize: 9, color: AppColors.secondary)), trailing: const Icon(Icons.chevron_right, size: 18))),
    ]),
  );
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.labels, required this.index, required this.onTap});
  final List<String> labels; final int index; final ValueChanged<int> onTap;
  @override Widget build(BuildContext context) => Container(
    height: 38, padding: const EdgeInsets.all(3), decoration: BoxDecoration(color: const Color(0xFFF4F4F6), borderRadius: BorderRadius.circular(16)),
    child: Row(children: List.generate(labels.length, (i) => Expanded(child: InkWell(onTap: () => onTap(i), child: Container(alignment: Alignment.center, decoration: BoxDecoration(color: i == index ? AppColors.coral : Colors.transparent, borderRadius: BorderRadius.circular(13)), child: Text(labels[i], style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: i == index ? Colors.white : AppColors.secondary))))))),
  );
}
class _Count extends StatelessWidget {
  const _Count(this.name, this.count); final String name, count;
  @override Widget build(BuildContext context) => Container(margin: const EdgeInsets.symmetric(horizontal: 2), padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: const Color(0xFFF8F8FA), borderRadius: BorderRadius.circular(12)), child: Text('$name  $count', textAlign: TextAlign.center, style: TextStyle(fontSize: 9.5, fontWeight: FontWeight.w800, color: count == '0' ? AppColors.secondary : AppColors.coral)));
}
class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, required this.checked, required this.onTap}); final String label; final bool checked; final VoidCallback onTap;
  @override Widget build(BuildContext context) => InkWell(onTap: onTap, child: SizedBox(height: 39, child: Row(children: [Icon(checked ? Icons.check_box : Icons.check_box_outline_blank, color: checked ? AppColors.coral : AppColors.secondary, size: 20), const SizedBox(width: 7), Expanded(child: Text(label, style: const TextStyle(fontSize: 10.5))), Text(checked ? '양호' : '확인', style: TextStyle(fontSize: 9, color: checked ? AppColors.coral : AppColors.secondary))])));
}
class _SummaryRow extends StatelessWidget {
  const _SummaryRow(this.name, this.state, this.detail); final String name, state, detail;
  @override Widget build(BuildContext context) => Container(height: 40, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))), child: Row(children: [SizedBox(width: 58, child: Text(name, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700))), SizedBox(width: 58, child: Text(state, style: const TextStyle(fontSize: 10, color: AppColors.coral))), Expanded(child: Text(detail, style: const TextStyle(fontSize: 10, color: AppColors.secondary)))]));
}
class _ListRow extends StatelessWidget {
  const _ListRow(this.text); final String text;
  @override Widget build(BuildContext context) => Container(height: 40, alignment: Alignment.centerLeft, decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.divider))), child: Text(text, style: const TextStyle(fontSize: 10.5)));
}
class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text); final String text;
  @override Widget build(BuildContext context) => Align(alignment: Alignment.centerLeft, child: Text(text, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)));
}
