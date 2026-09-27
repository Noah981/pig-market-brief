import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import 'api_exception.dart';

class KapePigPrice {
  const KapePigPrice({required this.date, required this.price, required this.count});
  final String date;
  final int price;
  final int count;
}

class KapeGradePrice {
  const KapeGradePrice({required this.grade,required this.price,required this.count,required this.date});
  final String grade,date;final int price,count;
}

class KapeAuctionStatus {
  const KapeAuctionStatus({required this.date,required this.totalCount,required this.castratedCount,required this.femaleCount,this.averageCarcassWeight});
  final String date;
  final int totalCount,castratedCount,femaleCount;
  final double? averageCarcassWeight;
}

class KapeDabomSnapshot {
  const KapeDabomSnapshot({required this.date, required this.grades, required this.auctionStatus});
  final String date;
  final List<KapeGradePrice> grades;
  final KapeAuctionStatus auctionStatus;
}

class KapeApiClient {
  KapeApiClient({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.kapeApiKey;
  final http.Client _client;
  final String _apiKey;
  static const _base = 'data.ekape.or.kr';
  static const _dabomBase = 'www.ekapepia.com';
  static const _dabomPath = '/v3/price/auction/period/pig/detail.do';
  static const _nationwideExcludingJeju = '057016';

  Future<KapePigPrice?> priceFor(String ymd) async {
    if (_apiKey.isEmpty) throw const OfficialApiException('KAPE', 'missing-key');
    var amount = 0.0, count = 0;
    for (final sex in const ['025001', '025003']) {
      final normalizedKey = Uri.decodeComponent(_apiKey);
      final uri = Uri.http(_base, '/openapi-data/service/user/grade/auct/pigGrade', {
        'serviceKey': normalizedKey, 'startYmd': ymd, 'endYmd': ymd,
        'skinYn': 'Y', 'sexCd': sex, 'egradeExceptYn': 'Y',
      });
      final response = await _client.get(uri).timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) throw OfficialApiException('KAPE', 'http', response.statusCode);
      final xml = utf8.decode(response.bodyBytes,allowMalformed:true);
      final code = RegExp(r'<resultCode>(.*?)</resultCode>').firstMatch(xml)?.group(1)?.trim();
      if (code != null && code != '00') throw const OfficialApiException('KAPE', 'service-error');
      final items = RegExp(r'<item>([\s\S]*?)</item>').allMatches(xml);
      for (final item in items) {
        final body = item.group(1)!;
        double? number(String tag) => double.tryParse((RegExp('<$tag>(.*?)</$tag>').firstMatch(body)?.group(1) ?? '').replaceAll(',', ''));
        final price = number('c_1101eTotAmt'), n = number('c_1101eTotCnt');
        if (price != null && n != null && price > 0 && n > 0) { amount += price * n; count += n.round(); }
      }
    }
    return count == 0 ? null : KapePigPrice(date: ymd, price: (amount / count).round(), count: count);
  }

  Future<List<KapePigPrice>> latest({int lookbackDays = 14}) async {
    final now = DateTime.now().toUtc().add(const Duration(hours: 9));
    final out = <KapePigPrice>[];
    for (var ago = 0; ago < lookbackDays && out.length < 2; ago++) {
      final day = now.subtract(Duration(days: ago));
      final ymd = '${day.year.toString().padLeft(4, '0')}${day.month.toString().padLeft(2, '0')}${day.day.toString().padLeft(2, '0')}';
      final value = await priceFor(ymd);
      if (value != null) out.add(value);
    }
    if (out.isEmpty) throw const OfficialApiException('KAPE', 'empty-result');
    return out.reversed.toList();
  }

  Future<List<KapeGradePrice>> gradePricesFor(String ymd)async{
    final table=await _dabomTable(ymd:ymd);
    return _gradeRows(table);
  }

  Future<KapeAuctionStatus> auctionStatusFor(String ymd)async{
    final all=await _dabomTable(ymd:ymd);
    final female=await _dabomTable(ymd:all.date,sex:'1');
    final castrated=await _dabomTable(ymd:all.date,sex:'3');
    final overall=_summaryRow(all);
    return KapeAuctionStatus(
      date:all.date,
      totalCount:_integer(overall,1),
      femaleCount:_integer(_summaryRow(female),1),
      castratedCount:_integer(_summaryRow(castrated),1),
      averageCarcassWeight:_decimal(overall,3),
    );
  }

  Future<KapeDabomSnapshot> latestDabom({String? endYmd,int lookbackDays=14})async{
    final now=DateTime.now().toUtc().add(const Duration(hours:9));
    final end=endYmd==null?now:DateTime.parse('${endYmd.substring(0,4)}-${endYmd.substring(4,6)}-${endYmd.substring(6,8)}');
    OfficialApiException? lastError;
    for(var ago=0;ago<lookbackDays;ago++){
      final day=end.subtract(Duration(days:ago));
      final ymd='${day.year.toString().padLeft(4,'0')}${day.month.toString().padLeft(2,'0')}${day.day.toString().padLeft(2,'0')}';
      try{
        final all=await _dabomTable(ymd:ymd);
        final grades=_gradeRows(all);
        if(grades.length!=4)continue;
        final female=await _dabomTable(ymd:all.date,sex:'1');
        final castrated=await _dabomTable(ymd:all.date,sex:'3');
        final overall=_summaryRow(all);
        return KapeDabomSnapshot(date:all.date,grades:grades,auctionStatus:KapeAuctionStatus(
          date:all.date,totalCount:_integer(overall,1),femaleCount:_integer(_summaryRow(female),1),castratedCount:_integer(_summaryRow(castrated),1),averageCarcassWeight:_decimal(overall,3),
        ));
      }on OfficialApiException catch(e){lastError=e;}
    }
    throw lastError??const OfficialApiException('KAPE_DABOM','empty-result');
  }

  Future<List<KapeGradePrice>> gradeHistory(String endYmd,{int lookbackDays=35,int maxTradingDays=8})async{
    final end=DateTime.parse('${endYmd.substring(0,4)}-${endYmd.substring(4,6)}-${endYmd.substring(6,8)}');
    final rows=<KapeGradePrice>[];var tradingDays=0;
    for(var ago=0;ago<lookbackDays&&tradingDays<maxTradingDays;ago++){
      final day=end.subtract(Duration(days:ago));
      final ymd='${day.year.toString().padLeft(4,'0')}${day.month.toString().padLeft(2,'0')}${day.day.toString().padLeft(2,'0')}';
      final values=await gradePricesFor(ymd);
      if(values.isNotEmpty){rows.addAll(values);tradingDays++;}
    }
    rows.sort((a,b)=>a.date.compareTo(b.date));return rows;
  }

  Future<_DabomTable> _dabomTable({required String ymd,String sex=''})async{
    final dashed='${ymd.substring(0,4)}-${ymd.substring(4,6)}-${ymd.substring(6,8)}';
    final uri=Uri.https(_dabomBase,_dabomPath,{
      'searchStartDate':dashed,'searchEndDate':dashed,'searchCondition':_nationwideExcludingJeju,'searchCondition1':'Y','searchCondition2':sex,
    });
    final response=await _client.get(uri,headers:const {'Accept':'text/html','User-Agent':'DonDonHae/1.0'}).timeout(const Duration(seconds:15));
    if(response.statusCode!=200)throw OfficialApiException('KAPE_DABOM','http',response.statusCode);
    final html=utf8.decode(response.bodyBytes,allowMalformed:true);
    final table=RegExp(r'''<table[^>]*id=["']table-type1["'][^>]*>([\s\S]*?)</table>''',caseSensitive:false).firstMatch(html)?.group(1);
    if(table==null)throw const OfficialApiException('KAPE_DABOM','table-missing');
    final rows=<List<String>>[];
    for(final tr in RegExp(r'<tr[^>]*>([\s\S]*?)</tr>',caseSensitive:false).allMatches(table)){
      final cells=RegExp(r'<t[hd][^>]*>([\s\S]*?)</t[hd]>',caseSensitive:false).allMatches(tr.group(1)!).map((m)=>_plainText(m.group(1)!)).toList();
      if(cells.length>1&&cells.first=='등급')cells.removeAt(0);
      if(cells.isNotEmpty)rows.add(cells);
    }
    final actualDate=RegExp(r'''name=["']searchStartDate["'][^>]*value=["'](\d{4})-(\d{2})-(\d{2})["']''',caseSensitive:false).firstMatch(html);
    final date=actualDate==null?ymd:'${actualDate.group(1)}${actualDate.group(2)}${actualDate.group(3)}';
    if(!rows.any((r)=>r.isNotEmpty&&r.first=='평균'))throw const OfficialApiException('KAPE_DABOM','empty-result');
    return _DabomTable(date,rows);
  }

  List<KapeGradePrice> _gradeRows(_DabomTable table){
    final out=<KapeGradePrice>[];
    for(final grade in const ['1+','1','2','등외']){
      final matches=table.rows.where((r)=>r.isNotEmpty&&r.first==grade);
      if(matches.isEmpty)continue;final row=matches.first;
      final price=_integer(row,2),count=_integer(row,1);
      if(price>0&&count>0)out.add(KapeGradePrice(grade:grade,price:price,count:count,date:table.date));
    }
    return out;
  }
  List<String> _summaryRow(_DabomTable table)=>table.rows.firstWhere((r)=>r.isNotEmpty&&r.first=='평균',orElse:()=>const []);
  int _integer(List<String> row,int index)=>row.length>index?double.tryParse(row[index].replaceAll(',',''))?.round()??0:0;
  double? _decimal(List<String> row,int index)=>row.length>index?double.tryParse(row[index].replaceAll(',','')):null;
  String _plainText(String html)=>html.replaceAll(RegExp(r'<br\s*/?>',caseSensitive:false),' ').replaceAll(RegExp(r'<[^>]+>'),'').replaceAll('&nbsp;',' ').replaceAll('&amp;','&').trim();

}

class _DabomTable{const _DabomTable(this.date,this.rows);final String date;final List<List<String>> rows;}
