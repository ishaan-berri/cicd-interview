#!/usr/bin/env python3
"""
Resilience check: ensures Bedrock model IDs are not hard-coded in test files.

When model IDs are hard-coded, a single Bedrock deprecation causes every test
that references the model to fail at the same time. Using an environment variable
means you update the model in one place (the CI config) and all tests adapt
automatically — no test files need to change.
"""
import re
import sys

# Matches any string literal that looks like a Bedrock model ID
HARDCODED_MODEL_PATTERN = re.compile(
    r'"bedrock/[^"]+"'          # e.g. "bedrock/anthropic.claude-v2"
    r'|\'bedrock/[^\']+\''      # e.g. 'bedrock/anthropic.claude-v2'
    r'|"anthropic\.claude[^"]+"'  # e.g. "anthropic.claude-v2"
    r'|"amazon\.titan[^"]+"'    # e.g. "amazon.titan-tg1-large"
)

FILES_TO_CHECK = ["tests/test_bedrock.py"]


def check_file(filepath: str) -> list:
    violations = []
    try:
        with open(filepath) as f:
            for lineno, line in enumerate(f, 1):
                for match in HARDCODED_MODEL_PATTERN.finditer(line):
                    violations.append((lineno, match.group()))
    except FileNotFoundError:
        pass
    return violations


if __name__ == "__main__":
    all_violations = []

    for filepath in FILES_TO_CHECK:
        for lineno, match in check_file(filepath):
            all_violations.append((filepath, lineno, match))

    if all_violations:
        print("FAIL: Hard-coded Bedrock model IDs detected.")
        print()
        print("  Swapping one model ID for another is a quick fix, but not a resilient one.")
        print("  When Bedrock deprecates a model again, every hard-coded reference breaks.")
        print()
        print("  Found:")
        for filepath, lineno, match in all_violations:
            print(f"    {filepath}:{lineno}  {match}")
        print()
        print("  Fix: Replace hard-coded model IDs with os.environ['BEDROCK_MODEL_ID']")
        print("       Then set the variable once in .circleci/config.yml:")
        print()
        print("         bedrock_tests:")
        print("           environment:")
        print("             BEDROCK_MODEL_ID: anthropic.claude-v2")
        print()
        print("  Next time Bedrock deprecates a model: change one line in config.yml.")
        print("  No test files need to change.")
        sys.exit(1)

    print("OK: No hard-coded Bedrock model IDs found in test files.")
    sys.exit(0)
