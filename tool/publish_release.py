import argparse
import hashlib
import json
import os
import re
import subprocess
from pathlib import Path

from changelog import release_notes, unreleased_notes


def gh(*arguments):
    subprocess.run(["gh", *arguments], check=True, stdout=subprocess.DEVNULL)


def github(path):
    result = subprocess.run(
        ["gh", "api", path], capture_output=True, text=True, check=False
    )
    if result.returncode == 0:
        return json.loads(result.stdout)
    if "(HTTP 404)" in result.stderr:
        return None

    raise SystemExit(result.stderr.strip())


def main():
    os.chdir(Path(__file__).resolve().parent.parent)
    parser = argparse.ArgumentParser()
    parser.add_argument("channel", choices=["dev", "release"])
    parser.add_argument("version")
    args = parser.parse_args()

    repository = os.environ["GITHUB_REPOSITORY"]
    sha = os.environ["GITHUB_SHA"]
    development = args.channel == "dev"
    tag = args.version.split("-dev.")[0] + "-dev" if development else args.version
    endpoint = f"repos/{repository}"
    existing = github(f"{endpoint}/releases/tags/{tag}")

    if development:
        stable_tag = tag.removesuffix("-dev")
        stable = github(f"{endpoint}/releases/tags/{stable_tag}")
        if (
            stable is not None
            and not stable["draft"]
            and not stable["prerelease"]
        ):
            if existing is not None:
                gh(
                    "release",
                    "delete",
                    tag,
                    "--repo",
                    repository,
                    "--cleanup-tag",
                    "--yes",
                )
            return

    assets = sorted(Path("dist").glob("BITree-*"))
    if not assets:
        raise SystemExit("没有成功构建的产物可供发布。")

    checksums = Path("dist/SHA256SUMS.txt")
    with checksums.open("w", encoding="utf-8") as output:
        for asset in assets:
            with asset.open("rb") as stream:
                digest = hashlib.file_digest(stream, "sha256").hexdigest()
            output.write(f"{digest}  {asset.name}\n")

    if (
        args.channel == "release"
        and existing is not None
        and (not existing["draft"] or existing["target_commitish"] != sha)
    ):
        raise SystemExit(f"{tag} 已发布或存在其他提交的草稿。")

    notes = Path("dist/release-notes.md")
    notes.write_text(
        unreleased_notes() if args.channel == "dev" else release_notes(tag),
        encoding="utf-8",
    )

    if existing is None:
        command = [
            "release",
            "create",
            tag,
            "--repo",
            repository,
            "--target",
            sha,
            "--draft",
            "--latest=false",
            "--title",
            f"BITree {tag}",
            "--notes-file",
            str(notes),
        ]
        if args.channel == "dev" or "-" in tag:
            command.append("--prerelease")

        gh(*command)

    gh(
        "release",
        "upload",
        tag,
        "--repo",
        repository,
        "--clobber",
        *map(str, assets),
        str(checksums),
    )

    if development:
        ref = github(f"{endpoint}/git/ref/tags/{tag}")
        if ref is not None:
            gh(
                "api",
                "--method",
                "PATCH",
                f"{endpoint}/git/refs/tags/{tag}",
                "-f",
                f"sha={sha}",
                "-F",
                "force=true",
            )

        keep = {asset.name for asset in assets} | {checksums.name}
        previous_assets = existing["assets"] if existing is not None else []
        for asset in previous_assets:
            if asset["name"] not in keep:
                gh(
                    "api",
                    "--method",
                    "DELETE",
                    f"{endpoint}/releases/assets/{asset['id']}",
                )

    latest = args.channel == "release" and "-" not in tag
    command = [
        "release",
        "edit",
        tag,
        "--repo",
        repository,
        "--draft=false",
        f"--latest={str(latest).lower()}",
        "--notes-file",
        str(notes),
    ]
    if args.channel == "dev":
        command.append("--prerelease")
    gh(*command)

    if development:
        # Publish the replacement before removing older development channels.
        for release in github(f"{endpoint}/releases?per_page=100"):
            old_tag = release["tag_name"]
            if (
                release["prerelease"]
                and old_tag != tag
                and (
                    old_tag == "dev"
                    or re.fullmatch(r"v\d+\.\d+\.\d+-dev", old_tag)
                )
            ):
                gh(
                    "release", "delete", old_tag, "--repo", repository,
                    "--cleanup-tag", "--yes",
                )
    else:
        # A release build can race the dev build triggered by the same push.
        # The dev publisher handles the opposite order by seeing this release.
        dev_tag = f"{tag}-dev"
        if github(f"{endpoint}/releases/tags/{dev_tag}") is not None:
            gh(
                "release",
                "delete",
                dev_tag,
                "--repo",
                repository,
                "--cleanup-tag",
                "--yes",
            )


if __name__ == "__main__":
    main()
