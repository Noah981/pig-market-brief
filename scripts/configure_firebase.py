"""Materialize private CI Firebase config; never publish an unconnected final."""
import argparse
import base64
import json
import os
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]/'flutter_app'

def configure(required=False):
    encoded=os.environ.get('DDH_FIREBASE_ANDROID_CONFIG_B64','')
    bundled=ROOT/'firebase/google-services.json'
    if not encoded and bundled.exists():encoded=base64.b64encode(bundled.read_bytes()).decode()
    if not encoded:
        if required:raise RuntimeError('Firebase Android configuration is missing; final release blocked')
        print('Validation environment only: Firebase connection is not configured')
        return False
    raw=base64.b64decode(encoded,validate=True)
    config=json.loads(raw)
    project=config['project_info']['project_id']
    expected=os.environ.get('DDH_FIREBASE_PROJECT_ID') or 'dondonhae-cd1d7'
    if project!=expected:raise ValueError('Firebase project mismatch')
    clients=[c for c in config['client'] if c['client_info']['android_client_info']['package_name']=='com.example.dondonhae']
    if len(clients)!=1:raise ValueError('Firebase Android application must match the existing package')
    if not clients[0].get('api_key') or not clients[0]['client_info'].get('mobilesdk_app_id'):raise ValueError('Incomplete Firebase Android configuration')
    path=ROOT/'android/app/google-services.json';path.write_bytes(raw);path.chmod(0o600)
    settings=ROOT/'android/settings.gradle'
    text=settings.read_text()
    if 'com.google.gms.google-services' not in text:
        text=text.replace('plugins {','plugins {\n    id "com.google.gms.google-services" version "4.4.2" apply false',1)
        settings.write_text(text)
    app=ROOT/'android/app/build.gradle';text=app.read_text()
    if 'com.google.gms.google-services' not in text:
        text=text.replace('plugins {','plugins {\n    id "com.google.gms.google-services"',1);app.write_text(text)
    manifest=ROOT/'android/app/src/main/AndroidManifest.xml';text=manifest.read_text()
    if 'com.google.firebase.messaging.default_notification_channel_id' not in text:
        text=text.replace('</application>','<meta-data android:name="com.google.firebase.messaging.default_notification_channel_id" android:value="disease_nationwide_v2" />\n    </application>')
        manifest.write_text(text)
    print('Firebase configuration matches the existing app and selected project')
    return True

if __name__=='__main__':
    parser=argparse.ArgumentParser();parser.add_argument('--require',action='store_true')
    configure(parser.parse_args().require)
