#!/usr/bin/env python3
"""Package a built app and sign the update feed with Sparkle."""
import hashlib
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / 'dist/Coffee Time.app'
TOOLS = ROOT / '.cache/sparkle/bin'
REPOSITORY = 'henrychoi7/coffee-time'


def run(*args, **kwargs):
    return subprocess.run([str(arg) for arg in args], check=True, **kwargs)


def signing_args():
    if os.environ.get('SPARKLE_PRIVATE_KEY'):
        return ['--ed-key-file', '-'], {'input': os.environ['SPARKLE_PRIVATE_KEY'].strip().encode() + b'\n'}
    return ['--account', 'coffee-time'], {}


def main():
    info = plistlib.loads((APP / 'Contents/Info.plist').read_bytes())
    version = info['CFBundleShortVersionString']
    source_info = plistlib.loads((ROOT / 'Resources/Info.plist').read_bytes())
    if not re.fullmatch(r'\d+\.\d+\.\d+', version):
        raise SystemExit('릴리스 버전은 1.1.0과 같은 형식으로 지정해 주세요.')
    if any(info[key] != source_info[key] for key in ('CFBundleVersion', 'CFBundleShortVersionString', 'SUPublicEDKey', 'SUFeedURL')):
        raise SystemExit('시험용 빌드는 배포할 수 없습니다. 기본 설정으로 다시 빌드해 주세요.')
    notes = ROOT / f'docs/releases/{version}.md'
    if not notes.is_file():
        raise SystemExit(f'릴리스 설명을 먼저 작성해 주세요: {notes.relative_to(ROOT)}')
    run('codesign', '--verify', '--deep', '--strict', APP)
    output = ROOT / f'dist/release-{version}'
    output.mkdir(parents=True, exist_ok=True)
    basename = f'Coffee-Time-{version}-arm64'
    archive = output / f'{basename}.zip'
    if archive.exists():
        archive.unlink()
    run('ditto', '-c', '-k', '--sequesterRsrc', '--keepParent', APP, archive)
    args, kwargs = signing_args()
    with tempfile.TemporaryDirectory(prefix='coffee-time-release-') as folder:
        staging = Path(folder)
        updates = staging / 'updates'
        updates.mkdir()
        shutil.copy2(archive, updates / archive.name)
        shutil.copy2(notes, updates / f'{basename}.md')
        run(TOOLS / 'generate_appcast', *args, '--maximum-deltas', '0', '--embed-release-notes',
            '--download-url-prefix', f'https://github.com/{REPOSITORY}/releases/download/v{version}/',
            '--full-release-notes-url', f'https://github.com/{REPOSITORY}/releases',
            '-o', output / 'appcast.xml', updates, **kwargs)
        tree = ET.parse(output / 'appcast.xml')
        enclosure = tree.find('./channel/item/enclosure')
        signature = enclosure.attrib['{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature']
        run(TOOLS / 'sign_update', *args, '--verify', archive, signature, **kwargs)
        run(TOOLS / 'sign_update', *args, '--verify', output / 'appcast.xml', **kwargs)
        image_source = staging / 'image'
        image_source.mkdir()
        run('ditto', APP, image_source / 'Coffee Time.app')
        (image_source / 'Applications').symlink_to('/Applications')
        image = output / f'{basename}.dmg'
        run('hdiutil', 'create', '-ov', '-volname', 'Coffee Time', '-srcfolder', image_source,
            '-fs', 'HFS+', '-format', 'UDZO', image)
        run('hdiutil', 'verify', image)
    files = [archive, image, output / 'appcast.xml']
    (output / 'SHA256SUMS.txt').write_text(''.join(f'{hashlib.sha256(p.read_bytes()).hexdigest()}  {p.name}\n' for p in files))
    print(f'릴리스 파일을 만들었습니다: {output}')


if __name__ == '__main__':
    main()
