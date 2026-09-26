import 'dart:math' as math;
import '../models/disease_models.dart';

class DiseaseRiskSummary {
  const DiseaseRiskSummary({required this.level,required this.count10,required this.count30,required this.count50,this.nearestKm});
  final DiseaseRiskLevel level;final int count10,count30,count50;final double? nearestKm;
}

class DiseaseRiskEngine {
  static double distanceKm(double lat1,double lon1,double lat2,double lon2){
    const r=6371.0088;double rad(double v)=>v*math.pi/180;
    final dLat=rad(lat2-lat1),dLon=rad(lon2-lon1);
    final a=math.sin(dLat/2)*math.sin(dLat/2)+math.cos(rad(lat1))*math.cos(rad(lat2))*math.sin(dLon/2)*math.sin(dLon/2);
    return r*2*math.atan2(math.sqrt(a),math.sqrt(1-a));
  }
  static DiseaseRiskLevel levelFor(double km)=>km<=10?DiseaseRiskLevel.level1:km<=30?DiseaseRiskLevel.level2:km<=50?DiseaseRiskLevel.level3:DiseaseRiskLevel.safe;
  static DiseaseRiskSummary summarize(Iterable<DiseaseAlert> events,{required double? latitude,required double? longitude,DiseaseType? type}){
    if(latitude==null||longitude==null)return const DiseaseRiskSummary(level:DiseaseRiskLevel.unknown,count10:0,count30:0,count50:0);
    final distances=events.where((x)=>x.isOfficial&&x.latitude!=null&&x.longitude!=null&&(type==null||x.type==type)).map((x)=>distanceKm(latitude,longitude,x.latitude!,x.longitude!)).toList()..sort();
    if(distances.isEmpty)return const DiseaseRiskSummary(level:DiseaseRiskLevel.safe,count10:0,count30:0,count50:0);
    return DiseaseRiskSummary(level:levelFor(distances.first),nearestKm:distances.first,count10:distances.where((x)=>x<=10).length,count30:distances.where((x)=>x<=30).length,count50:distances.where((x)=>x<=50).length);
  }
}
