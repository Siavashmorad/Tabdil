#!/usr/bin/env python3
"""Patch the generated Android app module for required release-build settings."""
import re
import sys
from pathlib import Path

DESUGAR_VERSION = "2.1.4"
GROOVY_PATH = Path("android/app/build.gradle")
KOTLIN_PATH = Path("android/app/build.gradle.kts")


def patch_groovy(path: Path) -> None:
    content = path.read_text()
    changed = False

    if "coreLibraryDesugaringEnabled" not in content:
        content, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        coreLibraryDesugaringEnabled true", content, count=1)
        if n == 0:
            raise SystemExit("compileOptions block not found in build.gradle")
        changed = True

    if "desugar_jdk_libs" not in content:
        dep_line = f"    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'"
        content, n = re.subn(r"(\ndependencies\s*\{)", r"\1\n" + dep_line + "\n", content, count=1)
        if n == 0:
            content = content.rstrip() + f"\n\ndependencies {{\n{dep_line}\n}}\n"
        changed = True

    # Avoid the runner's broken lintVitalAnalyzeRelease/D8 path for the
    # generated app. Dart analyze and the test suite remain CI gates.
    if "checkReleaseBuilds = false" not in content:
        content = content.rstrip() + "\nlint {\n    checkReleaseBuilds = false\n}\n"
        changed = True

    path.write_text(content)
    print(f"Patched {path} (desugaring + release lint compatibility). changed={changed}")


def patch_kotlin(path: Path) -> None:
    content = path.read_text()
    changed = False

    if "isCoreLibraryDesugaringEnabled" not in content:
        content, n = re.subn(r"(compileOptions\s*\{)", r"\1\n        isCoreLibraryDesugaringEnabled = true", content, count=1)
        if n == 0:
            raise SystemExit("compileOptions block not found in build.gradle.kts")
        changed = True

    if "desugar_jdk_libs" not in content:
        dep_line = f'    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}")'
        content, n = re.subn(r"(\ndependencies\s*\{)", r"\1\n" + dep_line + "\n", content, count=1)
        if n == 0:
            content = content.rstrip() + f"\n\ndependencies {{\n{dep_line}\n}}\n"
        changed = True

    if "checkReleaseBuilds = false" not in content:
        content = content.rstrip() + "\nlint {\n    checkReleaseBuilds = false\n}\n"
        changed = True

    path.write_text(content)
    print(f"Patched {path} (desugaring + release lint compatibility). changed={changed}")


def main() -> int:
    if KOTLIN_PATH.exists():
        patch_kotlin(KOTLIN_PATH)
        return 0
    if GROOVY_PATH.exists():
        patch_groovy(GROOVY_PATH)
        return 0
    print("::error::Android app Gradle file was not generated.")
    return 1


if __name__ == "__main__":
    sys.exit(main())
