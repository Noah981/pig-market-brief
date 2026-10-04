"""Use the persistent Android release key when it is supplied by private CI secrets.

Never generate replacement keys or write passwords into the checkout. Validation
builds keep the platform's test signer and must not be published as production.
"""
import os
from pathlib import Path

def configure(gradle):
    key_file=os.environ.get('DDH_ANDROID_KEYSTORE_FILE','')
    password=os.environ.get('DDH_ANDROID_KEYSTORE_PASSWORD','')
    if not key_file or not password or not Path(key_file).is_file():
        print('Validation build: production signing key not supplied')
        return False
    text=gradle.read_text(encoding='utf-8')
    if 'dondonhaeRelease' not in text:
        text+='''\nandroid {
    signingConfigs {
        dondonhaeRelease {
            storeFile file(System.getenv('DDH_ANDROID_KEYSTORE_FILE'))
            storeType 'PKCS12'
            storePassword System.getenv('DDH_ANDROID_KEYSTORE_PASSWORD')
            keyAlias 'dondonhae-release'
            keyPassword System.getenv('DDH_ANDROID_KEYSTORE_PASSWORD')
        }
    }
    buildTypes { release { signingConfig signingConfigs.dondonhaeRelease } }
}
'''
        gradle.write_text(text,encoding='utf-8')
    print('Persistent production signing configured')
    return True

if __name__=='__main__':
    configure(Path(__file__).resolve().parents[1]/'flutter_app/android/app/build.gradle')
