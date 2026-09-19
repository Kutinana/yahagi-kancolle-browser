import json
import tempfile
import unittest
from pathlib import Path

from build_enemy_release import build_release


class BuildEnemyReleaseTest(unittest.TestCase):
    def test_writes_digest_and_counts(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / "catalog.json"
            manifest = root / "manifest.json"
            catalog.write_text(json.dumps({
                "schemaVersion": 1, "dataVersion": "v1", "revision": 3,
                "publishedAt": "2026-09-20T00:00:00Z",
                "source": "test",
                "ships": [{
                    "key": "1@a", "id": 1, "name": "a", "equipment": [{
                        "slot": 1, "name": "gun", "matched": False, "stats": None,
                    }],
                }],
                "aliases": {"1|a": "1@a"}, "quality": {},
            }), encoding="utf-8")

            result = build_release(catalog, manifest, tag="enemy-data-v1")

            decoded = json.loads(manifest.read_text(encoding="utf-8"))
            self.assertEqual(decoded["revision"], 3)
            self.assertEqual(decoded["shipCount"], 1)
            self.assertEqual(decoded["aliasCount"], 1)
            self.assertEqual(decoded["dataSha256"], result["sha256"])

    def test_rejects_malformed_catalog_and_release_identifiers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / "catalog.json"
            manifest = root / "manifest.json"
            catalog.write_text(json.dumps({
                "schemaVersion": 1, "dataVersion": "v1", "revision": 3,
                "publishedAt": "2026-09-20T00:00:00Z", "source": "test",
                "ships": [{"key": "a"}], "aliases": {"x": "a"},
                "quality": {},
            }), encoding="utf-8")

            with self.assertRaisesRegex(ValueError, "ship fields"):
                build_release(catalog, manifest, tag="enemy-data-v1")
            with self.assertRaisesRegex(ValueError, "tag"):
                build_release(catalog, manifest, tag="../unsafe")
            with self.assertRaisesRegex(ValueError, "version"):
                build_release(
                    catalog, manifest, tag="enemy-data-v1",
                    minimum_app_version="latest",
                )


if __name__ == "__main__":
    unittest.main()
