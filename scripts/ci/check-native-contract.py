#!/usr/bin/env python3
import hashlib
import re
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
EXPECTED = '788615f11474103035501f6ea7380116e53ef57a48bb6ac2585455015e221163'
TARGET = 'OMT-Global/Flapline/.github/workflows/native-trusted.yml@19590e95cfa40ce282b00d2816a77d84f9f5280a'

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
