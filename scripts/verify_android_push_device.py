"""Deliver isolated QA notifications to this ephemeral emulator only."""
import json, os, subprocess, time, uuid
from pathlib import Path
import xml.etree.ElementTree as ET
from send_official_push import fcm_sender
PKG='com.example.dondonhae'
OUT=Path('qa-output'); OUT.mkdir(exist_ok=True)
def adb(*args,check=True):
 return subprocess.run(['adb',*args],capture_output=True,check=check).stdout.decode(errors='replace')
def wait_for(fn,seconds=180):
 deadline=time.monotonic()+seconds
 while time.monotonic()<deadline:
  value=fn()
  if value:return value
  time.sleep(3)
 raise RuntimeError('Device verification timed out')
root_result=adb('root'); print('ADB root:',root_result.strip()); adb('wait-for-device')
apks=list(Path('qa-apk').rglob('app-release.apk'))
assert len(apks)==1,'Expected the validated release APK'
adb('install','-r',str(apks[0]))
if int(adb('shell','getprop','ro.build.version.sdk').strip())>=33:
 adb('shell','pm','grant',PKG,'android.permission.POST_NOTIFICATIONS')
adb('shell','am','broadcast','-a','android.server.checkin.CHECKIN_NOW',check=False)
adb('shell','am','start','-n',PKG+'/.MainActivity')
def registration():
 raw=adb('shell','cat',f'/data/data/{PKG}/shared_prefs/com.google.android.gms.appid.xml',check=False)
 try:
  for item in ET.fromstring(raw):
   if '|T|' in item.attrib.get('name',''):
    token=json.loads(item.text or '{}').get('token')
    if token:return token
 except (ET.ParseError,ValueError):pass
 return None
try:
 token=wait_for(registration,300)
except RuntimeError:
 print('Preference filenames:',adb('shell','ls',f'/data/data/{PKG}/shared_prefs',check=False).strip())
 raw=adb('shell','cat',f'/data/data/{PKG}/shared_prefs/com.google.android.gms.appid.xml',check=False)
 try: print('Registration preference keys:',[x.attrib.get('name') for x in ET.fromstring(raw)])
 except ET.ParseError: print('Registration preference file unavailable')
 raw=adb('shell','cat',f'/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml',check=False)
 try:
  print('Push initialization state:',{x.attrib.get('name'):x.text or x.attrib.get('value') for x in ET.fromstring(raw) if x.attrib.get('name','').startswith('flutter.server_push_')})
 except ET.ParseError:pass
 logs=adb('logcat','-d','-s','FirebaseMessaging','Firebase-Installations','FirebaseApp','AndroidRuntime','flutter',check=False)
 import re
 logs=re.sub(r'[A-Za-z0-9_:\-]{100,}','[redacted]',logs)
 print('Firebase diagnostics:',logs[-6000:])
 with (OUT/'registration-failure.png').open('wb') as f:subprocess.run(['adb','exec-out','screencap','-p'],stdout=f,check=True)
 raise
print('::add-mask::'+token,flush=True)
send=fcm_sender(); results=[]
for kind,channel,screen_off in [('market','market_price',False),('disease','disease_nationwide_v2',True)]:
 adb('shell','input','keyevent','3');time.sleep(3)
 adb('shell','am','kill',PKG)
 pids=adb('shell','pidof',PKG,check=False).strip().split()
 for pid in pids:
  if pid.isdigit():adb('shell','kill','-9',pid,check=False)
 assert not adb('shell','pidof',PKG,check=False).strip(),'Application must be terminated before delivery'
 if screen_off:
  adb('shell','input','keyevent','223')
  wait_for(lambda:'mWakefulness=Asleep' in adb('shell','dumpsys','power'),30)
 tag='qa-'+uuid.uuid4().hex
 send({'token':token,'notification':{'title':'돈돈해 알림 수신 검증','body':'테스트 메시지 · 실제 발생 정보 아님'},'data':{'kind':kind,'eventId':tag,'stableKey':tag,'countryCode':'KR','confirmed':'true'},'android':{'priority':'HIGH','ttl':'300s','notification':{'channel_id':channel,'tag':tag,'sound':'default'}}})
 wait_for(lambda:any(PKG in line and tag in line and 'NotificationRecord' in line for line in adb('shell','dumpsys','notification','--noredact').splitlines()),120)
 results.append({'kind':kind,'appTerminatedBeforeSend':True,'screenOff':screen_off,'notificationPosted':True,'channel':channel})
 print(kind+' terminated-app notification posted',flush=True)
 if screen_off:adb('shell','input','keyevent','224')
 adb('shell','cmd','statusbar','expand-notifications');time.sleep(2)
 with (OUT/(kind+'.png')).open('wb') as f:subprocess.run(['adb','exec-out','screencap','-p'],stdout=f,check=True)
 adb('shell','cmd','statusbar','collapse')
(OUT/'push-device-results.json').write_text(json.dumps({'results':results},indent=2))
