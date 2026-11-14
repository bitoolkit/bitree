import subprocess
import unittest
from unittest.mock import patch

from tool import build_release


class BuildReleaseTest(unittest.TestCase):
    def test_run_resolves_platform_launcher_and_preserves_arguments(self):
        for executable in (
            r"C:\Flutter SDK\bin\flutter.bat",
            "/opt/flutter/bin/flutter",
        ):
            with self.subTest(executable=executable):
                with (
                    patch.object(build_release.shutil, "which", return_value=executable) as which,
                    patch.object(build_release.subprocess, "run") as run,
                ):
                    build_release.run("flutter", "build", "windows", "--dart-define=NAME=a b")
                    which.assert_called_once_with("flutter")
                    run.assert_called_once_with(
                        [executable, "build", "windows", "--dart-define=NAME=a b"],
                        check=True,
                    )

    def test_missing_tool_keeps_subprocess_error(self):
        with (
            patch.object(build_release.shutil, "which", return_value=None),
            patch.object(build_release.subprocess, "run", side_effect=FileNotFoundError),
        ):
            with self.assertRaises(FileNotFoundError):
                build_release.run("missing-tool")

    def test_build_failure_is_not_swallowed(self):
        with (
            patch.object(build_release.shutil, "which", return_value="/opt/flutter/bin/flutter"),
            patch.object(
                build_release.subprocess,
                "run",
                side_effect=subprocess.CalledProcessError(1, "flutter"),
            ),
        ):
            with self.assertRaises(subprocess.CalledProcessError):
                build_release.run("flutter", "build", "ios", "--no-codesign")


if __name__ == "__main__":
    unittest.main()
