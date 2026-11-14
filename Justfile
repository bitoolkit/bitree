default:
    @just --list

deps:
    flutter pub get

devices:
    flutter devices

run device=os():
    flutter run -d {{ quote(device) }}

fmt:
    dart format lib test tool

fmt-nix:
    nixfmt devenv.nix

analyze:
    flutter analyze --no-pub

test:
    flutter test --no-pub

check: analyze test

build target=os():
    flutter build {{ quote(target) }}

apk:
    flutter build apk --release --target-platform=android-arm64 --split-per-abi

release version:
    python3 tool/release.py {{ quote(version) }}

doctor:
    flutter doctor -v

clean:
    flutter clean
