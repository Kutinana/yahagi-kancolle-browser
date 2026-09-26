import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path
from unittest.mock import patch

from PIL import Image

from tool.build_sortie_release import build_release
from tool import build_sortie_release


def _fixture(root: Path, *, data_version: str = '2026.09.20') -> tuple[Path, Path, Path]:
    assets = root / 'assets'
    data_dir = assets / 'data'
    cover_dir = assets / 'images' / 'sortie_maps' / 'covers'
    map_dir = assets / 'images' / 'sortie_maps' / 'maps'
    data_dir.mkdir(parents=True)
    cover_dir.mkdir(parents=True)
    map_dir.mkdir(parents=True)
    Image.new('RGBA', (4, 2), (20, 40, 60, 255)).save(cover_dir / '1-1.png')
    Image.new('RGBA', (8, 4), (20, 40, 60, 255)).save(map_dir / '1-1.png')
    catalog = {
        'version': 1, 'schemaVersion': 1, 'dataVersion': data_version, 'revision': 2026092001,
        'publishedAt': '2026-09-20T00:00:00Z', 'source': 'test',
        'maps': [{
            'id': '1-1', 'nameJa': 'test', 'difficulty': 1,
            'coverAsset': 'assets/images/sortie_maps/covers/1-1.png',
            'mapAsset': 'assets/images/sortie_maps/maps/1-1.png',
            'nodes': [{'point': 'A', 'kind': 'battle', 'typeLabel': 'battle',
                       'battleTypeLabel': 'battle', 'formations': []}],
        }],
    }
    (data_dir / 'sortie_map_catalog.json').write_text(json.dumps(catalog), encoding='utf-8')
    return assets, root / 'manifest.json', root / 'dist'


class BuildSortieReleaseTest(unittest.TestCase):
    def test_rejects_catalog_without_nodes(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
            catalog['maps'][0]['nodes'] = []
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'node count'):
                build_release(assets, manifest, dist)

    def test_rejects_nonstandard_json_numbers(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
            catalog['maps'][0]['audit'] = float('nan')
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'nonstandard JSON'):
                build_release(assets, manifest, dist)

    def test_changed_archive_requires_higher_revision_and_new_tag(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            build_release(assets, manifest, dist)
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
            catalog['maps'][0]['nameJa'] = 'new map name'
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'revision'):
                build_release(assets, manifest, dist)
            catalog['revision'] += 1
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'tag'):
                build_release(assets, manifest, dist)
            catalog['dataVersion'] = '2026.09.20.1'
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            build_release(assets, manifest, dist)

    def test_rejects_catalog_missing_a_required_client_field(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
            del catalog['version']
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'version'):
                build_release(assets, manifest, dist)

    def test_rejects_invalid_nested_client_fields(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            original = json.loads(catalog_file.read_text(encoding='utf-8'))
            invalid_cases = [
                ({'nodes': [{'point': 'A', 'formations': []}]}, 'kind'),
                ({'nodes': [{'point': 'A', 'kind': 'battle', 'typeLabel': 'battle',
                            'battleTypeLabel': 'battle', 'formations': [{'variant': 1}]}]}, 'fleetGroups'),
                ({'nodes': [{'point': 'A', 'kind': 'battle', 'typeLabel': 'battle',
                            'battleTypeLabel': 'battle', 'formations': [{'variant': 1,
                            'fleetGroups': [[{'id': 1}]]}]}]}, 'nameJa'),
            ]
            for replacement, message in invalid_cases:
                with self.subTest(message=message):
                    catalog = json.loads(json.dumps(original))
                    catalog['maps'][0].update(replacement)
                    catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
                    with self.assertRaisesRegex(ValueError, message):
                        build_release(assets, manifest, dist)

    def test_rejects_manifest_identifiers_the_client_cannot_parse(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary), data_version='bad/version')
            with self.assertRaisesRegex(ValueError, 'dataVersion'):
                build_release(assets, manifest, dist)
            self.assertFalse(manifest.exists())
            safe_assets, safe_manifest, safe_dist = _fixture(Path(temporary) / 'safe')
            for version in ('1.0.8-foo..bar', '1.0.8-beta.02'):
                with self.subTest(version=version):
                    with self.assertRaisesRegex(ValueError, 'minimumAppVersion'):
                        build_release(
                            safe_assets, safe_manifest, safe_dist,
                            minimum_app_version=version,
                        )

    def test_rejects_duplicate_map_ids_and_invalid_pngs(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            catalog_file = assets / 'data' / 'sortie_map_catalog.json'
            catalog = json.loads(catalog_file.read_text(encoding='utf-8'))
            catalog['maps'].append(dict(catalog['maps'][0]))
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'duplicate map id'):
                build_release(assets, manifest, dist)
            catalog['maps'].pop()
            catalog_file.write_text(json.dumps(catalog), encoding='utf-8')
            (assets / 'images' / 'sortie_maps' / 'covers' / '1-1.png').write_bytes(b'not a png')
            with self.assertRaisesRegex(ValueError, 'PNG'):
                build_release(assets, manifest, dist)

    def test_rejects_assets_exceeding_client_install_limits(self):
        with tempfile.TemporaryDirectory() as temporary:
            assets, manifest, dist = _fixture(Path(temporary))
            for name, value, message in [
                ('MAX_FILES', 2, 'file count'),
                ('MAX_UNCOMPRESSED_BYTES', 100, 'uncompressed'),
                ('MAX_ARCHIVE_BYTES', 100, 'archive size'),
            ]:
                with self.subTest(name=name), patch.object(
                    build_sortie_release, name, value, create=True,
                ):
                    with self.assertRaisesRegex(ValueError, message):
                        build_release(assets, manifest, dist)

    def test_builds_deterministic_archive_and_manifest(self):
        with tempfile.TemporaryDirectory() as temp_dir:
            root = Path(temp_dir)
            assets = root / "assets"
            data_dir = assets / "data"
            cover_dir = assets / "images" / "sortie_maps" / "covers"
            map_dir = assets / "images" / "sortie_maps" / "maps"
            data_dir.mkdir(parents=True)
            cover_dir.mkdir(parents=True)
            map_dir.mkdir(parents=True)
            Image.new("RGBA", (4, 2), (20, 40, 60, 255)).save(
                cover_dir / "1-1.png"
            )
            Image.new("RGBA", (8, 4), (20, 40, 60, 255)).save(
                map_dir / "1-1.png"
            )
            catalog = {
                "version": 1,
                "schemaVersion": 1,
                "dataVersion": "2026.09.20",
                "revision": 2026092001,
                "publishedAt": "2026-09-20T00:00:00Z",
                "source": "https://zh.kcwiki.cn/wiki/出击",
                "maps": [
                    {
                        "id": "1-1",
                        "nameJa": "鎮守府正面海域",
                        "difficulty": 1,
                        "coverAsset": "assets/images/sortie_maps/covers/1-1.png",
                        "mapAsset": "assets/images/sortie_maps/maps/1-1.png",
                        "mapAspectRatio": 2.0,
                        "source": None,
                        "nodes": [
                            {
                                "point": "A",
                                "kind": "battle",
                                "typeLabel": "通常",
                                "battleTypeLabel": "通常戦闘",
                                "nameJa": "敵偵察艦",
                                "reward": None,
                                "formations": [],
                            }
                        ],
                    }
                ],
            }
            (data_dir / "sortie_map_catalog.json").write_text(
                json.dumps(catalog, ensure_ascii=False), encoding="utf-8"
            )
            manifest_path = root / "data" / "sortie" / "manifest.json"
            dist_dir = root / "data" / "sortie" / "dist"

            first = build_release(assets, manifest_path, dist_dir)
            first_bytes = first.read_bytes()
            second = build_release(assets, manifest_path, dist_dir)
            second_bytes = second.read_bytes()

            self.assertEqual(first_bytes, second_bytes)
            manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
            self.assertEqual(manifest["revision"], 2026092001)
            self.assertEqual(manifest["minimumAppVersion"], "1.0.8-beta.2")
            self.assertEqual(manifest["counts"], {
                "maps": 1,
                "nodes": 1,
                "formations": 0,
            })
            self.assertEqual(
                manifest["archive"]["sha256"],
                hashlib.sha256(first_bytes).hexdigest(),
            )
            self.assertEqual(manifest["archive"]["bytes"], len(first_bytes))

            with zipfile.ZipFile(first) as archive:
                self.assertEqual(archive.namelist(), sorted(archive.namelist()))
                archived_catalog = archive.read(
                    "sortie_map_catalog.json"
                ).decode("utf-8")
                self.assertNotIn("assets/images/sortie_maps/", archived_catalog)
                decoded = json.loads(archived_catalog)
                self.assertEqual(decoded["maps"][0]["coverAsset"], "covers/1-1.png")
                self.assertEqual(decoded["maps"][0]["mapAsset"], "maps/1-1.png")


if __name__ == "__main__":
    unittest.main()
