"""Build a deterministic sortie-data release archive and update manifest."""

from __future__ import annotations

import argparse
import hashlib
import json
import math
import os
import re
import zipfile
from copy import deepcopy
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from PIL import Image, UnidentifiedImageError


PROJECT_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ASSETS_ROOT = PROJECT_ROOT / "assets"
DEFAULT_MANIFEST = PROJECT_ROOT / "data" / "sortie" / "manifest.json"
DEFAULT_DIST = PROJECT_ROOT / "data" / "sortie" / "dist"
ASSET_PREFIX = "assets/images/sortie_maps/"
MAX_ARCHIVE_BYTES = 64 * 1024 * 1024
MAX_UNCOMPRESSED_BYTES = 96 * 1024 * 1024
MAX_FILES = 256
MAX_MANIFEST_BYTES = 64 * 1024
_SAFE_TOKEN = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}$")
_SAFE_FILE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,127}\.zip$")
_SAFE_MAP_ID = re.compile(r"^[A-Za-z0-9-]+$")
_SEMVER_IDENTIFIER = r"(?:0|[1-9]\d*|\d*[A-Za-z-][0-9A-Za-z-]*)"
_VERSION = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)"
    rf"(?:-{_SEMVER_IDENTIFIER}(?:\.{_SEMVER_IDENTIFIER})*)?"
    r"(?:\+[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?$"
)


def _reject_nonstandard_json(value: str) -> None:
    raise ValueError(f"nonstandard JSON number: {value}")


def _load_catalog(assets_root: Path) -> dict[str, Any]:
    path = assets_root / "data" / "sortie_map_catalog.json"
    decoded = json.loads(
        path.read_text(encoding="utf-8"),
        parse_constant=_reject_nonstandard_json,
    )
    if not isinstance(decoded, dict) or not isinstance(decoded.get("maps"), list):
        raise ValueError("sortie map catalog root is invalid")
    for key in ("schemaVersion", "dataVersion", "revision", "publishedAt"):
        if key not in decoded:
            raise ValueError(f"sortie map catalog is missing {key}")
    _validate_client_catalog(decoded)
    return decoded


def _required_int(value: dict[str, Any], key: str) -> int:
    result = value.get(key)
    if isinstance(result, bool) or not isinstance(result, int):
        raise ValueError(f"client catalog {key} must be an integer")
    return result


def _required_string(value: dict[str, Any], key: str) -> str:
    result = value.get(key)
    if not isinstance(result, str):
        raise ValueError(f"client catalog {key} must be a string")
    return result


def _optional_int(value: dict[str, Any], key: str) -> None:
    if value.get(key) is not None:
        _required_int(value, key)


def _optional_string(value: dict[str, Any], key: str) -> None:
    if value.get(key) is not None:
        _required_string(value, key)


def _object_list(value: dict[str, Any], key: str) -> list[dict[str, Any]]:
    result = value.get(key)
    if not isinstance(result, list) or any(not isinstance(item, dict) for item in result):
        raise ValueError(f"client catalog {key} must be a list of objects")
    return result


def _validate_client_catalog(catalog: dict[str, Any]) -> None:
    # Mirror the fields consumed by sortie_map_models.dart, then enforce the
    # extra structure checked by FileSortieMapCatalogStore.
    _required_int(catalog, 'version')
    if _required_int(catalog, 'schemaVersion') != 1:
        raise ValueError('client catalog schemaVersion is unsupported')
    if _required_int(catalog, 'revision') <= 0:
        raise ValueError('client catalog revision is invalid')
    if not _required_string(catalog, 'dataVersion'):
        raise ValueError('client catalog dataVersion is empty')
    _required_string(catalog, 'source')
    for map_info in _object_list(catalog, 'maps'):
        _required_string(map_info, 'id')
        _required_string(map_info, 'nameJa')
        _required_int(map_info, 'difficulty')
        _required_string(map_info, 'coverAsset')
        _required_string(map_info, 'mapAsset')
        _optional_string(map_info, 'source')
        ratio = map_info.get('mapAspectRatio')
        if ratio is not None and (isinstance(ratio, bool) or not isinstance(ratio, (int, float)) or not math.isfinite(ratio)):
            raise ValueError('client catalog mapAspectRatio is invalid')
        points: set[str] = set()
        for node in _object_list(map_info, 'nodes'):
            point = _required_string(node, 'point')
            if point in points:
                raise ValueError(f'duplicate node point: {point}')
            points.add(point)
            for key in ('kind', 'typeLabel', 'battleTypeLabel'):
                _required_string(node, key)
            for key in ('nameJa', 'reward'):
                _optional_string(node, key)
            for formation in _object_list(node, 'formations'):
                _required_int(formation, 'variant')
                for key in ('experience', 'airPower', 'airSuperiority', 'airSupremacy'):
                    _optional_int(formation, key)
                for key in ('formation', 'note'):
                    _optional_string(formation, key)
                groups = formation.get('fleetGroups')
                if not isinstance(groups, list) or any(not isinstance(group, list) for group in groups):
                    raise ValueError('client catalog fleetGroups must be nested lists')
                for group in groups:
                    for ship in group:
                        if not isinstance(ship, dict):
                            raise ValueError('client catalog fleetGroups ship must be an object')
                        _required_int(ship, 'id')
                        _required_string(ship, 'nameJa')
                        _optional_string(ship, 'nameZh')


def _logical_image_path(value: Any, kind: str, map_id: str) -> str:
    expected = f"{ASSET_PREFIX}{kind}/{map_id}.png"
    if value != expected:
        raise ValueError(f"unexpected {kind} image reference for {map_id}: {value!r}")
    return f"{kind}/{map_id}.png"


def _validate_png(raw: bytes, logical: str) -> None:
    try:
        from io import BytesIO
        with Image.open(BytesIO(raw)) as opened:
            width, height = opened.size
            if opened.format != 'PNG' or not (0 < width <= 4096 and 0 < height <= 4096) or width * height > 8_000_000:
                raise ValueError(f"invalid PNG dimensions or format: {logical}")
            opened.verify()
    except (UnidentifiedImageError, OSError, SyntaxError) as error:
        raise ValueError(f"invalid PNG image: {logical}") from error


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
    data_version = str(catalog["dataVersion"])
    archive_name = f"sortie-data-{data_version}.zip"
    archive_tag = f"sortie-data-{data_version}"
    if not _SAFE_TOKEN.fullmatch(archive_tag) or not _SAFE_FILE.fullmatch(archive_name):
        raise ValueError("dataVersion cannot form a safe client release identifier")
    if not _VERSION.fullmatch(minimum_app_version):
        raise ValueError("minimumAppVersion is invalid")
    if not catalog['maps']:
        raise ValueError('catalog has no maps')
    archived = deepcopy(catalog)
    entries: dict[str, bytes] = {}
    node_count = 0
    formation_count = 0
    map_ids: set[str] = set()

    for map_info in archived["maps"]:
        if not isinstance(map_info, dict):
            raise ValueError("catalog maps must be objects")
        map_id = str(map_info.get("id") or "")
        if not _SAFE_MAP_ID.fullmatch(map_id):
            raise ValueError(f"catalog map id is invalid: {map_id}")
        if map_id in map_ids:
            raise ValueError(f"duplicate map id: {map_id}")
        map_ids.add(map_id)
        cover = _logical_image_path(map_info.get("coverAsset"), "covers", map_id)
        route = _logical_image_path(map_info.get("mapAsset"), "maps", map_id)
        map_info["coverAsset"] = cover
        map_info["mapAsset"] = route
        for logical in (cover, route):
            source = assets_root / "images" / "sortie_maps" / Path(logical)
            if not source.is_file():
                raise ValueError(f"catalog image is missing: {logical}")
            raw = source.read_bytes()
            _validate_png(raw, logical)
            entries[logical] = raw
        nodes = map_info.get("nodes")
        if not isinstance(nodes, list):
            raise ValueError(f"catalog nodes are invalid for {map_id}")
        node_count += len(nodes)
        for node in nodes:
            formations = node.get("formations") if isinstance(node, dict) else None
            if not isinstance(formations, list):
                raise ValueError(f"catalog formations are invalid for {map_id}")
            formation_count += len(formations)

    if node_count <= 0:
        raise ValueError('catalog node count must be positive')

    catalog_bytes = (
        json.dumps(archived, ensure_ascii=False, allow_nan=False, separators=(",", ":")) + "\n"
    ).encode("utf-8")
    entries["sortie_map_catalog.json"] = catalog_bytes
    if len(entries) > MAX_FILES:
        raise ValueError('archive file count exceeds client limit')
    if sum(map(len, entries.values())) > MAX_UNCOMPRESSED_BYTES:
        raise ValueError('archive uncompressed size exceeds client limit')

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
    if temporary_archive.stat().st_size > MAX_ARCHIVE_BYTES:
        temporary_archive.unlink()
        raise ValueError('archive size exceeds client limit')
    archive_bytes = temporary_archive.read_bytes()
    manifest = {
        "schemaVersion": 1,
        "dataVersion": data_version,
        "revision": int(catalog["revision"]),
        "publishedAt": str(catalog["publishedAt"]),
        "minimumAppVersion": minimum_app_version,
        "archive": {
            "tag": archive_tag,
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
    manifest_bytes = (json.dumps(manifest, ensure_ascii=False, allow_nan=False, indent=2) + "\n").encode('utf-8')
    try:
        if len(manifest_bytes) > MAX_MANIFEST_BYTES:
            raise ValueError('manifest size exceeds client limit')
        if manifest_path.exists():
            previous = json.loads(
                manifest_path.read_text(encoding='utf-8'),
                parse_constant=_reject_nonstandard_json,
            )
            old_archive = previous['archive']
            if old_archive['sha256'] != manifest['archive']['sha256']:
                if manifest['revision'] <= previous['revision']:
                    raise ValueError('changed archive requires a higher revision')
                if archive_tag == old_archive['tag']:
                    raise ValueError('changed archive requires a new tag')
        os.replace(temporary_archive, archive_path)
        _atomic_write(manifest_path, manifest_bytes)
    finally:
        if temporary_archive.exists():
            temporary_archive.unlink()
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
