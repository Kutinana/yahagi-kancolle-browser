"""Build a deterministic sortie-data release archive and update manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import zipfile
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSETS_ROOT = PROJECT_ROOT / "assets"
DEFAULT_MANIFEST = PROJECT_ROOT / "data" / "sortie" / "manifest.json"
DEFAULT_DIST = PROJECT_ROOT / "data" / "sortie" / "dist"
ASSET_PREFIX = "assets/images/sortie_maps/"


def _load_catalog(assets_root: Path) -> dict[str, Any]:
    path = assets_root / "data" / "sortie_map_catalog.json"
    decoded = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(decoded, dict) or not isinstance(decoded.get("maps"), list):
        raise ValueError("sortie map catalog root is invalid")
    for key in ("schemaVersion", "dataVersion", "revision", "publishedAt"):
        if key not in decoded:
            raise ValueError(f"sortie map catalog is missing {key}")
    return decoded


def _logical_image_path(value: Any, kind: str, map_id: str) -> str:
    expected = f"{ASSET_PREFIX}{kind}/{map_id}.png"
    if value != expected:
        raise ValueError(f"unexpected {kind} image reference for {map_id}: {value!r}")
    return f"{kind}/{map_id}.png"


def _zip_info(name: str, published_at: str) -> zipfile.ZipInfo:
    timestamp = datetime.fromisoformat(published_at.replace("Z", "+00:00"))
    timestamp = timestamp.astimezone(timezone.utc)
    year = max(1980, timestamp.year)
    info = zipfile.ZipInfo(
        name,
        date_time=(year, timestamp.month, timestamp.day, timestamp.hour, timestamp.minute, timestamp.second),
    )
    info.compress_type = zipfile.ZIP_DEFLATED
    info.external_attr = 0o100644 << 16
    return info


def _atomic_write(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f"{path.name}.tmp")
    temporary.write_bytes(data)
    os.replace(temporary, path)


def build_release(
    assets_root: Path = DEFAULT_ASSETS_ROOT,
    manifest_path: Path = DEFAULT_MANIFEST,
    dist_dir: Path = DEFAULT_DIST,
    *,
    minimum_app_version: str = "1.0.8-beta.2",
) -> Path:
    catalog = _load_catalog(assets_root)
    archived = deepcopy(catalog)
    entries: dict[str, bytes] = {}
    node_count = 0
    formation_count = 0

    for map_info in archived["maps"]:
        if not isinstance(map_info, dict):
            raise ValueError("catalog maps must be objects")
        map_id = str(map_info.get("id") or "")
        if not map_id:
            raise ValueError("catalog map id is empty")
        cover = _logical_image_path(map_info.get("coverAsset"), "covers", map_id)
        route = _logical_image_path(map_info.get("mapAsset"), "maps", map_id)
        map_info["coverAsset"] = cover
        map_info["mapAsset"] = route
        for logical in (cover, route):
            source = assets_root / "images" / "sortie_maps" / Path(logical)
            if not source.is_file():
                raise ValueError(f"catalog image is missing: {logical}")
            entries[logical] = source.read_bytes()
        nodes = map_info.get("nodes")
        if not isinstance(nodes, list):
            raise ValueError(f"catalog nodes are invalid for {map_id}")
        node_count += len(nodes)
        for node in nodes:
            formations = node.get("formations") if isinstance(node, dict) else None
            if not isinstance(formations, list):
                raise ValueError(f"catalog formations are invalid for {map_id}")
            formation_count += len(formations)

    catalog_bytes = (
        json.dumps(archived, ensure_ascii=False, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    entries["sortie_map_catalog.json"] = catalog_bytes

    data_version = str(catalog["dataVersion"])
    archive_name = f"sortie-data-{data_version}.zip"
    archive_path = dist_dir / archive_name
    archive_path.parent.mkdir(parents=True, exist_ok=True)
    temporary_archive = archive_path.with_name(f"{archive_path.name}.tmp")
    with zipfile.ZipFile(
        temporary_archive,
        mode="w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for name in sorted(entries):
            archive.writestr(_zip_info(name, str(catalog["publishedAt"])), entries[name])
    os.replace(temporary_archive, archive_path)

    archive_bytes = archive_path.read_bytes()
    manifest = {
        "schemaVersion": 1,
        "dataVersion": data_version,
        "revision": int(catalog["revision"]),
        "publishedAt": str(catalog["publishedAt"]),
        "minimumAppVersion": minimum_app_version,
        "archive": {
            "tag": f"sortie-data-{data_version}",
            "fileName": archive_name,
            "bytes": len(archive_bytes),
            "sha256": hashlib.sha256(archive_bytes).hexdigest(),
        },
        "counts": {
            "maps": len(archived["maps"]),
            "nodes": node_count,
            "formations": formation_count,
        },
    }
    _atomic_write(
        manifest_path,
        (json.dumps(manifest, ensure_ascii=False, indent=2) + "\n").encode("utf-8"),
    )
    return archive_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--assets-root", type=Path, default=DEFAULT_ASSETS_ROOT)
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--dist", type=Path, default=DEFAULT_DIST)
    parser.add_argument("--minimum-app-version", default="1.0.8-beta.2")
    args = parser.parse_args()
    archive = build_release(
        args.assets_root,
        args.manifest,
        args.dist,
        minimum_app_version=args.minimum_app_version,
    )
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    print(
        json.dumps(
            {
                "archive": str(archive),
                "bytes": manifest["archive"]["bytes"],
                "sha256": manifest["archive"]["sha256"],
                "counts": manifest["counts"],
            },
            ensure_ascii=False,
        )
    )


if __name__ == "__main__":
    main()
