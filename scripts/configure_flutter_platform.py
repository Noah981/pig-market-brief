"""Apply platform permissions after `flutter create` in CI."""
from pathlib import Path
import plistlib

root=Path(__file__).resolve().parents[1]/"flutter_app"
manifest=root/"android/app/src/main/AndroidManifest.xml"
text=manifest.read_text(encoding="utf-8")
internet='<uses-permission android:name="android.permission.INTERNET" />'
if internet not in text:
    text=text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',f'<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    {internet}')
permission='<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />'
if permission not in text:
    text=text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',f'<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    {permission}\n    <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />')
notification='<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />'
if notification not in text:
    text=text.replace('<manifest xmlns:android="http://schemas.android.com/apk/res/android">',f'<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n    {notification}')
if 'android:usesCleartextTraffic="true"' not in text:
    text=text.replace('<application', '<application android:usesCleartextTraffic="true"')
manifest.write_text(text,encoding="utf-8")

gradle=root/"android/app/build.gradle"
gtext=gradle.read_text(encoding="utf-8")
if "coreLibraryDesugaringEnabled true" not in gtext:
    gtext=gtext.replace("android {", "android {\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n        sourceCompatibility JavaVersion.VERSION_1_8\n        targetCompatibility JavaVersion.VERSION_1_8\n    }")
if "desugar_jdk_libs" not in gtext:
    gtext += "\n\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'\n}\n"
gradle.write_text(gtext,encoding="utf-8")

plist=root/"ios/Runner/Info.plist"
with plist.open("rb") as file:data=plistlib.load(file)
data["NSLocationWhenInUseUsageDescription"]="주변 가축질병 발생지역과의 거리를 기기에서 계산하기 위해 사용합니다. 위치정보는 서버에 저장하지 않습니다."
with plist.open("wb") as file:plistlib.dump(data,file)
