import 'package:flutter/widgets.dart';
import 'package:workmanager/workmanager.dart';
import 'data_refresh_service.dart';

const officialDataRefreshTask='dondonhae.officialDataRefresh';

@pragma('vm:entry-point')
void backgroundCallbackDispatcher(){
  Workmanager().executeTask((task,inputData)async{
    WidgetsFlutterBinding.ensureInitialized();
    await DataRefreshService.refreshAll(force:true);
    return true;
  });
}

Future<void> initializeBackgroundRefresh()async{
  await Workmanager().initialize(backgroundCallbackDispatcher);
  await Workmanager().registerPeriodicTask('official-data-refresh-v1',officialDataRefreshTask,
    frequency:const Duration(hours:6),existingWorkPolicy:ExistingWorkPolicy.keep,
    constraints:Constraints(networkType:NetworkType.connected));
}
