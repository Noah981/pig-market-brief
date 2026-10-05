import io
import unittest
from scripts.direct_market_sources import world_bank, quote, eia
from scripts.fetch_fred_markets import update

class DirectSourceTests(unittest.TestCase):
    def workbook(self, unit='($/mt)'):
        import openpyxl
        book = openpyxl.Workbook()
        sheet = book.active
        sheet.title = 'Monthly Prices'
        sheet.append([None, 'Soybeans', 'Maize', 'Wheat, US HRW', 'Soybean meal'])
        sheet.append([None, unit, unit, unit, unit])
        sheet.append(['2026M08', 400, 200, 300, 350])
        sheet.append(['2026M09', 420, 210, 315, 367.5])
        sheet.append(['2099M01', 9999, 9999, 9999, 9999])
        buffer = io.BytesIO()
        book.save(buffer)
        return buffer.getvalue()

    def test_named_columns_dates_units_and_same_source_changes(self):
        rows = world_bank(self.workbook())
        corn = next(x for x in rows if x['name'] == 'corn')
        self.assertEqual((corn['value'], corn['previousValue'], corn['changePct']), (210, 200, 5))
        self.assertEqual(corn['date'], '2026-09-01')
        self.assertEqual(len(corn['history']), 2)
        self.assertIn('World Bank', corn['source'])

    def test_unit_change_blocks_publication(self):
        with self.assertRaises(ValueError):
            world_bank(self.workbook('($/kg)'))

    def test_error_page_is_not_oil_data(self):
        with self.assertRaises(Exception):
            eia(b'<html>Service unavailable</html>')

    def test_provider_switch_never_stitches_old_history(self):
        new = world_bank(self.workbook())
        old = {'markets': [{'name': 'corn', 'source': 'IMF', 'date': '2026-09-01',
            'value': 800, 'history': [{'date': '2026-08-01', 'value': 900}]}]}
        result = update(old, new)
        corn = next(x for x in result['markets'] if x['name'] == 'corn')
        self.assertEqual(corn['history'], new[0]['history'])
        self.assertEqual(corn['previousValue'], 200)

    def test_missing_provider_keeps_cache_marked_stale(self):
        result = update({'markets': [{'name': 'wti', 'value': 90, 'source': 'EIA'}]}, [])
        self.assertEqual(result['markets'][0]['status'], 'STALE')
        self.assertNotEqual(result['sourceStatus'][-1]['status'], '연결 완료')

if __name__ == '__main__':
    unittest.main()
