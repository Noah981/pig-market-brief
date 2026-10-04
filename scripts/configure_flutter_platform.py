"""Apply platform permissions after `flutter create` in CI."""
from pathlib import Path
import shutil
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

# Android Launcher widgets are kept as source templates because CI creates the
# Flutter platform folders from scratch for every verified release build.
widget_template=root/"android_widget"
android_main=root/"android/app/src/main"
if widget_template.exists():
    shutil.copytree(widget_template,android_main,dirs_exist_ok=True)
drawable=android_main/"res/drawable"
drawable.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/"assets/images/dondonhae_symbol.png",drawable/"widget_pig.png")

# Share the reference card artwork and Korean font with the native renderer.
widget_assets=android_main/"assets/widget"
widget_assets.mkdir(parents=True,exist_ok=True)
shutil.copy2(root/"assets/images/widget/price_card_art.png",widget_assets/"price_card_art.png")
shutil.copy2(root/"assets/fonts/NotoSansKR.ttf",widget_assets/"NotoSansKR.ttf")
shutil.copy2(root/"assets/images/widget/price_card_reference.png",widget_assets/"price_card_reference.jpg")
shutil.copy2(root/"assets/images/widget/price_card_reference.png",drawable/"widget_price_preview.jpg")
if (root/"android_widget_test").exists():
    shutil.copytree(root/"android_widget_test",root/"android/app/src/test",dirs_exist_ok=True)
gtext=gradle.read_text(encoding="utf-8")
if "org.robolectric:robolectric" not in gtext:
    gtext += '\nandroid { testOptions { unitTests { includeAndroidResources = true } } }\ndependencies { testImplementation "junit:junit:4.13.2"; testImplementation "org.robolectric:robolectric:4.14.1" }\n'
    gradle.write_text(gtext,encoding="utf-8")

# Register all five real AppWidget providers and widget deep links.
text=manifest.read_text(encoding="utf-8")
providers="""
        <receiver android:name=".PigPriceSmallWidget" android:exported="false">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_price_small_info" />
        </receiver>
        <receiver android:name=".PigPriceDetailWidget" android:exported="false">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_price_detail_info" />
        </receiver>
        <receiver android:name=".PigGradeWidget" android:exported="false">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_grade_info" />
        </receiver>
        <receiver android:name=".WeatherTodoWidget" android:exported="false">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_weather_todo_info" />
        </receiver>
        <receiver android:name=".TodayOverviewWidget" android:exported="false">
            <intent-filter><action android:name="android.appwidget.action.APPWIDGET_UPDATE" /></intent-filter>
            <meta-data android:name="android.appwidget.provider" android:resource="@xml/widget_today_info" />
        </receiver>
"""
if 'PigPriceSmallWidget' not in text:
    text=text.replace('</application>',providers+'\n    </application>')
if 'android:scheme="dondonhae"' not in text:
    deep_link='''
            <intent-filter>
                <action android:name="android.intent.action.VIEW" />
                <category android:name="android.intent.category.DEFAULT" />
                <category android:name="android.intent.category.BROWSABLE" />
                <data android:scheme="dondonhae" />
            </intent-filter>
'''
    text=text.replace('</activity>',deep_link+'        </activity>',1)
manifest.write_text(text,encoding="utf-8")

plist=root/"ios/Runner/Info.plist"
with plist.open("rb") as file:data=plistlib.load(file)
data["NSLocationWhenInUseUsageDescription"]="주변 가축질병 발생지역과의 거리를 기기에서 계산하기 위해 사용합니다. 위치정보는 서버에 저장하지 않습니다."
with plist.open("wb") as file:plistlib.dump(data,file)
