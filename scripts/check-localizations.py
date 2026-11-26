#!/usr/bin/env python3
"""Check translation coverage and printf argument types before packaging."""
import json
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parent.parent

def read_table(language):
    path = root / 'Resources' / f'{language}.lproj' / 'Localizable.strings'
    return json.loads(subprocess.check_output(['plutil', '-convert', 'json', '-o', '-', str(path)]))

def argument_types(value):
    arguments = {}
    next_position = 1
    for match in re.finditer(r'%(?:(\d+)\$)?(ld|@|%)', value):
        position, kind = match.groups()
        if kind == '%':
            continue
        position = int(position) if position else next_position
        assert position not in arguments or arguments[position] == kind
        arguments[position] = kind
        next_position += 1
    return arguments

en = read_table('en')
ko = read_table('ko')
assert en.keys() == ko.keys(), 'English and Korean translation keys differ'
for key in en:
    assert en[key] == key, f'English fallback differs from its key: {key}'
    assert ko[key].strip(), f'Empty Korean translation: {key}'
    assert argument_types(en[key]) == argument_types(ko[key]), f'Format arguments differ: {key}'
used = set()
for source in (root / 'Sources').glob('*.swift'):
    text = source.read_text().split('if CommandLine.arguments.contains("--integration-test")')[0]
    for key in re.findall(r'L10n\.(?:text|format)\(("(?:[^"\\]|\\.)*")', text):
        used.add(json.loads(key))
assert used <= en.keys(), f'Missing translations: {used - en.keys()}'
assert en.keys() <= used, f'Unused translations: {en.keys() - used}'
print(f'{len(en)} English and Korean translations verified')
