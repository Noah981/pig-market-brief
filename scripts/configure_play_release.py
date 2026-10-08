"""Upgrade only generated Android build files for the verified Play bundle."""
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'flutter_app/android'
settings=ROOT/'settings.gradle'
text=settings.read_text()
text=re.sub(r'(id\s+"com.android.application"\s+version\s+")[^"]+',r'\g<1>8.10.1',text)
settings.write_text(text)
wrapper=ROOT/'gradle/wrapper/gradle-wrapper.properties'
text=re.sub(r'gradle-[\d.]+-all.zip','gradle-8.11.1-all.zip',wrapper.read_text())
wrapper.write_text(text)
app=ROOT/'app/build.gradle';text=app.read_text()
text=re.sub(r'compileSdk\s*(?:=\s*)?flutter.compileSdkVersion','compileSdk = 36',text)
text=re.sub(r'targetSdk\s*(?:=\s*)?flutter.targetSdkVersion','targetSdk = 36',text)
if 'compileSdk = 36' not in text or 'targetSdk = 36' not in text:raise ValueError('Unexpected generated Android SDK configuration')
app.write_text(text)
print('Play target API 36 and modern bundle packaging configured')
