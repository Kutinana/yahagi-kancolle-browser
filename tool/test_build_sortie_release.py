import hashlib
import json
import tempfile
import unittest
import zipfile
from pathlib import Path

from PIL import Image

from tool.build_sortie_release import build_release


class BuildSortieReleaseTest(unittest.TestCase):
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
