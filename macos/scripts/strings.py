#!/usr/bin/env python3
"""strings.py <xaml-dir> <overrides-dir> <out-dir>

Converts the Windows string dictionaries (Localization/Strings.<lang>.xaml) into
<out-dir>/<lang>.json ({"Key": "Value"}), merging <overrides-dir>/overrides.<lang>.json
on top so macOS-specific labels replace the Windows ones (SPEC §13.4).
"""
import json
import os
import sys
import xml.etree.ElementTree as ET

LANGS = ("en", "uk", "ru")
X_KEY = "{http://schemas.microsoft.com/winfx/2006/xaml}Key"


def parse_xaml(path):
    strings = {}
    for element in ET.parse(path).getroot():
        key = element.get(X_KEY)
        if key is not None:
            strings[key] = element.text or ""
    return strings


def main(xaml_dir, overrides_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    for lang in LANGS:
        strings = parse_xaml(os.path.join(xaml_dir, f"Strings.{lang}.xaml"))
        override_path = os.path.join(overrides_dir, f"overrides.{lang}.json")
        if os.path.exists(override_path):
            with open(override_path, encoding="utf-8") as f:
                strings.update(json.load(f))
        with open(os.path.join(out_dir, f"{lang}.json"), "w", encoding="utf-8") as f:
            json.dump(strings, f, ensure_ascii=False, indent=2, sort_keys=True)
            f.write("\n")
        print(f"  {lang}.json: {len(strings)} strings")


if __name__ == "__main__":
    if len(sys.argv) != 4:
        sys.exit(__doc__)
    main(*sys.argv[1:])
