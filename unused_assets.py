#!/usr/bin/env python3
import os
import re
import sys

PROJECT_ROOT = "./Mixin"
STRINGS_FILE = "./Mixin/Resources/en.lproj/Localizable.strings"
ASSETS_DIR = "./Mixin/Assets.xcassets"
COLORS_DIR = "./Mixin/Colors.xcassets"

# File types to scan for usage
SCAN_EXTENSIONS = {
    ".swift", ".m", ".mm", ".h", ".c", ".cpp",
    ".xib", ".storyboard", ".plist"
}

STRING_KEY_REGEX = re.compile(r'"([^"]+)"\s*=')


def read_all_project_text():
    """Read all text content of project files into one big string"""
    buffer = []
    for root, _, files in os.walk(PROJECT_ROOT):
        for f in files:
            ext = os.path.splitext(f)[1].lower()
            if ext in SCAN_EXTENSIONS:
                path = os.path.join(root, f)
                try:
                    with open(path, "r", encoding="utf-8", errors="ignore") as fp:
                        buffer.append(fp.read())
                except Exception:
                    pass
    return "\n".join(buffer)


def load_localizable_keys(strings_path):
    keys = set()
    with open(strings_path, "r", encoding="utf-8") as f:
        for line in f:
            m = STRING_KEY_REGEX.search(line)
            if m:
                keys.add(m.group(1))
    return keys


def find_unused_strings(keys, project_text):
    unused = []
    for k in keys:
        # simple substring match (fast & robust)
        if k not in project_text:
            unused.append(k)
    return unused


def load_imageset_names(assets_dir):
    names = set()
    for item in os.listdir(assets_dir):
        if item.endswith(".imageset"):
            name = item.replace(".imageset", "")
            names.add(name)
    return names

def load_colorset_names(assets_dir):
    names = set()
    for item in os.listdir(assets_dir):
        if item.endswith(".colorset"):
            name = item.replace(".colorset", "")
            names.add(name)
    return names

def find_unused_assets(asset_names, project_text):
    unused = []
    for name in asset_names:
        if name not in project_text:
            unused.append(name)
    return unused


def main():
    print("🔍 Scanning project:", PROJECT_ROOT)
    print("")

    project_text = read_all_project_text()

    # -------- Strings --------
    if not os.path.exists(STRINGS_FILE):
        print("❌ Localizable.strings not found:", STRINGS_FILE)
        sys.exit(1)

    keys = load_localizable_keys(STRINGS_FILE)
    unused_strings = find_unused_strings(keys, project_text)

    # -------- Assets --------
    if not os.path.exists(ASSETS_DIR):
        print("❌ Assets.xcassets not found:", ASSETS_DIR)
        sys.exit(1)

    asset_names = load_imageset_names(ASSETS_DIR)
    unused_assets = find_unused_assets(asset_names, project_text)

    # -------- Colors --------
    if not os.path.exists(COLORS_DIR):
        print("❌ Colors.xcassets not found:", COLORS_DIR)
        sys.exit(1)

    color_names = load_colorset_names(COLORS_DIR)
    unused_colors = find_unused_assets(color_names, project_text)

    # -------- Output --------
    print("========== UNUSED Localizable.strings KEYS ==========")
    if unused_strings:
        for k in unused_strings:
            print(k)
    else:
        print("None 🎉")

    print("")
    print("========== UNUSED IMAGE ASSETS ==========")
    if unused_assets:
        for a in unused_assets:
            print(a)
    else:
        print("None 🎉")

    print("")
    print("========== UNUSED COLOR ASSETS ==========")
    if unused_colors:
        for c in unused_colors:
            print(c)
    else:
        print("None 🎉")

    print("")
    print("Summary:")
    print(f"  Total strings: {len(keys)}, Unused: {len(unused_strings)}")
    print(f"  Total images : {len(asset_names)}, Unused: {len(unused_assets)}")
    print(f"  Total colors : {len(color_names)}, Unused: {len(unused_colors)}")


if __name__ == "__main__":
    main()