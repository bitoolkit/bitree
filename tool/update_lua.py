import hashlib
import json
import shutil
import tarfile
import tempfile
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TARGET = ROOT / "packages/bitree_lua/third_party/lua"
MANIFEST = TARGET / "SOURCE.json"


def sha256(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def main():
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    version = manifest["version"]

    with tempfile.TemporaryDirectory() as temporary:
        temporary = Path(temporary)
        archive = temporary / f"lua-{version}.tar.gz"
        with urllib.request.urlopen(
            manifest["url"], timeout=60
        ) as response, archive.open("wb") as output:
            shutil.copyfileobj(response, output)

        actual = sha256(archive)
        if actual != manifest["sha256"]:
            raise SystemExit(
                f"Lua archive SHA256 mismatch: expected {manifest['sha256']}, "
                f"got {actual}"
            )

        extracted = temporary / "source"
        extracted.mkdir()
        with tarfile.open(archive, "r:gz") as package:
            package.extractall(extracted, filter="data")

        destination = TARGET / "src"
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(extracted / f"lua-{version}" / "src", destination)

    print(f"Updated vendored Lua to {version} ({manifest['sha256']}).")


if __name__ == "__main__":
    main()
