import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dondonhae/settings/display_settings.dart';
import 'package:dondonhae/services/data_refresh_service.dart';

void main(){
  TestWidgetsFlutterBinding.ensureInitialized();
  test('old settings migrate to readable normal mode and extra large persists',()async{
    SharedPreferences.setMockInitialValues({'display_text_scale':1.08,'display_large_text_mode':true});
    final settings=DisplaySettings.instance;await settings.load();
    expect(settings.largeTextMode,false);expect(settings.textScale,1.15);
    await settings.setLargeTextMode(true);expect(settings.textScale,1.45);
    await settings.load();expect(settings.largeTextMode,true);expect(settings.textScale,1.45);
    await settings.setLargeTextMode(false);expect(settings.textScale,1.15);
  });
  test('Korean midnight bypasses throttle without fabricating new quotes',(){
    final before=DateTime.parse('2026-10-05T23:59:00+09:00');
    expect(DataRefreshService.shouldRefresh(before,DateTime.parse('2026-10-06T00:00:00+09:00')),true);
    expect(DataRefreshService.shouldRefresh(before,before.add(const Duration(minutes:1))),true);
    final noon=DateTime.parse('2026-10-05T12:00:00+09:00');
    expect(DataRefreshService.shouldRefresh(noon,noon.add(const Duration(minutes:4))),false);
    expect(DataRefreshService.shouldRefresh(noon,noon.add(const Duration(minutes:5))),true);
    expect(DataRefreshService.shouldRefresh(noon,noon.subtract(const Duration(minutes:1))),true);
  });
}
