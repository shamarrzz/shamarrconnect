#!/usr/bin/env python3
"""Drop PluginRegistry.Registrar from two plugins the Play build still pins.

Flutter 3.47 removed that v1 embedding type. external_path 1.0.3 and
flutter_plugin_android_lifecycle 2.0.17 still mention it. The desktop and
bridge jobs stay on older Flutter, which still has the type, so this runs
only in the Play workflow. The lifecycle method is a no-op. The external_path
method is the old registration path; the v2 plugin entry stays.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = ROOT / ".dart_tool" / "package_config.json"

EXTERNAL_OLD = """import io.flutter.plugin.common.PluginRegistry.Registrar
"""
EXTERNAL_REGISTER = """  companion object {
  @JvmStatic
  fun registerWith(registrar: Registrar) {
    val channel = MethodChannel(registrar.messenger(), "external_path")
    channel.setMethodCallHandler(ExternalPathPlugin())
    }
  }

"""
LIFECYCLE_REGISTER = """  @SuppressWarnings("deprecation")
  public static void registerWith(
      @NonNull io.flutter.plugin.common.PluginRegistry.Registrar registrar) {
    // no-op
  }

"""


def package_root(name):
    data = json.loads(CONFIG.read_text())
    for package in data["packages"]:
        if package["name"] != name:
            continue
        uri = package["rootUri"]
        path = pathlib.Path(uri.removeprefix("file://"))
        if not path.is_absolute():
            path = (CONFIG.parent / path).resolve()
        return path
    raise SystemExit(f"package {name} is not in {CONFIG}")


def strip(path, old, label):
    text = path.read_text()
    if "PluginRegistry.Registrar" not in text and "Registrar" not in text:
        print(f"{label}: already free of Registrar")
        return
    if old not in text:
        raise SystemExit(f"{label}: Registrar is still in {path}, but the expected method was not found")
    path.write_text(text.replace(old, "", 1))
    updated = path.read_text()
    if "Registrar" in updated:
        raise SystemExit(f"{label}: Registrar remains in {path}")
    print(f"{label}: removed the v1 registration method")


def main():
    if not CONFIG.is_file():
        raise SystemExit(f"missing {CONFIG}; run flutter pub get first")
    external = package_root("external_path") / "android/src/main/kotlin/com/pinciat/external_path/ExternalPathPlugin.kt"
    lifecycle = package_root("flutter_plugin_android_lifecycle") / "android/src/main/java/io/flutter/plugins/flutter_plugin_android_lifecycle/FlutterAndroidLifecyclePlugin.java"
    text = external.read_text()
    if EXTERNAL_OLD in text:
        external.write_text(text.replace(EXTERNAL_OLD, "", 1))
    strip(external, EXTERNAL_REGISTER, "external_path")
    strip(lifecycle, LIFECYCLE_REGISTER, "flutter_plugin_android_lifecycle")


if __name__ == "__main__":
    sys.exit(main())
