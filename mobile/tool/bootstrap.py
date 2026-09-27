#!/usr/bin/env python3
"""Generate official Flutter runners, preserving every application source file.

Run once after installing Flutter: python3 tool/bootstrap.py
Platform boilerplate comes from your installed stable Flutter SDK so Gradle,
Xcode and plugin integration match the SDK instead of a hand-written template.
"""
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
flutter = shutil.which('flutter')
if not flutter:
    raise SystemExit('Install Flutter stable, add flutter/bin to PATH, then run this script again.')

# Generate in isolation: flutter create cannot replace the app or its tests.
with tempfile.TemporaryDirectory(prefix='near-runners-') as tmp:
    generated = Path(tmp) / 'near'
    subprocess.run([flutter, 'create', '--platforms=ios,android', '--org=app.near',
                    '--project-name=near', '--no-pub', str(generated)], check=True)
    for name in ('android', 'ios'):
        destination = root / name
        if destination.exists():
            print(f'Keeping existing {name}/ runner.')
            continue
        shutil.copytree(generated / name, destination)
    metadata = root / '.metadata'
    if not metadata.exists():
        shutil.copyfile(generated / '.metadata', metadata)

manifest = root / 'android/app/src/main/AndroidManifest.xml'
text = manifest.read_text()
if 'android.permission.INTERNET' not in text:
    text = text.replace('<application', '<uses-permission android:name="android.permission.INTERNET"/>\n    <application', 1)
for permission in ('ACCESS_COARSE_LOCATION', 'ACCESS_FINE_LOCATION'):
    declaration = f'<uses-permission android:name="android.permission.{permission}"/>'
    if declaration not in text:
        text = text.replace('<application', f'{declaration}\n    <application', 1)
text = re.sub(r'android:label="[^"]+"', 'android:label="Near"', text)
if 'android:allowBackup=' not in text:
    text = text.replace('<application', '<application android:allowBackup="false"', 1)
manifest.write_text(text)
# Local HTTP is allowed only for the Android debug build.
debug = root / 'android/app/src/debug/AndroidManifest.xml'
debug.parent.mkdir(parents=True, exist_ok=True)
text = debug.read_text() if debug.exists() else '<manifest xmlns:android="http://schemas.android.com/apk/res/android"></manifest>'
if 'usesCleartextTraffic' not in text:
    text = text.replace('</manifest>', '<application android:usesCleartextTraffic="true"/>\n</manifest>')
debug.write_text(text)

info = root / 'ios/Runner/Info.plist'
with info.open('rb') as stream:
    data = plistlib.load(stream)
data.update({
    'CFBundleDisplayName': 'Near',
    'NSPhotoLibraryUsageDescription': 'Choose a photo to share privately with your partner.',
    'NSCameraUsageDescription': 'Take a photo to share privately with your partner.',
    'NSLocalNetworkUsageDescription': 'Connect to your local development server during testing.',
    'NSLocationWhenInUseUsageDescription': 'Share your location with your partner to calculate the distance between you.',
})
# Allow local development hosts; arbitrary remote HTTP stays blocked.
data.setdefault('NSAppTransportSecurity', {})['NSAllowsLocalNetworking'] = True
with info.open('wb') as stream:
    plistlib.dump(data, stream)

print('iOS and Android runners are ready. Run flutter pub get, flutter analyze, flutter test.')
