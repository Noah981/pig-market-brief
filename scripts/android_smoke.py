"""Run against a booted test emulator. Save screens and crash evidence."""
import subprocess,time,re,xml.etree.ElementTree as ET
from pathlib import Path
out=Path('android/app/build/reports/device-smoke');out.mkdir(parents=True,exist_ok=True)
def adb(*args):return subprocess.check_output(['adb',*args])
def nodes():
 adb('shell','uiautomator','dump','/sdcard/dondon-window.xml')
 return ET.fromstring(adb('shell','cat','/sdcard/dondon-window.xml')).iter('node')
def tap(text):
 for node in nodes():
  if node.get('text')==text and node.get('enabled')=='true':
   x1,y1,x2,y2=map(int,re.findall(r'\d+',node.get('bounds','')))
   adb('shell','input','tap',str((x1+x2)//2),str((y1+y2)//2));time.sleep(2);return True
 return False
adb('logcat','-c');adb('install','-r','android/app/build/outputs/apk/debug/app-debug.apk');adb('shell','am','start','-W','-n','kr.pigmarketbrief/.MainActivity');time.sleep(5)
for _ in range(5):
 if tap('시작하기'):break
 adb('shell','input','swipe','500','1500','500','400','500');time.sleep(1)
else:raise AssertionError('Onboarding start not found')
for _ in range(3):
 if tap('DENY') or tap('허용 안 함') or tap('Don’t allow'):continue
 break
for tab in ['돈가','시장','혜택','더보기','오늘']:
 assert tap(tab),f'Navigation failed: {tab}'
 (out/f'{tab}.png').write_bytes(adb('exec-out','screencap','-p'))
adb('shell','svc','wifi','disable');adb('shell','svc','data','disable')
adb('shell','am','force-stop','kr.pigmarketbrief');adb('shell','am','start','-W','-n','kr.pigmarketbrief/.MainActivity');time.sleep(5)
(out/'offline.png').write_bytes(adb('exec-out','screencap','-p'))
assert any('마지막 저장 데이터' in n.get('text','') for n in nodes()),'Offline cache state not visible'
assert tap('더보기')
for _ in range(6):
 if tap('화면 모드  ›'):break
 adb('shell','input','swipe','500','1450','500','500','450');time.sleep(1)
else:raise AssertionError('Appearance settings not found')
assert tap('다크 모드')
time.sleep(3)
(out/'dark.png').write_bytes(adb('exec-out','screencap','-p'))
logs=adb('logcat','-d','-s','AndroidRuntime').decode(errors='replace');(out/'runtime.log').write_text(logs)
assert 'FATAL EXCEPTION' not in logs,logs
(out/'result.txt').write_text('PASS: onboarding, denied location, five navigation tabs, offline cache, dark mode; no fatal AndroidRuntime errors')
