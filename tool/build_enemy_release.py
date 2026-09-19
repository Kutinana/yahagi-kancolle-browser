#!/usr/bin/env python3
"""Create the small manifest for an immutable enemy catalog release asset."""

import argparse
from datetime import datetime
import hashlib
import json
from pathlib import Path
import re


REPOSITORY = "yamatosaki/yahagi-kancolle-browser"
TAG_PATTERN = re.compile(r"^enemy-data-[A-Za-z0-9][A-Za-z0-9._-]*$")
VERSION_PATTERN = re.compile(
    r"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?$"
)


def _non_empty_string(value: object) -> bool:
    return isinstance(value, str) and bool(value.strip())


def _validate_catalog(catalog: object) -> tuple[list[dict], dict[str, str]]:
    if not isinstance(catalog, dict) or catalog.get("schemaVersion") != 1:
        raise ValueError("Enemy catalog root is invalid")
    if not all(
        _non_empty_string(catalog.get(field))
        for field in ("dataVersion", "publishedAt", "source")
    ):
        raise ValueError("Enemy catalog metadata is invalid")
    revision = catalog.get("revision")
    if isinstance(revision, bool) or not isinstance(revision, int) or revision < 1:
        raise ValueError("Enemy catalog revision is invalid")
    try:
        datetime.fromisoformat(catalog["publishedAt"].replace("Z", "+00:00"))
    except ValueError as error:
        raise ValueError("Enemy catalog timestamp is invalid") from error
    ships = catalog.get("ships")
    aliases = catalog.get("aliases")
    if (
        not isinstance(ships, list)
        or not ships
        or not isinstance(aliases, dict)
        or not aliases
        or not isinstance(catalog.get("quality"), dict)
    ):
        raise ValueError("Enemy catalog collections are invalid")
    keys: set[str] = set()
    for ship in ships:
        if not isinstance(ship, dict):
            raise ValueError("Enemy catalog ship is invalid")
        key, ship_id, name, equipment = (
            ship.get("key"), ship.get("id"), ship.get("name"), ship.get("equipment")
        )
        if (
            not _non_empty_string(key)
            or key in keys
            or isinstance(ship_id, bool)
            or not isinstance(ship_id, int)
            or ship_id < 1
            or not _non_empty_string(name)
            or not isinstance(equipment, list)
        ):
            raise ValueError("Enemy catalog ship fields are invalid")
        keys.add(key)
        slots: set[int] = set()
        for item in equipment:
            if not isinstance(item, dict):
                raise ValueError("Enemy catalog equipment is invalid")
            slot = item.get("slot")
            if (
                isinstance(slot, bool)
                or not isinstance(slot, int)
                or slot < 1
                or slot > 5
                or slot in slots
                or not _non_empty_string(item.get("name"))
                or not isinstance(item.get("matched"), bool)
                or (
                    item.get("stats") is not None
                    and not isinstance(item.get("stats"), dict)
                )
            ):
                raise ValueError("Enemy catalog equipment fields are invalid")
            slots.add(slot)
    if not all(
        _non_empty_string(alias)
        and _non_empty_string(target)
        and target in keys
        for alias, target in aliases.items()
    ):
        raise ValueError("Enemy catalog aliases are invalid")
    return ships, aliases


def build_release(
    catalog_path: Path,
    manifest_path: Path,
    *,
    tag: str,
    minimum_app_version: str = "1.0.8-beta.2",
) -> dict[str, object]:
    if not TAG_PATTERN.fullmatch(tag):
        raise ValueError("Enemy release tag is invalid")
    if not VERSION_PATTERN.fullmatch(minimum_app_version):
        raise ValueError("Minimum app version is invalid")
    raw = catalog_path.read_bytes()
    catalog = json.loads(raw.decode("utf-8"))
    ships, aliases = _validate_catalog(catalog)
    digest = hashlib.sha256(raw).hexdigest()
    manifest = {
        "schemaVersion": 1,
        "dataVersion": catalog["dataVersion"],
        "revision": catalog["revision"],
        "publishedAt": catalog["publishedAt"],
        "minimumAppVersion": minimum_app_version,
        "dataUrl": f"https://github.com/{REPOSITORY}/releases/download/{tag}/enemy_catalog.json",
        "dataBytes": len(raw),
        "dataSha256": digest,
        "shipCount": len(ships),
        "aliasCount": len(aliases),
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    manifest_path.write_text(
        json.dumps(manifest, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    return {"sha256": digest, "bytes": len(raw), "manifest": manifest}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("catalog", type=Path)
    parser.add_argument("manifest", type=Path)
    parser.add_argument("--tag", required=True)
    parser.add_argument("--minimum-app-version", default="1.0.8-beta.2")
    args = parser.parse_args()
    print(json.dumps(build_release(
        args.catalog,
        args.manifest,
        tag=args.tag,
        minimum_app_version=args.minimum_app_version,
    ), ensure_ascii=False))


if __name__ == "__main__":
    main()
