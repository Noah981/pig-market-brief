import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/commodity_repository.dart';
import '../data/benefit_repository.dart';
import '../data/disease_repository.dart';
import '../data/market_repository.dart';
import '../data/pig_grade_repository.dart';
import '../data/weather_farm_repository.dart';
import '../settings/farm_location_settings.dart';
import 'disease_notification_coordinator.dart';
import 'widget_update_service.dart';

class DataRefreshService {
  DataRefreshService._();
  static final revision=ValueNotifier<int>(0);
  static const _lastCheckKey='official_api_last_check_v1';
  static const minInterval=Duration(minutes:5);

  static bool shouldRefresh(DateTime? last,DateTime now){
    if(last==null)return true;
    final a=last.toUtc().add(const Duration(hours:9)), b=now.toUtc().add(const Duration(hours:9));
    return a.year!=b.year||a.month!=b.month||a.day!=b.day||now.isBefore(last)||now.difference(last)>=minInterval;
  }

  static Future<bool> refreshAll({bool force=false})async{
    final prefs=await SharedPreferences.getInstance();
    final last=DateTime.tryParse(prefs.getString(_lastCheckKey)??'');
    if(!force&&!shouldRefresh(last,DateTime.now())){await WidgetUpdateService.updateAll();return false;}
    await FarmLocationSettings.instance.load();
    await Future.wait<void>([
      _isolated(()async{final market=await MarketRepository().refresh();await PigGradeRepository().refresh(market.date);}),
      _isolated(()async{await CommodityRepository().refresh();}),
      _isolated(()async{await BenefitRepository().refresh();}),
      _isolated(()async{await WeatherFarmRepository().refresh(region:FarmLocationSettings.instance.location.province);}),
      _isolated(()async{final feed=await DiseaseRepository().refresh();await DiseaseNotificationCoordinator.process(feed);}),
    ]);
    await prefs.setString(_lastCheckKey,DateTime.now().toIso8601String());
    await WidgetUpdateService.updateAll();
    revision.value++;
    return true;
  }

  /// Disease signals are checked independently so reopening the app is not
  /// blocked by the slower common-data refresh throttle.
  static Future<int> refreshDisease()async{
    try{
      final feed=await DiseaseRepository().refresh();
      return DiseaseNotificationCoordinator.process(feed);
    }catch(_){return 0;}
  }

  static Future<void> _isolated(Future<void> Function() action)async{try{await action();}catch(_){}}
}
