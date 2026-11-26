#!/usr/bin/env python3
"""Validate the tag before a release job uses its signing key."""
import json
import os
import plistlib
import re
import subprocess
import tempfile
import xml.etree.ElementTree as ET
from pathlib import Path

root = Path(__file__).resolve().parent.parent
tag = os.environ['RELEASE_TAG']
if not re.fullmatch(r'v\d+\.\d+\.\d+', tag):
    raise SystemExit('정식 릴리스 태그는 v1.1.0과 같은 형식이어야 합니다.')
info = plistlib.loads((root / 'Resources/Info.plist').read_bytes())
version = info['CFBundleShortVersionString']
if tag != 'v' + version:
    raise SystemExit('태그와 Info.plist의 버전이 다릅니다.')
releases = json.loads(subprocess.run(['gh', 'release', 'list', '--limit', '100', '--json', 'tagName,isDraft,isPrerelease'], check=True, capture_output=True, text=True).stdout)
result = subprocess.run(['gh', 'release', 'view', tag, '--json', 'assets,isDraft,isPrerelease'], capture_output=True, text=True)
complete = False
if result.returncode == 0:
    release = json.loads(result.stdout)
    if release['isPrerelease']:
        raise SystemExit('이 워크플로는 정식 릴리스만 배포합니다.')
    names = {asset['name'] for asset in release['assets']}
    expected = {f'Coffee-Time-{version}-arm64.dmg', f'Coffee-Time-{version}-arm64.zip', 'appcast.xml', 'SHA256SUMS.txt'}
    complete = not release['isDraft'] and expected <= names
    if names & expected and not complete:
        raise SystemExit('일부 파일이 이미 올라가 있습니다. 기존 파일을 확인한 뒤 다시 배포해 주세요.')
if not complete:
    current = tuple(map(int, version.split('.')))
    published = [r for r in releases if not r['isDraft'] and not r['isPrerelease'] and r['tagName'] != tag]
    for release in published:
        old_tag = release['tagName']
        if re.fullmatch(r'v\d+\.\d+\.\d+', old_tag):
            if tuple(map(int, old_tag[1:].split('.'))) >= current:
                raise SystemExit('이미 배포한 버전보다 높은 버전으로 배포해 주세요.')
    if published:
        with tempfile.TemporaryDirectory(prefix='coffee-time-previous-release-') as folder:
            subprocess.run(['gh', 'release', 'download', published[0]['tagName'], '--pattern', 'appcast.xml', '--dir', folder], check=True)
            previous = ET.parse(Path(folder) / 'appcast.xml').findtext('./channel/item/{http://www.andymatuschak.org/xml-namespaces/sparkle}version')
            if previous is None or int(info['CFBundleVersion']) <= int(previous):
                raise SystemExit('빌드 번호는 이전 릴리스보다 커야 합니다.')
with open(os.environ['GITHUB_OUTPUT'], 'a') as output:
    output.write(f'complete={str(complete).lower()}\n')
print('이미 배포된 릴리스입니다.' if complete else '릴리스 버전을 확인했습니다.')
