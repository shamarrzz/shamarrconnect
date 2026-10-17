#!/usr/bin/env python3
"""Drop PluginRegistry.Registrar from plugins the Play build still pins.

Flutter 3.47 removed that v1 embedding type. The desktop and bridge jobs
stay on older Flutter, which still has the type, so this runs only in the
Play workflow after flutter pub get. It does not change pubspec.yaml.

external_path 1.0.3 and flutter_plugin_android_lifecycle 2.0.17 only need
their old registration methods removed. The lifecycle method is a no-op.
file_picker 5.5.0 also types a setup() parameter as Registrar. The v2
activity path already passed null for that parameter, so the parameter and
the v1 branch go away and the v2 listeners stay. sqflite 2.2.0 has a
registration method that is not on the v2 path.

After those edits, every resolved package is scanned. A remaining
PluginRegistry.Registrar fails the job before Gradle spends several minutes
compiling it.
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
FILE_PICKER_IMPORT = """import io.flutter.plugin.common.PluginRegistry;
"""
FILE_PICKER_REGISTER = """    /**
     * Plugin registration.
     */
    public static void registerWith(final io.flutter.plugin.common.PluginRegistry.Registrar registrar) {

        if (registrar.activity() == null) {
            // If a background flutter view tries to register the plugin, there will be no activity from the registrar,
            // we stop the registering process immediately because the ImagePicker requires an activity.
            return;
        }

        final Activity activity = registrar.activity();
        Application application = null;
        if (registrar.context() != null) {
            application = (Application) (registrar.context().getApplicationContext());
        }

        final FilePickerPlugin plugin = new FilePickerPlugin();
        plugin.setup(registrar.messenger(), application, activity, registrar, null);

    }

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
SQFLITE_REGISTER = """    @SuppressWarnings("deprecation")
    public static void registerWith(io.flutter.plugin.common.PluginRegistry.Registrar registrar) {
        SqflitePlugin sqflitePlugin = new SqflitePlugin();
        sqflitePlugin.onAttachedToEngine(registrar.context(), registrar.messenger());
    }

"""


def package_root(name):
    data = json.loads(CONFIG.read_text())
    for package in data["packages"]:
        if package["name"] != name:
            continue
        return resolve_root(package["rootUri"])
    raise SystemExit(f"package {name} is not in {CONFIG}")


def resolve_root(uri):
    path = pathlib.Path(uri.removeprefix("file://"))
    if not path.is_absolute():
        path = (CONFIG.parent / path).resolve()
    return path


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


def replace_once(text, old, new, label):
    if old not in text:
        raise SystemExit(f"{label}: expected text was not found")
    return text.replace(old, new, 1)


def strip_file_picker(path):
    text = path.read_text()
    if "PluginRegistry.Registrar" not in text and "Registrar" not in text:
        print("file_picker: already free of Registrar")
        return
    text = replace_once(text, FILE_PICKER_IMPORT, "", "file_picker import")
    text = replace_once(text, FILE_PICKER_REGISTER, "", "file_picker registerWith")
    text = replace_once(text, FILE_PICKER_SETUP_OLD, FILE_PICKER_SETUP_NEW, "file_picker setup")
    text = replace_once(text, FILE_PICKER_BRANCH_OLD, FILE_PICKER_BRANCH_NEW, "file_picker v1 branch")
    text = replace_once(text, FILE_PICKER_CALL_OLD, FILE_PICKER_CALL_NEW, "file_picker setup call")
    if "Registrar" in text or "PluginRegistry" in text:
        raise SystemExit(f"file_picker: Registrar remains in {path}")
    path.write_text(text)
    print("file_picker: removed the v1 registration path")


def scan():
    leftovers = []
    data = json.loads(CONFIG.read_text())
    for package in data["packages"]:
        root = resolve_root(package["rootUri"])
        android = root / "android" / "src"
        if not android.is_dir():
            continue
        for source in android.rglob("*"):
            if source.suffix not in {".java", ".kt"}:
                continue
            if "PluginRegistry.Registrar" in source.read_text(errors="replace"):
                leftovers.append(f"{package['name']}: {source}")
    if leftovers:
        print("PluginRegistry.Registrar remains:", file=sys.stderr)
        for item in leftovers:
            print(item, file=sys.stderr)
        raise SystemExit(1)
    print("scan: no PluginRegistry.Registrar left in resolved Android sources")


def main():
    if not CONFIG.is_file():
        raise SystemExit(f"missing {CONFIG}; run flutter pub get first")
    external = package_root("external_path") / "android/src/main/kotlin/com/pinciat/external_path/ExternalPathPlugin.kt"
    lifecycle = package_root("flutter_plugin_android_lifecycle") / "android/src/main/java/io/flutter/plugins/flutter_plugin_android_lifecycle/FlutterAndroidLifecyclePlugin.java"
    picker = package_root("file_picker") / "android/src/main/java/com/mr/flutter/plugin/filepicker/FilePickerPlugin.java"
    sqflite = package_root("sqflite") / "android/src/main/java/com/tekartik/sqflite/SqflitePlugin.java"
    text = external.read_text()
    if EXTERNAL_OLD in text:
        external.write_text(text.replace(EXTERNAL_OLD, "", 1))
    strip(external, EXTERNAL_REGISTER, "external_path")
    strip(lifecycle, LIFECYCLE_REGISTER, "flutter_plugin_android_lifecycle")
    strip_file_picker(picker)
    strip(sqflite, SQFLITE_REGISTER, "sqflite")
    scan()


if __name__ == "__main__":
    sys.exit(main())
