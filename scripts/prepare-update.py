#!/usr/bin/env python3
"""Sign a notarized release and stage its public feed. Never exports private keys."""
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import xml.etree.ElementTree as ET

repo = Path(__file__).resolve().parents[1]
version = sys.argv[1] if len(sys.argv) == 2 else ''
if not re.fullmatch(r'\d+\.\d+\.\d+', version):
    sys.exit('Usage: scripts/prepare-update.py VERSION')
config = json.loads((repo / 'assets/update-config.json').read_text())
release = repo / f'dist/releases/Cove-{version}.dmg'
notes = repo / f'docs/releases/{version}.html'
if not notes.is_file() or not release.is_file():
    sys.exit('Missing final DMG or release notes.')
subprocess.run(['xcrun', 'stapler', 'validate', str(release)], check=True)
subprocess.run(['spctl', '--assess', '--type', 'open', '--context', 'context:primary-signature', str(release)], check=True)
# Cloudflare Pages has a 25 MiB per-file limit.
if release.stat().st_size > 25 * 1024 * 1024:
    sys.exit('Release exceeds Pages file limit; provision a download bucket before publishing.')
staging = repo / 'dist/updates'
staging.mkdir(parents=True, exist_ok=True)
shutil.copy2(release, staging / release.name)
shutil.copy2(notes, staging / (release.stem + '.html'))
tools = repo / '.build/artifacts/sparkle/Sparkle/bin'
public_key = subprocess.run([str(tools / 'generate_keys'), '--account', config['keychainAccount'], '-p'],
                            check=True, capture_output=True, text=True).stdout.strip()
if public_key != config['publicEDKey']:
    sys.exit('The saved update key does not match the public app configuration.')
subprocess.run([str(tools / 'generate_appcast'), '--account', config['keychainAccount'],
    '--download-url-prefix', 'https://covemail.xyz/downloads/', '--embed-release-notes',
    '--link', 'https://covemail.xyz/beta/', '--maximum-deltas', '0', str(staging)], check=True)
feed = staging / 'appcast.xml'
subprocess.run([str(tools / 'sign_update'), '--account', config['keychainAccount'], '--verify', str(feed)], check=True)
ns = '{http://www.andymatuschak.org/xml-namespaces/sparkle}'
items = ET.parse(feed).findall('./channel/item')
item = next((x for x in items if x.findtext(ns + 'shortVersionString') == version), None)
if item is None:
    sys.exit('Generated feed is missing the expected version.')
enclosure = item.find('enclosure')
if enclosure.get('url') != 'https://covemail.xyz/downloads/' + release.name:
    sys.exit('Unexpected release URL in signed feed.')
subprocess.run([str(tools / 'sign_update'), '--account', config['keychainAccount'], '--verify',
    str(release), enclosure.get(ns + 'edSignature')], check=True)
public = repo / 'site/updates'
public.mkdir(parents=True, exist_ok=True)
shutil.copy2(feed, public / 'appcast.xml')
digest = hashlib.sha256(release.read_bytes()).hexdigest()
(repo / 'site/downloads' / (release.name + '.sha256')).write_text(f'{digest}  {release.name}\n')
metadata = {'version': version, 'build': item.findtext(ns + 'version'), 'filename': release.name,
            'sha256': digest, 'bytes': release.stat().st_size}
(repo / 'site/release.json').write_text(json.dumps(metadata, indent=2) + '\n')
redirects = repo / 'site/_redirects'
redirects.write_text(re.sub(r'/download/latest /downloads/Cove-[^ ]+ 302',
                           f'/download/latest /downloads/{release.name} 302', redirects.read_text()))
print('Verified feed and release metadata staged. Update the beta page, run scripts/build-site.py, then publish dist/site.')
