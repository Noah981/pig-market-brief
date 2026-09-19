class DiseaseAlert {
  const DiseaseAlert({required this.disease,required this.source,required this.countryCode,required this.scope,required this.evidenceLevel,required this.level,required this.summary,required this.sourceUrl,required this.publishedAt,this.region,this.latitude,this.longitude});
  final String disease,source,countryCode,scope,evidenceLevel,level,summary,sourceUrl,publishedAt;
  final String? region;
  final double? latitude,longitude;
  bool get isOfficial=>evidenceLevel=='OFFICIAL';
  bool get hasMapPoint=>scope=='국내'&&latitude!=null&&longitude!=null;
}

class DiseaseFeed {
  const DiseaseFeed({required this.items,required this.updatedAt,required this.fromCache});
  final List<DiseaseAlert> items;
  final String updatedAt;
  final bool fromCache;
}
