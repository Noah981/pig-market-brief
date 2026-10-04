import os,tempfile,unittest
from pathlib import Path
from unittest.mock import patch
from scripts.configure_android_release_signing import configure

class ReleaseSigningTest(unittest.TestCase):
 def test_missing_private_key_does_not_change_validation_signer(self):
  with tempfile.TemporaryDirectory() as root,patch.dict(os.environ,{},clear=True):
   gradle=Path(root)/'build.gradle';gradle.write_text('android {}\n')
   self.assertFalse(configure(gradle));self.assertEqual(gradle.read_text(),'android {}\n')
 def test_secret_password_is_not_written_into_checkout(self):
  with tempfile.TemporaryDirectory() as root:
   gradle=Path(root)/'build.gradle';gradle.write_text('android {}\n')
   key=Path(root)/'release.p12';key.write_bytes(b'unit-test fixture')
   with patch.dict(os.environ,{'DDH_ANDROID_KEYSTORE_FILE':str(key),'DDH_ANDROID_KEYSTORE_PASSWORD':'unit-test-private-password'}):
    self.assertTrue(configure(gradle));self.assertTrue(configure(gradle))
   text=gradle.read_text();self.assertNotIn('unit-test-private-password',text);self.assertNotIn(str(key),text);self.assertEqual(text.count('dondonhaeRelease {'),1)
 def test_nonexistent_keystore_is_not_a_production_signer(self):
  with tempfile.TemporaryDirectory() as root,patch.dict(os.environ,{'DDH_ANDROID_KEYSTORE_FILE':'/nonexistent/release.p12','DDH_ANDROID_KEYSTORE_PASSWORD':'unit-test'}):
   gradle=Path(root)/'build.gradle';gradle.write_text('android {}\n')
   self.assertFalse(configure(gradle))
if __name__=='__main__':unittest.main()
