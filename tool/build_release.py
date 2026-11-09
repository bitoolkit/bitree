import argparse
import json
import os
import platform
import shutil
import subprocess
import tarfile
from datetime import datetime, timezone
from pathlib import Path


def run(program, *arguments):
    subprocess.run([program, *arguments], check=True)


def build_flutter(target, flags, *arguments):
    run(
        "flutter",
        "build",
        target,
        f"--split-debug-info=build/symbols/{target}",
        *arguments,
        *flags,
    )


def build_android(flags, prefix):
    suffix = "" if Path("android/key.properties").exists() else "-debug-signed"

    build_flutter("apk", flags, "--split-per-abi", "--target-platform=android-arm64")
    shutil.copy2(
        "build/app/outputs/flutter-apk/app-arm64-v8a-release.apk",
        f"dist/{prefix}-android-arm64-v8a{suffix}.apk",
    )

    build_flutter("appbundle", flags, "--target-platform=android-arm64")
    shutil.copy2(
        "build/app/outputs/bundle/release/app-release.aab",
        f"dist/{prefix}-android{suffix}.aab",
    )


def build_linux(flags, prefix):
    architecture = {"x86_64": "x64", "aarch64": "arm64"}[platform.machine()]
    build_flutter("linux", flags, f"--target-platform=linux-{architecture}")
    with tarfile.open(
        f"dist/{prefix}-linux-{architecture}.tar.xz", "w:xz", preset=9
    ) as archive:
        archive.add(f"build/linux/{architecture}/release/bundle", arcname="BITree")
    return architecture


def build_windows(flags, prefix, native_version):
    build_flutter("windows", flags)
    run(
        "iscc",
        f"/DAppVersion={native_version}",
        f"/DOutputName={prefix}-windows-x64-setup-unsigned",
        "windows/installer.iss",
    )


def build_macos(flags, prefix):
    run("flutter", "config", "--no-enable-macos-arm64-only")
    build_flutter("macos", flags)
    app = Path("build/macos/Build/Products/Release/BITree.app")
    run(
        "ditto",
        "-c",
        "-k",
        "--zlibCompressionLevel",
        "9",
        "--sequesterRsrc",
        "--keepParent",
        str(app),
        f"dist/{prefix}-macos-universal-unsigned.zip",
    )


def build_ios(flags, prefix):
    build_flutter("ios", flags, "--no-codesign")
    payload = Path("build/unsigned-ipa/Payload")
    payload.mkdir(parents=True, exist_ok=True)
    shutil.copytree(
        "build/ios/iphoneos/Runner.app",
        payload / "Runner.app",
        dirs_exist_ok=True,
        symlinks=True,
    )
    run(
        "ditto",
        "-c",
        "-k",
        "--zlibCompressionLevel",
        "9",
        "--keepParent",
        str(payload),
        f"dist/{prefix}-ios-arm64-unsigned.ipa",
    )


def main():
    os.chdir(Path(__file__).resolve().parent.parent)
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "platform", choices=["android", "linux", "windows", "macos", "ios"]
    )
    parser.add_argument("--version", required=True)
    parser.add_argument("--native-version", required=True)
    parser.add_argument("--build-number", required=True)
    args = parser.parse_args()

    Path("dist").mkdir(exist_ok=True)
    built_at = datetime.now(timezone.utc).isoformat()
    flags = [
        "--release",
        "--no-pub",
        f"--build-name={args.native_version}",
        f"--build-number={args.build_number}",
        f"--dart-define=BITREE_VERSION={args.version}",
        f"--dart-define=BITREE_BUILD_TIME={built_at}",
    ]
    prefix = f"BITree-{args.version}"
    metadata_platform = args.platform

    match args.platform:
        case "android":
            build_android(flags, prefix)
        case "linux":
            if build_linux(flags, prefix) == "arm64":
                metadata_platform = "linux-arm64"
        case "windows":
            build_windows(flags, prefix, args.native_version)
        case "macos":
            build_macos(flags, prefix)
        case "ios":
            build_ios(flags, prefix)

    Path(f"dist/{prefix}-{metadata_platform}-update.json").write_text(
        json.dumps({"version": args.version, "builtAt": built_at}) + "\n",
        encoding="utf-8",
    )


if __name__ == "__main__":
    main()
