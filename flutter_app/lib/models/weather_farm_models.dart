class WeatherFarmGuide {
  const WeatherFarmGuide({required this.region,required this.tempMin,required this.tempMax,required this.humidity,required this.rainProbability,required this.riskFactors,required this.checks,required this.updatedAt,required this.source,this.windSpeed,this.fromCache=false});
  final String region,updatedAt,source;
  final double tempMin,tempMax,humidity,rainProbability;
  final double? windSpeed;
  final List<String> riskFactors,checks;
  final bool fromCache;

  bool get hasForecast=>[tempMin,tempMax,humidity,rainProbability].every((x)=>x.isFinite);
  static String number(double value,{int digits=0})=>value.isFinite?value.toStringAsFixed(digits):'—';
  double get diurnalRange=>tempMax-tempMin;
  String get condition=>!hasForecast?'정보 없음':rainProbability>=60?'비 가능성':tempMax>=30?'더움':'지역 예보';
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
