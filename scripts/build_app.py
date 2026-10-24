#!/usr/bin/env python3
"""Build a local ad-hoc signed app in dist. Does not install or launch it."""
import json
from pathlib import Path
import plistlib
import shutil
import subprocess

root = Path(__file__).resolve().parent.parent
config = json.loads((root / 'app-config.json').read_text())
name = config['name']
version_file = root / 'VERSION'
version = version_file.read_text().strip() if version_file.exists() else '0.1.0'
if not name.strip() or any(c in name for c in '/\\\n\r\x00') or name in ('.', '..'):
    raise SystemExit('Invalid application name')
subprocess.run(['swift', 'build', '-c', 'release'], cwd=root, check=True)
bin_path = subprocess.check_output(['swift', 'build', '-c', 'release', '--show-bin-path'], cwd=root, text=True).strip()
app = root / 'dist' / f'{name}.app'
macos = app / 'Contents' / 'MacOS'
macos.mkdir(parents=True, exist_ok=True)
shutil.copy2(Path(bin_path) / 'ClotheslineApp', macos / 'ClotheslineApp')
resources = app / 'Contents' / 'Resources'
resources.mkdir(parents=True, exist_ok=True)
for license_name in ['LICENSE', 'THIRD_PARTY_LICENSES.txt']:
    license_file = root / license_name
    if license_file.exists(): shutil.copy2(license_file, resources / license_file.name)
icon = root / 'assets' / 'AppIcon.icns'
if icon.exists(): shutil.copy2(icon, resources / icon.name)
info = {
    'CFBundleName': name, 'CFBundleDisplayName': name,
    'CFBundleIdentifier': config['bundle_id'], 'CFBundleExecutable': 'ClotheslineApp',
    'CFBundlePackageType': 'APPL', 'CFBundleShortVersionString': version, 'CFBundleVersion': str(config.get('build', 1)),
    'LSMinimumSystemVersion': '14.0', 'LSUIElement': True, 'NSHighResolutionCapable': True,
}
if icon.exists(): info['CFBundleIconFile'] = 'AppIcon'
with (app / 'Contents' / 'Info.plist').open('wb') as stream:
    plistlib.dump(info, stream)
subprocess.run(['codesign', '--force', '--sign', '-', str(app)], check=True)
subprocess.run(['codesign', '--verify', '--deep', '--strict', str(app)], check=True)
print(app)
