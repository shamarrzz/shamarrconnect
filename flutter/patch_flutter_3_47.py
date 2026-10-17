#!/usr/bin/env python3
"""Adapt pinned Dart code to Flutter 3.47. The Play job is the only caller.

Desktop and bridge builds stay on Flutter 3.24 and 3.22. Those SDKs still
use DialogTheme, TabBarTheme, and the older SelectionHandler, and they can
still use FontWeight as a const map key. This script rewrites the checkout
and the pub cache after flutter pub get. It does not change pubspec.yaml.

Flutter 3.47 ThemeData.dialogTheme is DialogThemeData and tabBarTheme is
TabBarThemeData. extended_text 14.0.0 copies an older RenderParagraph
fragment that does not implement SelectionHandler.contentLength or
getSelection, added in Flutter 3.29. google_fonts 6.2.1 keeps a const map
keyed by FontWeight, which Flutter 3.41 rejects because FontWeight.== is no
longer a primitive constant operation. The same one-line change shipped in
google_fonts 6.3.2.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = ROOT / ".dart_tool" / "package_config.json"

SELECTION_ANCHOR = """    return SelectedContent(
      plainText: fullText.substring(start, end),
    );
  }

  void _didChangeSelection() {
"""
SELECTION_INSERT = """    return SelectedContent(
      plainText: fullText.substring(start, end),
    );
  }

  @override
  SelectedContentRange? getSelection() {
    if (_textSelectionStart == null || _textSelectionEnd == null) {
      return null;
    }
    return SelectedContentRange(
      startOffset: _textSelectionStart!.offset,
      endOffset: _textSelectionEnd!.offset,
    );
  }

  @override
  int get contentLength => range.end - range.start;

  void _didChangeSelection() {
"""


def resolve_root(uri):
    path = pathlib.Path(uri.removeprefix("file://"))
    if not path.is_absolute():
        path = (CONFIG.parent / path).resolve()
    return path


def package_root(name):
    data = json.loads(CONFIG.read_text())
    for package in data["packages"]:
        if package["name"] == name:
            return resolve_root(package["rootUri"])
    raise SystemExit(f"package {name} is not in {CONFIG}")


def replace_themes(path):
    text = path.read_text()
    original = text
    text = text.replace("dialogTheme: DialogTheme(", "dialogTheme: DialogThemeData(")
    text = text.replace("tabBarTheme: const TabBarTheme(", "tabBarTheme: const TabBarThemeData(")
    if "dialogTheme: DialogTheme(" in text or "tabBarTheme: const TabBarTheme(" in text:
        raise SystemExit(f"theme types were not rewritten in {path}")
    if text.count("dialogTheme: DialogThemeData(") < 2 or text.count("tabBarTheme: const TabBarThemeData(") < 2:
        raise SystemExit(f"expected both light and dark themes to use the data classes in {path}")
    if text != original:
        path.write_text(text)
        print("common.dart: DialogThemeData and TabBarThemeData")
    else:
        print("common.dart: themes already use the data classes")


def patch_selection(path):
    text = path.read_text()
    if "int get contentLength => range.end - range.start;" in text and "SelectedContentRange? getSelection()" in text:
        print("extended_text: selection methods already present")
        return
    if SELECTION_ANCHOR not in text:
        raise SystemExit(f"extended_text selection anchor was not found in {path}")
    text = text.replace(SELECTION_ANCHOR, SELECTION_INSERT, 1)
    if text.count("SelectedContentRange? getSelection()") != 1:
        raise SystemExit(f"extended_text getSelection was not added once in {path}")
    path.write_text(text)
    print("extended_text: added contentLength and getSelection")


def patch_font_weight_map(path):
    text = path.read_text()
    old = "const _fontWeightToFilenameWeightParts = {"
    new = "final _fontWeightToFilenameWeightParts = {"
    if new in text and old not in text:
        print("google_fonts: font weight map is already final")
        return
    if old not in text:
        raise SystemExit(f"google_fonts font weight map was not found in {path}")
    path.write_text(text.replace(old, new, 1))
    print("google_fonts: font weight map is no longer const")


def main():
    if not CONFIG.is_file():
        raise SystemExit(f"missing {CONFIG}; run flutter pub get first")
    replace_themes(ROOT / "lib" / "common.dart")
    extended = package_root("extended_text") / "lib/src/official/rendering/paragraph.dart"
    fonts = package_root("google_fonts") / "lib/src/google_fonts_variant.dart"
    patch_selection(extended)
    patch_font_weight_map(fonts)


if __name__ == "__main__":
    sys.exit(main())
