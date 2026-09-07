#[cfg(windows)]
fn build_windows() {
    let file = "src/platform/windows.cc";
    let file2 = "src/platform/windows_delete_test_cert.cc";
    cc::Build::new().file(file).file(file2).compile("windows");
    println!("cargo:rustc-link-lib=WtsApi32");
    println!("cargo:rerun-if-changed={}", file);
    println!("cargo:rerun-if-changed={}", file2);
}

#[cfg(target_os = "macos")]
fn build_mac() {
    let file = "src/platform/macos.mm";
    let mut b = cc::Build::new();
    if let Ok(os_version::OsVersion::MacOS(v)) = os_version::detect() {
        let v = v.version;
        if v.contains("10.14") {
            b.flag("-DNO_InputMonitoringAuthStatus=1");
        }
    }
    b.flag("-std=c++17").file(file).compile("macos");
    println!("cargo:rerun-if-changed={}", file);
}

#[cfg(all(windows, feature = "inline"))]
fn build_manifest() {
    use std::io::Write;
    if std::env::var("PROFILE").unwrap() == "release" {
        let mut res = winres::WindowsResource::new();
        res.set_icon("res/icon.ico")
            .set_language(winapi::um::winnt::MAKELANGID(
                winapi::um::winnt::LANG_ENGLISH,
                winapi::um::winnt::SUBLANG_ENGLISH_US,
            ))
            .set_manifest_file("res/manifest.xml");
        match res.compile() {
            Err(e) => {
                write!(std::io::stderr(), "{}", e).unwrap();
                std::process::exit(1);
            }
            Ok(_) => {}
        }
    }
}

fn install_android_deps() {
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    if target_os != "android" {
        return;
    }
    let mut target_arch = std::env::var("CARGO_CFG_TARGET_ARCH").unwrap();
    if target_arch == "x86_64" {
        target_arch = "x64".to_owned();
    } else if target_arch == "x86" {
        target_arch = "x86".to_owned();
    } else if target_arch == "aarch64" {
        target_arch = "arm64".to_owned();
    } else {
        target_arch = "arm".to_owned();
    }
    let target = format!("{}-android", target_arch);
    let vcpkg_root = std::env::var("VCPKG_ROOT").unwrap();
    let mut path: std::path::PathBuf = vcpkg_root.into();
    if let Ok(vcpkg_root) = std::env::var("VCPKG_INSTALLED_ROOT") {
        path = vcpkg_root.into();
    } else {
        path.push("installed");
    }
    path.push(target);
    println!(
        "cargo:rustc-link-search={}",
        path.join("lib").to_str().unwrap()
    );
    println!("cargo:rustc-link-lib=ndk_compat");
    println!("cargo:rustc-link-lib=oboe");
    println!("cargo:rustc-link-lib=c++");
    println!("cargo:rustc-link-lib=OpenSLES");
}

fn tag_from_pubspec() -> Option<String> {
    let s = std::fs::read_to_string("flutter/pubspec.yaml").ok()?;
    for line in s.lines() {
        let line = line.trim();
        if let Some(rest) = line.strip_prefix("version:") {
            let v = rest.trim().split('+').next()?.trim();
            if v.contains("-sc") {
                return Some(v.to_string());
            }
        }
    }
    None
}

fn stamp_release_tag() {
    println!("cargo:rerun-if-env-changed=SC_RELEASE_TAG");
    println!("cargo:rerun-if-env-changed=VERSION");
    println!("cargo:rerun-if-env-changed=GITHUB_REF_NAME");
    println!("cargo:rerun-if-changed=flutter/pubspec.yaml");
    let tag = ["SC_RELEASE_TAG", "VERSION", "GITHUB_REF_NAME"]
        .iter()
        .find_map(|k| {
            std::env::var(k).ok().and_then(|s| {
                let s = s.trim().trim_start_matches("refs/tags/").to_string();
                s.contains("-sc").then_some(s)
            })
        })
        .or_else(tag_from_pubspec)
        .unwrap_or_else(|| "1.4.9-sc19".to_string());
    println!("cargo:rustc-env=SC_STAMPED_TAG={tag}");
    let path = std::path::Path::new("src/version.rs");
    let mut body = std::fs::read_to_string(path).unwrap_or_default();
    let release_line = format!("pub const RELEASE_TAG: &str = \"{tag}\";");
    let version_line = format!("pub const VERSION: &str = \"{tag}\";");
    let mut out = String::new();
    let mut saw_release = false;
    let mut saw_version = false;
    for l in body.lines() {
        if l.starts_with("pub const RELEASE_TAG:") {
            out.push_str(&release_line);
            out.push('\n');
            saw_release = true;
        } else if l.starts_with("pub const VERSION:") {
            out.push_str(&version_line);
            out.push('\n');
            saw_version = true;
        } else {
            out.push_str(l);
            out.push('\n');
        }
    }
    if !saw_version {
        out.push_str(&version_line);
        out.push('\n');
    }
    if !saw_release {
        out.push_str(&release_line);
        out.push('\n');
    }
    let _ = std::fs::write(path, out);
}

fn main() {
    hbb_common::gen_version();
    stamp_release_tag();
    install_android_deps();
    #[cfg(all(windows, feature = "inline"))]
    build_manifest();
    #[cfg(windows)]
    build_windows();
    let target_os = std::env::var("CARGO_CFG_TARGET_OS").unwrap();
    if target_os == "macos" {
        #[cfg(target_os = "macos")]
        build_mac();
        println!("cargo:rustc-link-lib=framework=ApplicationServices");
    }
    println!("cargo:rerun-if-changed=build.rs");
}
