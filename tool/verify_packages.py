import subprocess
import sys
import tarfile
import tempfile
import zipfile
from pathlib import Path, PurePosixPath


def archive_members(path):
    if path.suffix in {".apk", ".aab", ".ipa", ".zip"}:
        with zipfile.ZipFile(path) as archive:
            return archive.namelist()
    if path.name.endswith(".tar.xz"):
        with tarfile.open(path, "r:xz") as archive:
            return archive.getnames()
    if path.suffix == ".exe":
        with tempfile.TemporaryDirectory() as temporary:
            installed = Path(temporary) / "BITree"
            subprocess.run(
                [
                    str(path),
                    "/VERYSILENT",
                    "/SUPPRESSMSGBOXES",
                    "/NORESTART",
                    "/NOICONS",
                    f"/DIR={installed}",
                ],
                check=True,
            )
            return [
                file.relative_to(installed).as_posix()
                for file in installed.rglob("*")
                if file.is_file()
            ]
    return None


def is_native_library(name):
    path = PurePosixPath(name)
    if name.endswith("/") or ".dSYM" in path.parts:
        return False
    return "bitree_lua" in path.name.lower()


def main():
    verified = 0
    for path in sorted(Path(sys.argv[1]).iterdir()):
        members = archive_members(path)
        if members is None:
            continue
        if not any(is_native_library(name) for name in members):
            raise SystemExit(f"Native Lua library is missing from {path}")
        print(f"{path.name}: native Lua library present")
        verified += 1

    if verified == 0:
        raise SystemExit("No packages found")


if __name__ == "__main__":
    main()
