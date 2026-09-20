class WeatherFarmGuide {
  const WeatherFarmGuide({required this.region,required this.tempMin,required this.tempMax,required this.humidity,required this.rainProbability,required this.riskFactors,required this.checks,required this.updatedAt,required this.source,this.fromCache=false});
  final String region,updatedAt,source;
  final double tempMin,tempMax,humidity,rainProbability;
  final List<String> riskFactors,checks;
  final bool fromCache;

  double get diurnalRange=>tempMax-tempMin;
  String get condition=>rainProbability>=60?'비 가능성':tempMax>=30?'더움':'맑음';
}

class FarmHealthRisk {
  const FarmHealthRisk(this.title,this.level,this.reason,this.signs);
  final String title,level,reason,signs;
}

class MedicineGuide {
  const MedicineGuide(this.category,this.use,this.caution);
  final String category,use,caution;
}

class SeasonalDiseaseGuide {
  const SeasonalDiseaseGuide(this.name,this.whyNow,this.signs,this.differentiate,this.urgency);
  final String name,whyNow,signs,differentiate,urgency;
}
