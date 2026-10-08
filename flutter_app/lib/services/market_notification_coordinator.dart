import 'package:shared_preferences/shared_preferences.dart';
import '../data/market_repository.dart';
import 'notification_service.dart';

class MarketNotificationCoordinator {
  static const _dateKey='market_notification_date_v1';
  static const _priceKey='market_notification_price_v1';

  static Future<bool> process(MarketSnapshot market,{
    Future<void> Function(MarketSnapshot)? notify,
  })async{
    if(market.fromCache)return false;
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    final date=market.date.replaceAll('-','');
    final previousDate=prefs.getString(_dateKey);
    final previousPrice=prefs.getInt(_priceKey);
    if(previousDate!=null&&date.compareTo(previousDate)<0)return false;
    if(date==previousDate&&market.price==previousPrice)return false;
    final changed=previousDate!=null;
    if(changed&&(prefs.getBool('market_notifications_enabled')??true)){
      await (notify??NotificationService.instance.newMarketPrice)(market);
    }
    // Save only after delivery succeeds, so a failed notification is retried.
    await prefs.setString(_dateKey,date);
    await prefs.setInt(_priceKey,market.price);
    return changed;
  }
}
