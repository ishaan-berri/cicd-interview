#!/usr/bin/env python3
"""
Security scanner for CircleCI config.

Checks for patterns where secrets can be exposed to untrusted fork PRs.
Fork PRs run in the context of the target repo and can access secrets if
the workflow is not carefully structured.
"""
import sys
import yaml


def check_config(config_path: str) -> list:
    try:
        with open(config_path) as f:
            config = yaml.safe_load(f)
    except FileNotFoundError:
        return [f"Config file not found: {config_path}"]
    except yaml.YAMLError as e:
        return [f"Invalid YAML: {e}"]

    issues = []
    workflows = config.get("workflows", {})

    for wf_name, wf in workflows.items():
        if wf_name == "version" or not isinstance(wf, dict):
            continue

        jobs = wf.get("jobs", [])
        pr_tests_contexts = []
        publish_has_branch_filter = None

        for job_entry in jobs:
            if isinstance(job_entry, str):
                continue
            if not isinstance(job_entry, dict):
                continue

            for job_name, job_cfg in job_entry.items():
                if not isinstance(job_cfg, dict):
                    job_cfg = {}

                contexts = job_cfg.get("context", [])
                if isinstance(contexts, str):
                    contexts = [contexts]

                if job_name == "pr_tests":
                    pr_tests_contexts = contexts

                if job_name == "publish":
                    filters = job_cfg.get("filters", {}) or {}
                    branches = filters.get("branches", {}) or {}
                    only = branches.get("only", None)
                    publish_has_branch_filter = only in ("main", ["main"])

        # Issue 1: pr_tests must not have pypi-publish context
        if "pypi-publish" in pr_tests_contexts:
            issues.append(
                "Issue 1 — Secret exfiltration via fork PR:\n"
                "  Job 'pr_tests' has the 'pypi-publish' context.\n"
                "  This job runs on pull_request events, including PRs from untrusted forks.\n"
                "  A malicious contributor can add `echo $PYPI_TOKEN` to their fork and\n"
                "  read the secret from CI logs or an external endpoint.\n"
                "\n"
                "  Fix: Remove 'pypi-publish' from pr_tests context in the workflow.\n"
                "       Only jobs that actually publish to PyPI need this context."
            )

        # Issue 2: publish must only run on main
        if publish_has_branch_filter is False:
            issues.append(
                "Issue 2 — Publish runs on every branch:\n"
                "  Job 'publish' has no branch filter.\n"
                "  It runs on every push, including feature branches and open PRs.\n"
                "  This means incomplete packages get published to PyPI on every PR push.\n"
                "\n"
                "  Fix: Restrict 'publish' to the main branch in the workflow:\n"
                "\n"
                "    publish:\n"
                "      context:\n"
                "        - pypi-publish\n"
                "      filters:\n"
                "        branches:\n"
                "          only: main"
            )

    return issues


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else ".circleci/config.yml"
    issues = check_config(config_path)

    if issues:
        print("Security scan FAILED\n")
        for i, issue in enumerate(issues, 1):
            print(f"[{i}] {issue}")
            print()
        sys.exit(1)

    print("Security scan passed. No issues found.")
    sys.exit(0)
