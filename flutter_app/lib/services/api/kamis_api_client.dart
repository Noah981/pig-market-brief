import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../config/api_config.dart';
import 'api_exception.dart';

class KamisApiClient {
  KamisApiClient({http.Client? client,String? apiKey,String? certId})
      :_client=client??http.Client(),_apiKey=apiKey??ApiConfig.kamisApiKey,_certId=certId??ApiConfig.kamisCertId;
  final http.Client _client;final String _apiKey,_certId;
  static const _cacheKey='kamis_last_official_response_v1';

  Future<Map<String,dynamic>> fetchLatest()async{
    if(_apiKey.isEmpty||_certId.isEmpty)throw const OfficialApiException('KAMIS','missing-key');
    final now=DateTime.now().toUtc().add(const Duration(hours:9));
    String ymd(DateTime x)=>'${x.year.toString().padLeft(4,'0')}-${x.month.toString().padLeft(2,'0')}-${x.day.toString().padLeft(2,'0')}';
    final uri=Uri.https('www.kamis.or.kr','/service/price/xml.do',{
      'action':'periodProductList','p_cert_key':_apiKey,'p_cert_id':_certId,'p_returntype':'json',
      'p_startday':ymd(now.subtract(const Duration(days:14))),'p_endday':ymd(now),
      'p_productclscode':'01','p_itemcategorycode':'100','p_productrankcode':'04','p_countrycode':'1101','p_convert_kg_yn':'N',
    });
    final response=await _client.get(uri).timeout(const Duration(seconds:15));
    if(response.statusCode!=200)throw OfficialApiException('KAMIS','http',response.statusCode);
    final decoded=jsonDecode(utf8.decode(response.bodyBytes));
    if(decoded is! Map<String,dynamic>)throw const OfficialApiException('KAMIS','invalid-schema');
    final error=decoded['error_code']?.toString();
    if(error!=null&&error!='000')throw const OfficialApiException('KAMIS','service-error');
    final raw=jsonEncode({'fetchedAt':DateTime.now().toIso8601String(),'source':'KAMIS 농산물유통정보','payload':decoded});
    await (await SharedPreferences.getInstance()).setString(_cacheKey,raw);
    return decoded;
  }
}
