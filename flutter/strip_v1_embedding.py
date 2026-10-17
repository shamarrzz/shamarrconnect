#!/usr/bin/env python3
"""Drop PluginRegistry.Registrar from every Android plugin the Play build compiles.

Flutter 3.29 removed that v1 embedding type. Flutter 3.47 is what this Play
job uses. The desktop and bridge jobs stay on older Flutter, which still has
the type, so this runs only in the Play workflow after flutter pub get.
It does not change pubspec.yaml.

The sweep deletes every registerWith method whose signature takes Registrar.
That is the old registration path. The v2 FlutterPlugin methods stay.
registerWith(FlutterEngine) is the current registrant and is left alone.
A Registrar-only import is removed. import PluginRegistry stays when the
file still uses another type on it, such as NewIntentListener.

file_picker 5.5.0 also types a setup() parameter as Registrar. The v2
activity path passed null for that parameter, so the parameter and the v1
branch go away and the v2 listeners stay.

After the sweep, any remaining PluginRegistry.Registrar fails the job
before Gradle.
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent
CONFIG = ROOT / ".dart_tool" / "package_config.json"

FILE_PICKER_IMPORT = """import io.flutter.plugin.common.PluginRegistry;
"""
FILE_PICKER_SETUP_OLD = """    private void setup(
            final BinaryMessenger messenger,
            final Application application,
            final Activity activity,
            final PluginRegistry.Registrar registrar,
            final ActivityPluginBinding activityBinding) {
"""
FILE_PICKER_SETUP_NEW = """    private void setup(
            final BinaryMessenger messenger,
            final Application application,
            final Activity activity,
            final ActivityPluginBinding activityBinding) {
"""
FILE_PICKER_BRANCH_OLD = """        this.observer = new LifeCycleObserver(activity);
        if (registrar != null) {
            // V1 embedding setup for activity listeners.
            application.registerActivityLifecycleCallbacks(this.observer);
            registrar.addActivityResultListener(this.delegate);
            registrar.addRequestPermissionsResultListener(this.delegate);
        } else {
            // V2 embedding setup for activity listeners.
            activityBinding.addActivityResultListener(this.delegate);
            activityBinding.addRequestPermissionsResultListener(this.delegate);
            this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
            this.lifecycle.addObserver(this.observer);
        }
"""
FILE_PICKER_BRANCH_NEW = """        this.observer = new LifeCycleObserver(activity);
        activityBinding.addActivityResultListener(this.delegate);
        activityBinding.addRequestPermissionsResultListener(this.delegate);
        this.lifecycle = FlutterLifecycleAdapter.getActivityLifecycle(activityBinding);
        this.lifecycle.addObserver(this.observer);
"""
FILE_PICKER_CALL_OLD = """        this.setup(
                this.pluginBinding.getBinaryMessenger(),
                (Application) this.pluginBinding.getApplicationContext(),
                this.activityBinding.getActivity(),
                null,
                this.activityBinding);
"""
FILE_PICKER_CALL_NEW = """        this.setup(
                this.pluginBinding.getBinaryMessenger(),
                (Application) this.pluginBinding.getApplicationContext(),
                this.activityBinding.getActivity(),
                this.activityBinding);
"""


def resolve_root(uri):
    path = pathlib.Path(uri.removeprefix("file://"))
    if not path.is_absolute():
        path = (CONFIG.parent / path).resolve()
    return path


def matching_brace(text, open_index):
    i = open_index + 1
    depth = 1
    n = len(text)
    while i < n:
        char = text[i]
        nxt = text[i + 1] if i + 1 < n else ""
        if char == "/" and nxt == "/":
            newline = text.find("\n", i)
            i = n if newline < 0 else newline + 1
            continue
        if char == "/" and nxt == "*":
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        if char in "\"'":
            quote = char
            i += 1
            while i < n and text[i] != quote:
                if text[i] == "\\":
                    i += 2
                    continue
                if text[i] == "\n":
                    break
                i += 1
            i += 1
            continue
        if char == "{":
            depth += 1
        elif char == "}":
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise SystemExit("unbalanced brace while removing a Registrar registerWith method")


def declaration_start(text, name_at):
    line_start = text.rfind("\n", 0, name_at) + 1
    start = line_start
    while start > 0:
        prev_end = start - 1
        prev_nl = text.rfind("\n", 0, prev_end)
        prev_start = 0 if prev_nl < 0 else prev_nl + 1
        prev = text[prev_start:start].strip()
        keep = (
            prev == ""
            or prev.startswith("@")
            or prev.startswith("*")
            or prev.startswith("/*")
            or prev.startswith("//")
            or prev.endswith("*/")
        )
        if not keep:
            break
        start = prev_start
        if prev_nl < 0:
            break
    return start


def remove_registrar_register_with(text):
    """Delete registerWith methods that take Registrar. Leave every other method."""
    while True:
        removed = False
        search_from = 0
        while True:
            pos = text.find("registerWith", search_from)
            if pos < 0:
                break
            brace = text.find("{", pos)
            if brace < 0 or "Registrar" not in text[pos:brace]:
                search_from = pos + len("registerWith")
                continue
            start = declaration_start(text, pos)
            end = matching_brace(text, brace) + 1
            if end < len(text) and text[end] == "\n":
                end += 1
            text = text[:start] + text[end:]
            removed = True
            break
        if not removed:
            return text


def remove_registrar_imports(text):
    kept = []
    for line in text.splitlines(keepends=True):
        stripped = line.strip().rstrip(";")
        if stripped == "import io.flutter.plugin.common.PluginRegistry.Registrar":
            continue
        kept.append(line)
    return "".join(kept)


def remove_empty_companions(text):
    lines = text.splitlines(keepends=True)
    out = []
    index = 0
    while index < len(lines):
        if lines[index].strip() == "companion object {":
            body = []
            cursor = index + 1
            while cursor < len(lines) and lines[cursor].strip() != "}":
                body.append(lines[cursor])
                cursor += 1
            if cursor < len(lines) and all(not line.strip() for line in body):
                index = cursor + 1
                if index < len(lines) and lines[index].strip() == "":
                    index += 1
                continue
        out.append(lines[index])
        index += 1
    return "".join(out)


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: expected text was not found")
    return text.replace(old, new, 1)


def strip_file_picker_setup(text, path):
    if "Registrar" not in text:
        return text
    if FILE_PICKER_IMPORT in text:
        text = text.replace(FILE_PICKER_IMPORT, "", 1)
    text = replace_once(text, FILE_PICKER_SETUP_OLD, FILE_PICKER_SETUP_NEW, f"{path} setup")
    text = replace_once(text, FILE_PICKER_BRANCH_OLD, FILE_PICKER_BRANCH_NEW, f"{path} v1 branch")
    text = replace_once(text, FILE_PICKER_CALL_OLD, FILE_PICKER_CALL_NEW, f"{path} setup call")
    return text


def strip_source(path):
    original = path.read_text()
    text = remove_registrar_register_with(original)
    text = remove_registrar_imports(text)
    text = remove_empty_companions(text)
    if path.name == "FilePickerPlugin.java":
        text = strip_file_picker_setup(text, path)
    if text == original:
        if "PluginRegistry.Registrar" in text:
            raise SystemExit(f"Registrar remains in {path} and it is not a registerWith method this script can remove")
        return False
    if "PluginRegistry.Registrar" in text or "Registrar" in text:
        raise SystemExit(f"Registrar remains in {path}")
    path.write_text(text)
    return True


def android_sources(root):
    android = root / "android" / "src"
    if not android.is_dir():
        return []
    return [
        source
        for source in android.rglob("*")
        if source.suffix in {".java", ".kt"} and not any(part in {"build", ".gradle"} for part in source.parts)
    ]


def main():
    if not CONFIG.is_file():
        raise SystemExit(f"missing {CONFIG}; run flutter pub get first")
    data = json.loads(CONFIG.read_text())
    changed = []
    scanned = 0
    for package in data["packages"]:
        root = resolve_root(package["rootUri"])
        for source in android_sources(root):
            scanned += 1
            if strip_source(source):
                changed.append(f"{package['name']}: {source.name}")
    leftovers = []
    for package in data["packages"]:
        root = resolve_root(package["rootUri"])
        for source in android_sources(root):
            if "PluginRegistry.Registrar" in source.read_text(errors="replace"):
                leftovers.append(f"{package['name']}: {source}")
    if leftovers:
        print("PluginRegistry.Registrar remains:", file=sys.stderr)
        for item in leftovers:
            print(item, file=sys.stderr)
        raise SystemExit(1)
    if changed:
        print("removed Registrar from:")
        for item in changed:
            print(f"  {item}")
    else:
        print("Registrar: already clear")
    print(f"scan: {scanned} Android sources, no PluginRegistry.Registrar left")


if __name__ == "__main__":
    sys.exit(main())
