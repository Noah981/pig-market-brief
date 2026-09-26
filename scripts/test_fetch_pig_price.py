import unittest

from scripts.fetch_pig_price import parse_headline


class DabomHeadlineTest(unittest.TestCase):
    def test_exact_official_pig_card_is_parsed(self):
        html = '''
        <div class="main-menu-wrap"><h3><img alt="돼지">돼지</h3>
        <div>경락가격</div><a data-card="auctPig">
        <b>전국(등외,제주 제외)</b><em class="data-blue">5,307</em></a>
        <div class="main-menu-bottom"><div><b>26년 09월 23일</b></div></div>
        </div>'''
        self.assertEqual(parse_headline(html), ("20260923", 5307))

    def test_unrelated_raw_value_is_rejected(self):
        html = '<div>pigGrade raw weighted price 4,348</div>'
        with self.assertRaises(RuntimeError):
            parse_headline(html)


if __name__ == "__main__":
    unittest.main()
