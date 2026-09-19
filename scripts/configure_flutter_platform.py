"""Apply platform permissions after `flutter create` in CI."""
from pathlib import Path
import plistlib

root=Path(__file__).resolve().parents[1]/"flutter_app"
manifest=root/"android/app/src/main/AndroidManifest.xml"
text=manifest.read_text(encoding="utf-8")
permission='<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'
if permission not in text:
    text=text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',f'<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    {permission}\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />')
manifest.write_text(text,encoding="utf-8")

plist=root/"ios/Runner/Info.plist"
with plist.open("rb") as file:data=plistlib.load(file)
data["NSLocationWhenInUseUsageDescription"]="주변 가축질병 발생지역과의 거리를 기기에서 계산하기 위해 사용합니다. 위치정보는 서버에 저장하지 않습니다."
with plist.open("wb") as file:plistlib.dump(data,file)
