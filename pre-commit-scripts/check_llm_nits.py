#!/usr/bin/env python3
"""
Check for LLM-generated anti-patterns.

1. Broad exception catching - catch specific exceptions instead
2. pytest.skip - fix the test instead
3. Late imports - move to top or fix circular dependencies

Any # noqa must include a comment explaining why it's necessary.
"""

import os
import re
import sys
from pathlib import Path
from typing import Iterable, List, Tuple

# Regex patterns for detection
BROAD_EXCEPT_PATTERNS = [
    (re.compile(r"\bexcept\s*:"), "bare except"),
    (re.compile(r"\bexcept\s+Exception\b"), "except Exception"),
    (re.compile(r"\bexcept\s+BaseException\b"), "except BaseException"),
]

PYTEST_SKIP_PATTERN = re.compile(
    r"pytest\.skip\(|@pytest\.mark\.skip|@pytest\.mark\.skipif"
)
IMPORT_PATTERN = re.compile(r"^\s*(from|import)\s+")

NOQA_PATTERN = re.compile(r"#\s*(?i:noqa):\s*")  # case agnostic
NOQA_BLE001_PATTERN = re.compile(NOQA_PATTERN.pattern + r"BLE001")
NOQA_SKIP001_PATTERN = re.compile(NOQA_PATTERN.pattern + r"SKIP001")
NOQA_E402_PATTERN = re.compile(NOQA_PATTERN.pattern + r"E402")


def check_file(filepath: Path) -> List[Tuple[str, int, str]]:
    """
    Check a single Python file for quality issues.

    Returns list of (issue_type, line_number, message) tuples.
    """
    issues = []

    try:
        with open(filepath, "r", encoding="utf-8") as f:
            lines = f.readlines()
    except (IOError, UnicodeDecodeError):
        return issues

    is_test_file = "/tests/" in str(filepath) or str(filepath).startswith("tests/")

    for line_num, line in enumerate(lines, 1):
        # Check 1: Broad exception catching (unless noqa comment present)
        if not NOQA_BLE001_PATTERN.search(line):
            for pattern, desc in BROAD_EXCEPT_PATTERNS:
                if pattern.search(line):
                    issues.append(
                        (
                            "broad-except",
                            line_num,
                            f"Found {desc}. Don't catch exceptions, we want errors. If adding noqa, defend your decision in the code",
                        )
                    )

        # Check 2: pytest.skip usage (in test files, unless noqa comment present)
        if (
            is_test_file
            and PYTEST_SKIP_PATTERN.search(line)
            and not NOQA_SKIP001_PATTERN.search(line)
        ):
            issues.append(
                (
                    "pytest-skip",
                    line_num,
                    "Found pytest.skip. Fix the test instead. If adding noqa, defend your decision in the code",
                )
            )

        # Check 3: Late imports (after line 50, not in tests)
        # Skip if has noqa: E402 comment (legitimate deferred import)
        if (
            not is_test_file
            and line_num > 50
            and IMPORT_PATTERN.match(line)
            and not NOQA_E402_PATTERN.search(line)
        ):
            issues.append(
                (
                    "late-import",
                    line_num,
                    f"Import at line {line_num}. Move to top or refactor circular dependency. If adding noqa, defend your decision in the code",
                )
            )

    return issues


def _is_excluded_path(candidate: Path, excludes: list[Path]) -> bool:
    """Return True when candidate path should be skipped."""
    return any(candidate == subpath or candidate.is_relative_to(subpath) for subpath in excludes)


def find_python_files(
    directory: Path,
    exclude_dirs: Iterable[str] | None = None,
    exclude_subpaths: Iterable[str] | None = None,
) -> List[Path]:
    """Find all Python files in directory, excluding specified directories/subpaths."""
    if exclude_dirs is None:
        exclude_dirs = {".venv", "venv", "__pycache__", ".git", ".uv", "build", "dist"}
    else:
        exclude_dirs = set(exclude_dirs)

    exclude_path_objs = [Path(subpath) for subpath in (exclude_subpaths or [])]

    python_files = []
    base_dir = directory.resolve()

    for root, dirs, files in os.walk(directory):
        root_path = Path(root).resolve()
        rel_root = root_path.relative_to(base_dir)

        if _is_excluded_path(rel_root, exclude_path_objs):
            dirs[:] = []
            continue

        # Remove excluded directories from dirs to prevent walking into them
        dirs[:] = [
            d
            for d in dirs
            if d not in exclude_dirs
            and not _is_excluded_path(rel_root / d, exclude_path_objs)
        ]

        for file in files:
            if file.endswith(".py"):
                python_files.append(Path(root) / file)

    return python_files


def main():
    """Main entry point for the checker."""
    # Check both api and slack-sidecar directories
    check_dirs = []

    if len(sys.argv) > 1:
        # Use command line argument if provided
        check_dirs = [Path(sys.argv[1])]
    else:
        # Default: check api and slack-sidecar
        for dir_name in ["api", "slack-sidecar"]:
            dir_path = Path(dir_name)
            if dir_path.exists():
                check_dirs.append(dir_path)

    if not check_dirs:
        print("No directories to check")
        return 0

    # Find all Python files in all directories
    python_files = []
    for check_dir in check_dirs:
        subpath_excludes: list[str] = []
        if check_dir.name == "api":
            subpath_excludes.append("models/silero")

        python_files.extend(find_python_files(check_dir, exclude_subpaths=subpath_excludes))

    # Check all files and collect issues
    all_issues = []
    for filepath in python_files:
        issues = check_file(filepath)
        if issues:
            all_issues.append((filepath, issues))

    # Report issues grouped by type
    if all_issues:
        issue_types = {}
        for filepath, issues in all_issues:
            for issue_type, line_num, message in issues:
                if issue_type not in issue_types:
                    issue_types[issue_type] = []
                issue_types[issue_type].append((filepath, line_num, message))

        # Print issues by type
        exit_code = 0

        if "broad-except" in issue_types:
            print("=" * 70)
            print("BROAD EXCEPTION HANDLING ISSUES:")
            print("=" * 70)
            for filepath, line_num, message in issue_types["broad-except"]:
                print(f"{filepath}:{line_num}: {message}")
            exit_code = 1

        if "pytest-skip" in issue_types:
            print("=" * 70)
            print("PYTEST SKIP ISSUES:")
            print("=" * 70)
            for filepath, line_num, message in issue_types["pytest-skip"]:
                print(f"{filepath}:{line_num}: {message}")
            exit_code = 1

        if "late-import" in issue_types:
            print("=" * 70)
            print("LATE IMPORT ISSUES:")
            print("=" * 70)
            for filepath, line_num, message in issue_types["late-import"]:
                print(f"{filepath}:{line_num}: {message}")
            exit_code = 1

        return exit_code
    else:
        print("✓ All code quality checks passed!")
        return 0


if __name__ == "__main__":
    sys.exit(main())
