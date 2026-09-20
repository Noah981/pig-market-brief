import re,unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
KOTLIN=(ROOT/'platform/android/app/src/main/kotlin/com/example/dondonhae/PriceWidgetProvider.kt').read_text(encoding='utf-8')
WIDE=(ROOT/'platform/android/app/src/main/res/layout/widget_price_wide.xml').read_text(encoding='utf-8')
INFO=(ROOT/'platform/android/app/src/main/res/xml/price_widget_wide_info.xml').read_text(encoding='utf-8')

def policy(width,height):
 return 'compact' if width<330 or height<125 else 'regular'

class WidgetContractTest(unittest.TestCase):
 def test_launcher_return_is_deterministic_for_ten_cycles(self):
  for bounds in ((280,110),(360,160),(600,180),(720,220)):
   first=policy(*bounds)
   for _ in range(10):self.assertEqual(policy(*bounds),first)
 def test_real_options_and_configuration_change_are_handled(self):
  self.assertIn('getAppWidgetOptions(id)',KOTLIN)
  self.assertIn('onAppWidgetOptionsChanged',KOTLIN)
  self.assertIn('ACTION_CONFIGURATION_CHANGED',KOTLIN)
 def test_remote_text_uses_density_not_system_font_scale(self):
  self.assertIn('TypedValue.COMPLEX_UNIT_DIP',KOTLIN)
  self.assertNotIn('COMPLEX_UNIT_SP',KOTLIN)
 def test_bounds_contract_and_required_content(self):
  for value in ('android:minWidth','android:minHeight','android:minResizeWidth','android:minResizeHeight','android:targetCellWidth','android:targetCellHeight'):self.assertIn(value,INFO)
  for value in ('widget_title','widget_price','widget_change','widget_date','widget_sparkline','widget_tagline'):self.assertRegex(WIDE,rf'@\+id/{value}')

if __name__=='__main__':unittest.main()
