enum DiseaseType { asf, fmd, ped, prrs }

extension DiseaseTypeLabel on DiseaseType {
  String get label => switch (this) { DiseaseType.asf => 'ASF', DiseaseType.fmd => '구제역', DiseaseType.ped => 'PED', DiseaseType.prrs => 'PRRS' };
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
  bool get hasMapPoint=>countryCode=='KR'&&latitude!=null&&longitude!=null;
  String get region=>[province,cityCounty,town].where((x)=>x.isNotEmpty).join(' ');
  String get stableKey=>id.isNotEmpty?id:'${type.name}|$occurrenceDate|$countryCode|$province|$cityCounty|$town|$summary';
  DateTime? get eventDate=>_parseDate(occurrenceDate);
  bool isActiveAt(DateTime now){final d=eventDate;if(d==null)return false;final today=DateTime(now.year,now.month,now.day),day=DateTime(d.year,d.month,d.day);return !day.isAfter(today)&&!day.isBefore(today.subtract(const Duration(days:30)));}
}

DateTime? _parseDate(String value){final digits=value.replaceAll(RegExp(r'[^0-9]'),'');if(digits.length>=8)return DateTime.tryParse('${digits.substring(0,4)}-${digits.substring(4,6)}-${digits.substring(6,8)}');return DateTime.tryParse(value);}

class DiseaseFeed {
  const DiseaseFeed({required this.items,required this.updatedAt,required this.fromCache,this.state=DiseaseDataState.live,this.errorMessage});
  final List<DiseaseAlert> items;final String updatedAt;final bool fromCache;final DiseaseDataState state;final String? errorMessage;
  List<DiseaseAlert> active(DateTime now)=>items.where((x)=>x.isActiveAt(now)).toList(growable:false);
}
