#!/usr/bin/env python3
"""
Patches android/app/build.gradle (generated fresh by `flutter create` in CI,
since this repo does not commit the native android/ folder) to enable Java 8+
core library desugaring, which flutter_local_notifications requires.

Reference: https://pub.dev/packages/flutter_local_notifications
  compileOptions {
      coreLibraryDesugaringEnabled true
      ...
  }
  dependencies {
      coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:2.1.4'
  }

Idempotent: safe to run multiple times, and safe whether the generated file
uses the Groovy (build.gradle) or Kotlin DSL (build.gradle.kts) template —
both are handled since the syntax used below (`coreLibraryDesugaringEnabled
true` / `coreLibraryDesugaring '...'`) is valid in both Groovy and as a
statement equivalent in Kotlin DSL is different, so this script detects the
file type and uses the correct syntax for each.
"""
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
        new_content, n = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        coreLibraryDesugaringEnabled true",
            content,
            count=1,
        )
        if n == 0:
            print("::warning::compileOptions block not found in build.gradle; "
                  "could not enable core library desugaring automatically.")
        else:
            content = new_content
            changed = True

    if "desugar_jdk_libs" not in content:
        dep_line = f"    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}'"
        # Explicit trailing "\n" so the dependency line always lands on its
        # own line even when the generated template has an empty one-liner
        # `dependencies {}` block (closing brace immediately follows).
        new_content, n = re.subn(
            r"(\ndependencies\s*\{)",
            r"\1\n" + dep_line + "\n",
            content,
            count=1,
        )
        if n == 0:
            # No existing dependencies block in the generated template — add one.
            content = content.rstrip() + f"\n\ndependencies {{\n{dep_line}\n}}\n"
        else:
            content = new_content
        changed = True

    if changed:
        path.write_text(content)
        print(f"Patched {path} for core library desugaring (Groovy DSL).")
    else:
        print(f"{path} already has core library desugaring enabled; no changes made.")


def patch_kotlin(path: Path) -> None:
    content = path.read_text()
    changed = False

    if "isCoreLibraryDesugaringEnabled" not in content:
        new_content, n = re.subn(
            r"(compileOptions\s*\{)",
            r"\1\n        isCoreLibraryDesugaringEnabled = true",
            content,
            count=1,
        )
        if n == 0:
            print("::warning::compileOptions block not found in build.gradle.kts; "
                  "could not enable core library desugaring automatically.")
        else:
            content = new_content
            changed = True

    if "desugar_jdk_libs" not in content:
        dep_line = f'    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:{DESUGAR_VERSION}")'
        new_content, n = re.subn(
            r"(\ndependencies\s*\{)",
            r"\1\n" + dep_line + "\n",
            content,
            count=1,
        )
        if n == 0:
            content = content.rstrip() + f"\n\ndependencies {{\n{dep_line}\n}}\n"
        else:
            content = new_content
        changed = True

    if changed:
        path.write_text(content)
        print(f"Patched {path} for core library desugaring (Kotlin DSL).")
    else:
        print(f"{path} already has core library desugaring enabled; no changes made.")


def main() -> int:
    if KOTLIN_PATH.exists():
        patch_kotlin(KOTLIN_PATH)
        return 0
    if GROOVY_PATH.exists():
        patch_groovy(GROOVY_PATH)
        return 0

    print("::error::Neither android/app/build.gradle nor android/app/build.gradle.kts "
          "was found. Did the 'flutter create' step run before this script?")
    return 1


if __name__ == "__main__":
    sys.exit(main())
