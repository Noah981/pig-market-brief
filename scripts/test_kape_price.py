import importlib.util
import unittest
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SPEC=importlib.util.spec_from_file_location("fetch_pig_price",ROOT/"scripts/fetch_pig_price.py")
MODULE=importlib.util.module_from_spec(SPEC);SPEC.loader.exec_module(MODULE)


class KapePriceTest(unittest.TestCase):
 def test_parse_official_detail_outgrade_excluded_national_cell(self):
  html='''<table><tr><th>등외제외</th><td data-col="all-area">6,442<br>(1,161)</td><td>7,016</td></tr></table>'''
  self.assertEqual(MODULE.parse_excluding_outgrade_price(html),6442)

 def test_empty_market_day_is_not_zero(self):
  html='''<table><tr><th>등외제외</th><td data-col="all-area">-</td></tr></table>'''
  self.assertIsNone(MODULE.parse_excluding_outgrade_price(html))

 def test_parse_official_producer_headline(self):
  html='''<a data-card="allPig"><b>전국(등외,제주 제외)</b><em>6,442</em><span>원/kg</span></a><div><b>26년 09월 18일</b></div>'''
  self.assertEqual(MODULE.parse_producer_headline(html),{'price':6442,'date':'20260918'})


if __name__=='__main__':unittest.main()
