import 'package:shared_preferences/shared_preferences.dart';
import '../data/commodity_repository.dart';
import '../data/disease_repository.dart';
import '../data/market_repository.dart';
import '../data/weather_farm_repository.dart';
import '../settings/farm_location_settings.dart';
import 'disease_notification_coordinator.dart';

class DataRefreshService {
  DataRefreshService._();
  static const _lastCheckKey='official_api_last_check_v1';
  static const minInterval=Duration(minutes:30);

  static Future<bool> refreshAll({bool force=false})async{
    final prefs=await SharedPreferences.getInstance();
    final last=DateTime.tryParse(prefs.getString(_lastCheckKey)??'');
    if(!force&&last!=null&&DateTime.now().difference(last)<minInterval)return false;
    await FarmLocationSettings.instance.load();
    await Future.wait<void>([
      _isolated(()async{await MarketRepository().refresh();}),
      _isolated(()async{await CommodityRepository().refresh();}),
      _isolated(()async{await WeatherFarmRepository().refresh(region:FarmLocationSettings.instance.location.province);}),
      _isolated(()async{final feed=await DiseaseRepository().refresh();await DiseaseNotificationCoordinator.process(feed);}),
    ]);
    await prefs.setString(_lastCheckKey,DateTime.now().toIso8601String());
    return true;
  }

  static Future<void> _isolated(Future<void> Function() action)async{try{await action();}catch(_){}}
}
