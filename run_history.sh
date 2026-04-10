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

# Read commits oldest-first
SHAS=()
MSGS=()
i=0
while IFS='|' read -r sha msg; do
    SHAS[$i]="$sha"
    MSGS[$i]="$msg"
    ((i++))
done < <(git log --reverse --format="%h|%s")

echo ""
echo -e "${BOLD}  Historical CI Runs${NC}  ${DIM}(oldest → most recent)${NC}"
echo ""

# Header
printf "  %-9s  %-38s  │  %-8s  %-10s  %-13s  %-16s  %-13s\n" \
    "SHA" "Commit" "lint" "unit_tests" "bedrock_tests" "regression_tests" "security_scan"
printf "  %s\n" "─────────────────────────────────────────────────────────────────────────────────────────────────────────────────────"

# Pass/fail state at each commit index (0-based, oldest first)
# P=pass  F=fail  N=n/a
#
#   idx 0  Initial commit — only infra, no source to lint yet
#   idx 1  Router added (max_retries=3) — lint fails (mypy errors), regression passes
#   idx 2  Bedrock tests added with claude-v1 — bedrock starts failing
#   idx 3  Secure CI config added — security passes
#   idx 4  BAD COMMIT: max_retries changed to 1 — regression starts failing
#   idx 5  Insecure CI config (pypi-publish on pr_tests) — security fails again
#   idx 6  Syntax error test added — unit_tests fails
#   idx 7  Deps update — no change
#   idx 8  .gitignore + build script — no change

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
    "F F F F F"
)

render_cell() {
    # Prints a fixed-width colored cell WITHOUT relying on printf width for color
    # $1 = state (P/F/N), $2 = column width
    local state=$1
    local width=$2
    local text color
    case "$state" in
        P) text="✓ pass"; color="$GREEN" ;;
        F) text="✗ fail"; color="$RED"   ;;
        N) text="── n/a"; color="$DIM"   ;;
    esac
    # Print colored text, then pad with spaces to reach width
    local textlen=${#text}
    local pad=$(( width - textlen ))
    printf "%b%s%b" "$color" "$text" "$NC"
    printf "%${pad}s" ""
}

for idx in "${!SHAS[@]}"; do
    sha="${SHAS[$idx]}"
    msg="${MSGS[$idx]}"
    state="${STATES[$idx]}"

    read -r lint unit bedrock regression security <<< "$state"

    short_msg="${msg:0:36}"
    [ "${#msg}" -gt 36 ] && short_msg="${msg:0:35}…"

    # Flag the bad commit
    marker=""
    if echo "$msg" | grep -qi "router config cleanup"; then
        marker="  ${RED}← regression introduced here${NC}"
    fi

    printf "  %-9s  %-38s  │  " "$sha" "$short_msg"
    render_cell "$lint"       10
    printf "  "
    render_cell "$unit"       12
    printf "  "
    render_cell "$bedrock"    15
    printf "  "
    render_cell "$regression" 18
    printf "  "
    render_cell "$security"   13
    printf "%b\n" "$marker"
done

echo ""
echo -e "  ${DIM}Tip: find the commit where 'regression_tests' flipped from ✓ to ✗."
echo -e "       Then: git bisect start && git bisect bad && git bisect good <sha-before-flip>${NC}"
echo ""
