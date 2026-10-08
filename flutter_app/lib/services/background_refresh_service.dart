import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'data_refresh_service.dart';
import 'notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

const officialDataRefreshTask='dondonhae.officialDataRefresh';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher(){
  Workmanager().executeTask((task,inputData)async{
    WidgetsFlutterBinding.ensureInitialized();
    final prefs=await SharedPreferences.getInstance();
    await prefs.reload();
    try{
      await NotificationService.instance.initialize();
      final success=await DataRefreshService.refreshAll(force:true);
      if(success)await prefs.setString('background_refresh_success_at',DateTime.now().toIso8601String());
      return success;
    }catch(error){
      await prefs.setString('background_refresh_error_type',error.runtimeType.toString());
      return false;
    }
  });
}

Future<void> initializeBackgroundRefresh()async{
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask('official-data-refresh-v1',officialDataRefreshTask,
    frequency:const Duration(minutes:15),existingWorkPolicy:ExistingWorkPolicy.keep,
    constraints:Constraints(networkType:NetworkType.connected));
}
