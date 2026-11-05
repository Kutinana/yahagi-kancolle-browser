#!/usr/bin/env python3
"""Apply the iOS-only memory-width fix to the resolved device_info_plus source.

The current upstream plugin multiplies two machine-width values into a 32-bit
natural_t. Keep this workaround tied to that exact expression, and let a future
upstream implementation take over once the narrow accumulator is removed.
"""

import json
from pathlib import Path
from urllib.parse import unquote, urlparse


def main():
    project = Path(__file__).resolve().parents[2]
    configuration = project / ".dart_tool/package_config.json"
    if not configuration.exists():
        return  # Flutter's normal preparation will explain a missing pub get.
    packages = json.loads(configuration.read_text())["packages"]
    package = next((p for p in packages if p["name"] == "device_info_plus"), None)
    if package is None:
        return
    uri = urlparse(package["rootUri"])
    if uri.scheme not in ("", "file"):
        raise SystemExit("Unsupported device_info_plus package location")
    root = Path(unquote(uri.path))
    if not root.is_absolute():
        root = configuration.parent / root
    source = root / "ios/device_info_plus/Sources/device_info_plus/FPPDeviceInfoPlusPlugin.m"
    if not source.exists():
        return  # A future plugin may replace its Objective-C implementation.
    content = source.read_text()
    old = "natural_t mem_free = vm_stat.free_count * page_size;\n    return mem_free / 1048576;"
    intermediate = "uint64_t mem_free = (uint64_t)vm_stat.free_count * page_size;\n    return mem_free / 1048576;"
    new = "uint64_t mem_free = (uint64_t)vm_stat.free_count * page_size;\n    return (int)MIN(mem_free / 1048576, (uint64_t)INT_MAX);"
    if new in content:
        return
    expected = old if old in content else intermediate
    if expected not in content:
        if "natural_t mem_free" in content:
            raise SystemExit("Review the device_info_plus iOS memory workaround: source changed")
        return
    if content.count(expected) != 1:
        raise SystemExit("Unexpected device_info_plus iOS memory implementation")
    temporary = source.with_suffix(".m.yahagi-pending")
    updated = content.replace(expected, new)
    if "#import <limits.h>" not in updated:
        updated = updated.replace("#import <mach/mach.h>", "#import <limits.h>\n#import <mach/mach.h>")
    temporary.write_text(updated)
    temporary.chmod(source.stat().st_mode)
    temporary.replace(source)


if __name__ == "__main__":
    main()
