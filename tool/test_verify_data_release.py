"""Regression checks for tracked manifest versus generated release drift."""

import json
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
DART = shutil.which('dart')


class VerifyDataReleaseTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if DART is None:
            raise unittest.SkipTest('Dart SDK is not installed')

    def test_rejects_tampered_tracked_sortie_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = json.loads((ROOT / 'data/sortie/manifest.json').read_text(encoding='utf-8'))
            source['archive']['bytes'] += 1
            target = Path(temporary) / 'sortie-manifest.json'
            target.write_text(json.dumps(source), encoding='utf-8')

            result = subprocess.run(
                [DART, 'run', 'tool/verify_data_release.dart', '--sortie-manifest', str(target)],
                cwd=ROOT, capture_output=True, text=True, timeout=120,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Generated sortie release differs', result.stderr)

    def test_rejects_tampered_tracked_enemy_manifest(self):
        with tempfile.TemporaryDirectory() as temporary:
            source = json.loads((ROOT / 'data/enemy/manifest.json').read_text(encoding='utf-8'))
            source['aliasCount'] += 1
            target = Path(temporary) / 'enemy-manifest.json'
            target.write_text(json.dumps(source), encoding='utf-8')

            result = subprocess.run(
                [DART, 'run', 'tool/verify_data_release.dart', '--enemy-manifest', str(target)],
                cwd=ROOT, capture_output=True, text=True, timeout=120,
            )

            self.assertNotEqual(result.returncode, 0)
            self.assertIn('Generated enemy release differs', result.stderr)


if __name__ == '__main__':
    unittest.main()
