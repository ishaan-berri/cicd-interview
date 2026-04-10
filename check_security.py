#!/usr/bin/env python3
"""
Security scanner for CircleCI config.
Checks that jobs triggered by fork PRs don't have access to publish secrets.
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

        for job_entry in wf.get("jobs", []):
            if not isinstance(job_entry, dict):
                continue
            for job_name, job_cfg in job_entry.items():
                if job_name != "pr_tests":
                    continue
                if not isinstance(job_cfg, dict):
                    job_cfg = {}
                contexts = job_cfg.get("context", [])
                if isinstance(contexts, str):
                    contexts = [contexts]
                if "pypi-publish" in contexts:
                    issues.append(
                        f"FAIL: pr_tests has access to PYPI_TOKEN\n"
                        f"\n"
                        f"  {config_path}:\n"
                        f"\n"
                        f"      - pr_tests:\n"
                        f"          context:\n"
                        f"            - pypi-publish    ← remove this\n"
                        f"\n"
                        f"  pr_tests runs on every pull request, including PRs from\n"
                        f"  untrusted forks. Any job with the pypi-publish context\n"
                        f"  can read PYPI_TOKEN — even a contributor's fork.\n"
                        f"\n"
                        f"  Fix: delete the context block from pr_tests so it looks like:\n"
                        f"\n"
                        f"      - pr_tests\n"
                        f"\n"
                        f"  Only the publish job needs pypi-publish."
                    )

    return issues


if __name__ == "__main__":
    config_path = sys.argv[1] if len(sys.argv) > 1 else ".circleci/config.yml"
    issues = check_config(config_path)

    if issues:
        print("Security scan FAILED\n")
        for issue in issues:
            print(issue)
            print()
        sys.exit(1)

    print("Security scan passed.")
    sys.exit(0)
