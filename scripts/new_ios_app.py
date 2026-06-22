#!/usr/bin/env python3
"""Scaffold a new native iOS / iPadOS SwiftUI app from the bundled AppScaffold template.

Copies the template, renames the placeholder app name and bundle identifier
throughout file names and contents, and (if XcodeGen is installed) generates a
ready-to-open .xcodeproj.

Usage:
    python3 new_ios_app.py "Aurora" \
        --bundle-id com.yourcompany.aurora \
        --dest ~/Developer/Aurora

    # Skip project generation (just produce the source tree + project.yml):
    python3 new_ios_app.py "Aurora" --no-generate

The template name "AppScaffold" and bundle id "com.example.AppScaffold" are the
placeholders that get replaced. Run `xcodegen generate` yourself later if you
edit project.yml.
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path

TEMPLATE_NAME = "AppScaffold"
TEMPLATE_BUNDLE_ID = "com.example.AppScaffold"

# Text files whose contents get token-replaced. Anything else (images, asset
# catalog binaries) is copied verbatim.
TEXT_SUFFIXES = {
    ".swift", ".plist", ".yml", ".yaml", ".md", ".json", ".pbxproj",
    ".xcscheme", ".entitlements", ".xcstrings", ".storekit", ".xcconfig",
}

SKIP_DIRS = {".git", "build", "DerivedData", ".build", ".swiftpm", "xcuserdata"}


def template_root() -> Path:
    # scripts/new_ios_app.py  ->  ../assets/templates/AppScaffold
    return (Path(__file__).resolve().parent.parent / "assets" / "templates" / TEMPLATE_NAME).resolve()


def valid_app_name(name: str) -> bool:
    # Xcode target / Swift type friendly: start with a letter, then letters/digits.
    return bool(re.fullmatch(r"[A-Za-z][A-Za-z0-9]*", name))


def replace_in_text(text: str, app_name: str, bundle_id: str) -> str:
    # Bundle id first (more specific) so it isn't mangled by the name pass.
    text = text.replace(TEMPLATE_BUNDLE_ID, bundle_id)
    text = text.replace(TEMPLATE_NAME, app_name)
    return text


def copy_and_rename(src_root: Path, dst_root: Path, app_name: str, bundle_id: str) -> None:
    for dirpath, dirnames, filenames in os.walk(src_root):
        dirnames[:] = [d for d in dirnames if d not in SKIP_DIRS]
        rel = Path(dirpath).relative_to(src_root)
        # Rename directory components containing the template name.
        rel_renamed = Path(*[p.replace(TEMPLATE_NAME, app_name) for p in rel.parts]) if rel.parts else Path()
        out_dir = dst_root / rel_renamed
        out_dir.mkdir(parents=True, exist_ok=True)
        for fn in filenames:
            src_file = Path(dirpath) / fn
            out_name = fn.replace(TEMPLATE_NAME, app_name)
            out_file = out_dir / out_name
            if src_file.suffix in TEXT_SUFFIXES:
                try:
                    content = src_file.read_text(encoding="utf-8")
                    out_file.write_text(replace_in_text(content, app_name, bundle_id), encoding="utf-8")
                    continue
                except UnicodeDecodeError:
                    pass  # fall through to binary copy
            shutil.copy2(src_file, out_file)


def main() -> int:
    parser = argparse.ArgumentParser(description="Scaffold a native iOS/iPadOS SwiftUI app from the AppScaffold template.")
    parser.add_argument("app_name", help="App / target name (letters and digits, e.g. Aurora). Becomes the Xcode target and SwiftUI App type.")
    parser.add_argument("--bundle-id", help="Bundle identifier (default: com.example.<AppName>).")
    parser.add_argument("--dest", help="Destination directory (default: ./<AppName>).")
    parser.add_argument("--no-generate", action="store_true", help="Do not run `xcodegen generate`, even if XcodeGen is installed.")
    parser.add_argument("--force", action="store_true", help="Overwrite the destination directory if it already exists.")
    args = parser.parse_args()

    app_name = args.app_name.strip()
    if not valid_app_name(app_name):
        print(f"error: app name '{app_name}' must start with a letter and contain only letters and digits (no spaces/punctuation).", file=sys.stderr)
        return 2

    bundle_id = args.bundle_id or f"com.example.{app_name}"
    src_root = template_root()
    if not src_root.is_dir():
        print(f"error: template not found at {src_root}", file=sys.stderr)
        return 1

    dst_root = Path(args.dest).expanduser().resolve() if args.dest else Path.cwd() / app_name
    if dst_root.exists():
        if not args.force:
            print(f"error: destination {dst_root} already exists (use --force to overwrite).", file=sys.stderr)
            return 1
        shutil.rmtree(dst_root)

    print(f"Scaffolding '{app_name}' (bundle id {bundle_id})\n  from: {src_root}\n  into: {dst_root}")
    copy_and_rename(src_root, dst_root, app_name, bundle_id)

    generated = False
    if not args.no_generate and shutil.which("xcodegen"):
        print("Running `xcodegen generate`...")
        result = subprocess.run(["xcodegen", "generate"], cwd=dst_root)
        generated = result.returncode == 0
        if not generated:
            print("warning: xcodegen failed; you can run it manually in the destination directory.", file=sys.stderr)

    print("\nDone. Next steps:")
    if generated:
        print(f"  open {dst_root}/{app_name}.xcodeproj")
    elif shutil.which("xcodegen"):
        print(f"  cd {dst_root} && xcodegen generate && open {app_name}.xcodeproj")
    else:
        print("  Install XcodeGen:  brew install xcodegen")
        print(f"  Then:  cd {dst_root} && xcodegen generate && open {app_name}.xcodeproj")
        print("  (Or create an iOS App project in Xcode and add the files under the app folder.)")
    print("  Select an iPhone or iPad simulator and press Run. Requires Xcode 26+ with the iOS 26 SDK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
