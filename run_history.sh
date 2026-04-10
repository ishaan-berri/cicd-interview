#!/bin/bash
# Shows simulated historical CI run results for this repo.
# Each row is one pipeline run tied to a commit, showing which jobs passed/failed.
# Use this to identify which commit introduced a regression.
#
# Usage: ./run_history.sh

BOLD='\033[1m'
DIM='\033[2m'
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass="${GREEN}✓ pass${NC}"
fail="${RED}✗ fail${NC}"
na="${DIM}── n/a${NC}"

# Read commits oldest-first using --reverse
mapfile_compat() {
    # portable replacement for mapfile (bash 3 compatible)
    local arr_name=$1; shift
    local i=0
    while IFS= read -r line; do
        eval "${arr_name}[$i]=\"\$line\""
        ((i++))
    done
}

SHAS=()
MSGS=()
i=0
while IFS='|' read -r sha msg; do
    SHAS[$i]="$sha"
    MSGS[$i]="$msg"
    ((i++))
done < <(git log --reverse --format="%h|%s")

echo ""
echo -e "${BOLD}  Historical CI Runs${NC}  ${DIM}(oldest at top · most recent at bottom)${NC}"
echo ""
printf "  ${BOLD}%-8s  %-42s  %-14s  %-14s  %-14s  %-18s  %-14s${NC}\n" \
    "SHA" "Commit" "lint" "unit_tests" "bedrock_tests" "regression_tests" "security_scan"
echo "  ─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

# Pass/fail state at each commit index (0-based, oldest first)
# Fields: lint  unit_tests  bedrock_tests  regression_tests  security_scan
# Values: P=pass  F=fail  N=n/a (job/file didn't exist yet)
#
# Why each state changes:
#   idx 0  f6fc8e8  Initial commit — only infra, no source to lint yet
#   idx 1  5c7b579  Router added (max_retries=3) — lint fails (mypy errors in router.py), regression passes
#   idx 2  99d2f41  Bedrock tests added with claude-v1 — bedrock starts failing
#   idx 3  1e8b257  Secure CI config added — security passes
#   idx 4  d9f8c9f  BAD COMMIT: max_retries changed to 1 — regression starts failing  ← find this one
#   idx 5  6e84d3b  Insecure CI config (pypi-publish on pr_tests) — security fails again
#   idx 6  4325c89  Syntax error test added — unit_tests fails
#   idx 7  84b14a6  Deps update — no change
#   idx 8  048fdf0  .gitignore + build script — no change

STATES=(
    "N N N N N"
    "F N N P N"
    "F N F P N"
    "F N F P P"
    "F N F F P"
    "F N F F F"
    "F F F F F"
    "F F F F F"
    "F F F F F"
)

render() {
    case "$1" in
        P) printf "%b" "${pass}" ;;
        F) printf "%b" "${fail}" ;;
        N) printf "%b" "${na}"   ;;
    esac
}

for idx in "${!SHAS[@]}"; do
    sha="${SHAS[$idx]}"
    msg="${MSGS[$idx]}"
    state="${STATES[$idx]}"

    read -r lint unit bedrock regression security <<< "$state"

    short_msg="${msg:0:40}"
    [ "${#msg}" -gt 40 ] && short_msg="${msg:0:39}…"

    # Mark the bad commit visually
    marker=""
    if echo "$msg" | grep -q "router config cleanup"; then
        marker=" ${RED}←${NC}"
    fi

    printf "  %-8s  %-42s  " "$sha" "$short_msg"
    printf "%-24b  " "$(render "$lint")"
    printf "%-24b  " "$(render "$unit")"
    printf "%-24b  " "$(render "$bedrock")"
    printf "%-28b  " "$(render "$regression")"
    printf "%b%b\n" "$(render "$security")" "$marker"
done

echo ""
echo -e "  ${DIM}Tip: find the commit where 'regression_tests' flipped from ✓ to ✗."
echo -e "       Then: git bisect start && git bisect bad && git bisect good <sha-before-flip>${NC}"
echo ""
