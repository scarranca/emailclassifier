#!/usr/bin/env python3
"""Stage the website and checksum-verified downloads into dist/site."""
from pathlib import Path
import hashlib
import json
import shutil
import xml.etree.ElementTree as ET

repo = Path(__file__).resolve().parents[1]
source = repo / 'site'
output = repo / 'dist/site'
metadata = json.loads((source / 'release.json').read_text())
feed = ET.parse(source / 'updates/appcast.xml')
# Preserve old published download links and all signed-feed enclosures.
required = {p.name.removesuffix('.sha256') for p in (source / 'downloads').glob('*.dmg.sha256')}
required.add(metadata['filename'])
for enclosure in feed.findall('./channel/item/enclosure'):
    url = enclosure.get('url', '')
    if not url.startswith('https://covemail.xyz/downloads/'):
        raise SystemExit('Unexpected release URL in feed')
    required.add(url.rsplit('/', 1)[1])
verified = []
for name in sorted(required):
    release = repo / 'dist/releases' / name
    if not release.is_file():
        release = source / 'downloads' / name
    checksum = (source / 'downloads' / (name + '.sha256')).read_text().split()[0]
    if hashlib.sha256(release.read_bytes()).hexdigest() != checksum:
        raise SystemExit(f'Release checksum mismatch: {name}')
    verified.append((release, name))
if output.exists():
    shutil.rmtree(output)
shutil.copytree(source, output, ignore=shutil.ignore_patterns('*.dmg', '.DS_Store'))
for release, name in verified:
    shutil.copy2(release, output / 'downloads' / name)
print(f'Website ready: {output} (Cove {metadata["version"]}, {len(verified)} verified releases)')
