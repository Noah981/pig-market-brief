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

class KapeApiClient {
  KapeApiClient({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(), _apiKey = apiKey ?? ApiConfig.kapeApiKey;
  final http.Client _client;
  final String _apiKey;
  static const _base = 'data.ekape.or.kr';

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
      final xml = response.body;
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
    if(_apiKey.isEmpty)throw const OfficialApiException('KAPE','missing-key');
    final uri=Uri.http(_base,'/openapi-data/service/user/grade/auct/pigGrade',{
      'serviceKey':Uri.decodeComponent(_apiKey),'startYmd':ymd,'endYmd':ymd,'skinYn':'Y','egradeExceptYn':'N',
    });
    final response=await _client.get(uri).timeout(const Duration(seconds:12));
    if(response.statusCode!=200)throw OfficialApiException('KAPE','http',response.statusCode);
    final code=RegExp(r'<resultCode>(.*?)</resultCode>').firstMatch(response.body)?.group(1)?.trim();
    if(code!=null&&code!='00')throw const OfficialApiException('KAPE','service-error');
    final totals=<String,(double,int)>{};
    for(final match in RegExp(r'<item>([\s\S]*?)</item>').allMatches(response.body)){
      final body=match.group(1)!;final fields=<String,String>{};
      for(final f in RegExp(r'<([^/>]+)>(.*?)</\1>').allMatches(body)){fields[f.group(1)!.toLowerCase()]=f.group(2)!.trim();}
      String pick(Iterable<String> names){for(final entry in fields.entries){if(names.any((x)=>entry.key.contains(x))&&entry.value.isNotEmpty)return entry.value;}return '';}
      final grade=_normalizeGrade(pick(const ['gradenm','grade_nm','judgradenm','grade']));
      final price=double.tryParse(pick(const ['totamt','avgprc','avgprice','auctionprice']).replaceAll(',',''));
      final count=double.tryParse(pick(const ['totcnt','count','headcnt']).replaceAll(',',''))?.round()??0;
      if(grade==null||price==null||price<=0)continue;
      final weight=count>0?count:1,old=totals[grade];totals[grade]=(old==null?(price*weight,weight):(old.$1+price*weight,old.$2+weight));
    }
    return ['1+','1','2','등외'].where(totals.containsKey).map((grade){final x=totals[grade]!;return KapeGradePrice(grade:grade,price:(x.$1/x.$2).round(),count:x.$2,date:ymd);}).toList();
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

  String? _normalizeGrade(String raw){final x=raw.replaceAll('등급','').trim().toUpperCase();if(x=='1+'||x.contains('1PLUS'))return '1+';if(x=='1')return '1';if(x=='2')return '2';if(x.contains('등외')||x=='E')return '등외';return null;}
}
