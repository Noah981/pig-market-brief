"""Official upstream observations; no credentials or prices are embedded."""
import csv
import io
import json
import os
import re
import urllib.parse
import urllib.request
from datetime import datetime, timedelta

from scripts.fetch_fred_markets import KST, parse_series

WORLD_BANK = 'https://www.worldbank.org/en/research/commodity-markets'
EIA = 'https://www.eia.gov/dnav/pet/hist_xls/RWTCd.xls'

def download(url):
    request = urllib.request.Request(url, headers={'User-Agent': 'Dondonhae/1.8'})
    with urllib.request.urlopen(request, timeout=35) as response:
        raw = response.read(5_000_001)
    if len(raw) > 5_000_000:
        raise ValueError('Official document exceeds size limit')
    return raw

def quote(name, rows, source, basis, frequency, unit, url):
    buffer = io.StringIO()
    writer = csv.writer(buffer)
    writer.writerow(['observation_date', name])
    writer.writerows(rows)
    result = parse_series(name, dict(id=name, source=source, basis=basis,
        frequency=frequency, unit=unit), buffer.getvalue().encode())
    result['url'] = url
    return result

def world_bank(raw):
    import openpyxl
    workbook = openpyxl.load_workbook(io.BytesIO(raw), read_only=True, data_only=True)
    rows = list(workbook['Monthly Prices'].values)
    header = next(i for i, row in enumerate(rows) if 'Maize' in row and 'Soybean meal' in row)
    labels = list(rows[header])
    result = []
    for name, column, basis in [('corn', 'Maize', '옥수수'),
            ('soybean_meal', 'Soybean meal', '대두박'),
            ('soybean', 'Soybeans', '대두'), ('wheat', 'Wheat, US HRW', '소맥 US HRW')]:
        index = labels.index(column)
        if rows[header + 1][index] != '($/mt)':
            raise ValueError('World Bank unit changed: ' + column)
        observations = []
        for row in rows[header + 2:]:
            match = re.fullmatch(r'(\d{4})M(\d{2})', str(row[0]))
            if match:
                observations.append((f'{match[1]}-{match[2]}-01', row[index]))
        result.append(quote(name, observations, '세계은행 World Bank Pink Sheet',
            f'{basis} 공식 벤치마크 월평균', 'monthly', '$/톤', WORLD_BANK))
    workbook.close()
    return result

def fetch_world_bank():
    page = download(WORLD_BANK).decode('utf-8')
    links = re.findall(r'https://thedocs\.worldbank\.org/[^\s"<>]+/CMO-Historical-Data-Monthly\.xlsx', page)
    if not links:
        raise ValueError('Current official monthly workbook link missing')
    return world_bank(download(links[0]))

def eia(raw):
    import xlrd
    book = xlrd.open_workbook(file_contents=raw)
    sheet = book.sheet_by_name('Data 1')
    if sheet.cell_value(1, 1) != 'RWTC' or 'Dollars per Barrel' not in sheet.cell_value(2, 1):
        raise ValueError('EIA series or unit mismatch')
    rows = []
    for index in range(3, sheet.nrows):
        if sheet.cell_type(index, 0) == xlrd.XL_CELL_DATE:
            observed = xlrd.xldate_as_datetime(sheet.cell_value(index, 0), book.datemode)
            rows.append((observed.date().isoformat(), sheet.cell_value(index, 1)))
    return quote('wti', rows, '미국 에너지정보청 EIA',
        'WTI Cushing 현물가격', 'daily', '$/bbl', 'https://www.eia.gov/dnav/pet/hist/RWTCD.htm')

def fetch_ecos():
    key = os.getenv('ECOS_API_KEY', '').strip()
    if not key:
        raise ValueError('ECOS credential unavailable')
    today = datetime.now(KST).date()
    start = (today - timedelta(days=90)).strftime('%Y%m%d')
    end = today.strftime('%Y%m%d')
    url = f'https://ecos.bok.or.kr/api/StatisticSearch/{urllib.parse.quote(key, safe="")}/json/kr/1/100/731Y001/D/{start}/{end}/0000001'
    try:
        document = json.loads(download(url))
        data = document['StatisticSearch']['row']
        rows = [(datetime.strptime(row['TIME'], '%Y%m%d').date().isoformat(), row['DATA_VALUE']) for row in data]
        return quote('usd_krw', rows, '한국은행 ECOS', '원/미국달러 매매기준율',
            'daily', '원/USD', 'https://ecos.bok.or.kr/')
    except Exception:
        raise ValueError('ECOS official observation request failed') from None

def fetch_all():
    from concurrent.futures import ThreadPoolExecutor, as_completed
    fetched = []
    with ThreadPoolExecutor(max_workers=3) as pool:
        futures = {pool.submit(task): name for name, task in [
            ('world-bank', fetch_world_bank), ('eia', lambda: eia(download(EIA))), ('ecos', fetch_ecos)]}
        for future in as_completed(futures):
            try:
                value = future.result()
                fetched.extend(value if isinstance(value, list) else [value])
            except Exception:
                print(f'{futures[future]}: official upstream retrieval failed')
    return fetched
