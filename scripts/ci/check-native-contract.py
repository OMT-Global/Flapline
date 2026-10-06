#!/usr/bin/env python3
import hashlib
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = '4c3a0aa1a56cc08d83074207b2ab58051ce772241984c10d8db09bec290399c3'
TARGET = 'OMT-Global/Flapline/.github/workflows/native-trusted.yml@2a5b2ae2675186b0913d6ed1c0d1ff9e35fbc3ad'

def validate(root):
    workflow = root / '.github/workflows/native-trusted.yml'
    if hashlib.sha256(workflow.read_bytes()).hexdigest() != EXPECTED:
        raise ValueError('Immutable native callee changed: independent review and selector renewal required')
    caller = (root / '.github/workflows/extended-validation.yml').read_text()
    if caller.count('uses: ' + TARGET) != 1:
        raise ValueError('Missing exact immutable caller')
    for path in (root / '.github/workflows').glob('*.yml'):
        if path == workflow:
            continue
        text = path.read_text()
        if 'self-hosted' in text or re.search(r'runs-on:\s*\n\s+group:', text):
            raise ValueError('Alternate self-hosted path: ' + path.name)

if __name__ == '__main__':
    try:
        validate(ROOT)
    except (ValueError, OSError) as error:
        print(error, file=sys.stderr)
        sys.exit(1)
    print('Immutable native contract valid')
