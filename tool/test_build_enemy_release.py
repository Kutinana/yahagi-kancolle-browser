import json
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tool.build_enemy_release import build_release
from tool import build_enemy_release


def _valid_catalog() -> dict:
    return {
        'schemaVersion': 1, 'dataVersion': 'v1', 'revision': 3,
        'publishedAt': '2026-09-20T00:00:00Z', 'source': 'test',
        'ships': [{'key': '1@a', 'id': 1, 'name': 'a', 'equipment': [
            {'slot': 1, 'name': 'gun', 'matched': False, 'stats': None},
        ]}],
        'aliases': {'1|a': '1@a'}, 'quality': {},
    }


class BuildEnemyReleaseTest(unittest.TestCase):
    def test_rejects_nonstandard_json_numbers(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.json'
            manifest = root / 'manifest.json'
            payload = _valid_catalog()
            payload['quality']['audit'] = float('nan')
            catalog.write_text(json.dumps(payload), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'nonstandard JSON'):
                build_release(catalog, manifest, tag='enemy-data-v1')

    def test_rejects_boolean_schema_version(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.json'
            manifest = root / 'manifest.json'
            payload = _valid_catalog()
            payload['schemaVersion'] = True
            catalog.write_text(json.dumps(payload), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'root'):
                build_release(catalog, manifest, tag='enemy-data-v1')

    def test_changed_catalog_requires_higher_revision_and_new_tag(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.json'
            manifest = root / 'manifest.json'
            payload = _valid_catalog()
            catalog.write_text(json.dumps(payload), encoding='utf-8')
            build_release(catalog, manifest, tag='enemy-data-v1')
            payload['ships'][0]['name'] = 'new name'
            catalog.write_text(json.dumps(payload), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'revision'):
                build_release(catalog, manifest, tag='enemy-data-v1')
            payload['revision'] += 1
            catalog.write_text(json.dumps(payload), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'tag'):
                build_release(catalog, manifest, tag='enemy-data-v1')
            build_release(catalog, manifest, tag='enemy-data-v2')

    def test_rejects_fields_that_the_client_cannot_parse(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.json'
            manifest = root / 'manifest.json'
            for field, bad_value in [
                ('firepower', {'base': 'not a number'}),
                ('evasion', 'not a number'),
            ]:
                with self.subTest(field=field):
                    payload = _valid_catalog()
                    payload['ships'][0][field] = bad_value
                    catalog.write_text(json.dumps(payload), encoding='utf-8')
                    with self.assertRaisesRegex(ValueError, field):
                        build_release(catalog, manifest, tag='enemy-data-v1')

    def test_rejects_data_or_manifest_beyond_client_limits(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            catalog = root / 'catalog.json'
            manifest = root / 'manifest.json'
            catalog.write_text(json.dumps(_valid_catalog()), encoding='utf-8')
            for name, limit, message in [
                ('MAX_DATA_BYTES', 10, 'catalog size'),
                ('MAX_MANIFEST_BYTES', 10, 'manifest size'),
            ]:
                with self.subTest(name=name), patch.object(build_enemy_release, name, limit, create=True):
                    with self.assertRaisesRegex(ValueError, message):
                        build_release(catalog, manifest, tag='enemy-data-v1')

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
            self.assertEqual(
                decoded["dataUrl"],
                "https://github.com/yamatosaki/yahagi-kancolle-data/releases/download/enemy-data-v1/enemy_catalog.json",
            )

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
            catalog.write_text(json.dumps(_valid_catalog()), encoding='utf-8')
            for version in ('1.0.8-foo..bar', '1.0.8-beta.02'):
                with self.subTest(version=version), self.assertRaisesRegex(ValueError, 'version'):
                    build_release(
                        catalog, manifest, tag='enemy-data-v1',
                        minimum_app_version=version,
                    )


if __name__ == "__main__":
    unittest.main()
