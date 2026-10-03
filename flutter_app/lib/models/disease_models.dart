enum DiseaseType { asf, fmd, ped, prrs }

extension DiseaseTypeLabel on DiseaseType {
  String get label => switch (this) { DiseaseType.asf => 'ASF', DiseaseType.fmd => '구제역', DiseaseType.ped => 'PED', DiseaseType.prrs => 'PRRS' };
  String get legalGroup=>switch(this){DiseaseType.asf||DiseaseType.fmd=>'제1종',DiseaseType.ped||DiseaseType.prrs=>'제3종'};
}

DiseaseType? normalizeDiseaseType(String value) {
  final text=value.trim().toUpperCase().replaceAll(RegExp(r'[\s\-]'),'');
  if(text.contains('아프리카돼지열병')||text.contains('AFRICANSWINEFEVER')||text=='ASF')return DiseaseType.asf;
  if(text.contains('구제역')||text.contains('FOOTANDMOUTH')||text=='FMD')return DiseaseType.fmd;
  if(text.contains('돼지유행성설사')||text.contains('PORCINEEPIDEMICDIARRHEA')||text=='PED')return DiseaseType.ped;
  if(text.contains('돼지생식기호흡기증후군')||text.contains('PORCINEREPRODUCTIVEANDRESPIRATORY')||text=='PRRS')return DiseaseType.prrs;
  return null;
}

enum DiseaseEvidence { official, publicInfo }
enum DiseaseDataState { live, stale, noNewData, error, reviewRequired }
enum DiseaseRiskLevel { level1, level2, level3, safe, unknown }

class DiseaseAlert {
  const DiseaseAlert({this.id='',required this.type,required this.source,required this.countryCode,required this.evidence,required this.status,required this.summary,required this.sourceUrl,required this.occurrenceDate,this.announcementDate='',this.updatedAt='',this.livestockType='',this.districtCode='',this.province='',this.cityCounty='',this.town='',this.latitude,this.longitude});
  final String id,source,countryCode,status,summary,sourceUrl,occurrenceDate,announcementDate,updatedAt,livestockType,districtCode,province,cityCounty,town;
  final DiseaseType type;final DiseaseEvidence evidence;final double? latitude,longitude;
  String get disease=>type.label;
  String get scope=>countryCode=='KR'?'국내':'국외';
  bool get isOfficial=>evidence==DiseaseEvidence.official;
  bool get isSuspected=>status.contains('의심')||status.contains('확인 중');
  bool get isNegative=>status.contains('음성')||status.contains('해제')||status.contains('불검출');
  bool get isConfirmed=>isOfficial&&!isSuspected&&!isNegative;
  bool get hasMapPoint=>countryCode=='KR'&&latitude!=null&&longitude!=null;
  String get region=>[province,cityCounty,town].where((x)=>x.isNotEmpty).join(' ');
  String get stableKey=>id.isNotEmpty?id:'${type.name}|$occurrenceDate|$countryCode|$province|$cityCounty|$town|$summary';
  String get incidentKey=>id.isNotEmpty?'${type.name}|$countryCode|$id':'${type.name}|$countryCode|$occurrenceDate|$province|$cityCounty|$town';
  DateTime? get eventDate{
    final declared=_parseDate(occurrenceDate);
    if(declared==null)return null;
    // Also protect already cached feeds that used the article publication
    // date: an explicit date/month in the headline is stronger evidence.
    return _dateMention(summary,declared)??declared;
  }
  bool isRecentAt(DateTime now){final d=eventDate;if(d==null)return false;final today=DateTime(now.year,now.month,now.day),day=DateTime(d.year,d.month,d.day);return !day.isAfter(today)&&!day.isBefore(today.subtract(const Duration(days:30)));}
  bool isActiveAt(DateTime now)=>!isNegative&&isRecentAt(now);
}

DateTime? _dateMention(String text,DateTime reference){
  final full=RegExp(r'((?:19|20)\d{2})\s*[년./-]\s*(\d{1,2})\s*[월./-]\s*(\d{1,2})\s*일?').firstMatch(text);
  if(full!=null)return _safeDate(int.parse(full.group(1)!),int.parse(full.group(2)!),int.parse(full.group(3)!));
  final monthDay=RegExp(r'(\d{1,2})\s*월\s*(\d{1,2})\s*일').firstMatch(text);
  final monthOnly=RegExp(r'(?:지난|올해|금년)?\s*(\d{1,2})\s*월(?:\s*(?:발생|확진|의심|사례|건))').firstMatch(text);
  final match=monthDay??monthOnly;if(match==null)return null;
  final month=int.parse(match.group(1)!),day=monthDay==null?1:int.parse(match.group(2)!);
  var result=_safeDate(reference.year,month,day);if(result==null)return null;
  if(result.isAfter(reference.add(const Duration(days:31))))result=_safeDate(reference.year-1,month,day)!;
  return result;
}
DateTime? _safeDate(int year,int month,int day){try{final value=DateTime(year,month,day);return value.year==year&&value.month==month&&value.day==day?value:null;}catch(_){return null;}}

DateTime? _parseDate(String value){
  final iso=DateTime.tryParse(value);if(iso!=null)return iso;
  final digits=value.replaceAll(RegExp(r'[^0-9]'),'');
  if(RegExp(r'^(?:19|20)\d{6}').hasMatch(digits))return DateTime.tryParse('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}');
  final rfc=RegExp(r'\b(\d{1,2})\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\s+(\d{4})\b',caseSensitive:false).firstMatch(value);
  if(rfc==null)return null;
  const months={'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
  return DateTime(int.parse(rfc.group(3)!),months[rfc.group(2)!.toLowerCase()]!,int.parse(rfc.group(1)!));
}

class DiseaseFeed {
  const DiseaseFeed({required this.items,required this.updatedAt,required this.fromCache,this.state=DiseaseDataState.live,this.errorMessage});
  final List<DiseaseAlert> items;final String updatedAt;final bool fromCache;final DiseaseDataState state;final String? errorMessage;
  List<DiseaseAlert> active(DateTime now)=>items.where((x)=>x.isActiveAt(now)).toList(growable:false);
}
