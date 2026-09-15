#!/usr/bin/env python3
import importlib.util
from pathlib import Path
import shutil
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('guard', ROOT / 'scripts/ci/check-native-contract.py')
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

class NativeBoundary(unittest.TestCase):
    def test_pristine(self):
        guard.validate(ROOT)

    def test_mutations(self):
        cases = [
            ('native-trusted.yml', "github.event_name == 'push'", "github.event_name == 'pull_request'"),
            ('native-trusted.yml', "github.repository == 'OMT-Global/Flapline'", "true"),
            ('native-trusted.yml', 'persist-credentials: false', 'persist-credentials: true'),
            ('native-trusted.yml', 'ONLY_ACTIVE_ARCH=NO', 'ONLY_ACTIVE_ARCH=YES'),
            ('native-trusted.yml', 'github.sha', 'github.event.pull_request.head.sha'),
            ('extended-validation.yml', '@39a20bd3f530292a03cd1f102826c166115974ab', '@main'),
            ('pr-fast-ci.yml', 'runs-on: ubuntu-latest', "runs-on: [self-hosted, linux]"),
            ('claude.yml', 'runs-on: ubuntu-latest', "runs-on: [self-hosted, linux]"),
        ]
        for file, old, new in cases:
            with self.subTest(file=file, old=old), tempfile.TemporaryDirectory() as tmp:
                root = Path(tmp)
                shutil.copytree(ROOT / '.github', root / '.github')
                path = root / '.github/workflows' / file
                text = path.read_text()
                self.assertIn(old, text)
                path.write_text(text.replace(old, new, 1))
                with self.assertRaises(ValueError):
                    guard.validate(root)

    def test_comment_decoy(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            shutil.copytree(ROOT / '.github', root / '.github')
            path = root / '.github/workflows/native-trusted.yml'
            path.write_text(path.read_text().replace("github.event_name == 'push'", "true # github.event_name == 'push'"))
            with self.assertRaises(ValueError):
                guard.validate(root)

if __name__ == '__main__':
    unittest.main()
