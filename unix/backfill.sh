#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRIBUTIONS_FILE="$REPO_DIR/contributions.log"
CONFIG_FILE="$REPO_DIR/mosaic.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

if [ $# -ne 2 ]; then
    echo "Usage: ./backfill.sh START_DATE END_DATE"
    echo "  Dates in YYYY-MM-DD format"
    echo "  Example: ./backfill.sh 2025-03-01 2026-02-18"
    exit 1
fi

START_DATE="$1"
END_DATE="$2"

# Validate date format
if ! date -j -f "%Y-%m-%d" "$START_DATE" "+%s" &>/dev/null; then
    echo "ERROR: Invalid start date format. Use YYYY-MM-DD."
    exit 1
fi
if ! date -j -f "%Y-%m-%d" "$END_DATE" "+%s" &>/dev/null; then
    echo "ERROR: Invalid end date format. Use YYYY-MM-DD."
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "ERROR: gh CLI is not installed. Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    echo "ERROR: gh CLI is not authenticated. Run: gh auth login"
    exit 1
fi

cd "$REPO_DIR"

if ! git remote get-url origin &>/dev/null; then
    echo "ERROR: No git remote 'origin' configured."
    exit 1
fi

GIT_EMAIL="$(git config user.email || true)"
if [ -z "$GIT_EMAIL" ]; then
    echo "ERROR: git user.email is not set. Run: git config user.email \"your@email.com\""
    exit 1
fi

# --- Check if repo is a fork (forks don't count toward contributions) ---

REMOTE_URL="$(git remote get-url origin)"
REPO_SLUG="$(echo "$REMOTE_URL" | sed -E 's#(.*github\.com[:/])##; s#\.git$##')"

IS_FORK=$(gh api "repos/$REPO_SLUG" --jq '.fork' 2>/dev/null || echo "unknown")
if [ "$IS_FORK" = "true" ]; then
    echo "ERROR: This repo is a GitHub fork. Commits to forks do NOT count as contributions."
    echo "       Create your own repo instead: gh repo create <name> --private"
    echo "       Then update the remote: git remote set-url origin <new-url>"
    exit 1
fi

# Convert dates to epoch for iteration
CURRENT_EPOCH=$(date -j -f "%Y-%m-%d" "$START_DATE" "+%s")
END_EPOCH=$(date -j -f "%Y-%m-%d" "$END_DATE" "+%s")

if [ "$CURRENT_EPOCH" -gt "$END_EPOCH" ]; then
    echo "ERROR: Start date must be before end date."
    exit 1
fi

TOTAL_COMMITS=0

echo "Backfilling from $START_DATE to $END_DATE..."
echo ""

while [ "$CURRENT_EPOCH" -le "$END_EPOCH" ]; do
    CURRENT_DATE=$(date -j -f "%s" "$CURRENT_EPOCH" "+%Y-%m-%d")

    # Activity roll
    DAY_OF_WEEK=$(date -j -f "%s" "$CURRENT_EPOCH" "+%u")  # 6=Saturday, 7=Sunday
    if [ "$DAY_OF_WEEK" -ge 6 ]; then
        CURRENT_ACTIVITY="$WEEKEND_ACTIVITY"
    else
        CURRENT_ACTIVITY="$WEEKDAY_ACTIVITY"
    fi

    ROLL=$(awk -v r=$RANDOM 'BEGIN {printf "%.4f", r/32768}')
    if awk "BEGIN {exit !($ROLL >= $CURRENT_ACTIVITY)}"; then
        if [ "$DAY_OF_WEEK" -ge 6 ]; then
            echo "  $CURRENT_DATE — weekend"
        else
            echo "  $CURRENT_DATE — homeoffice"
        fi
        CURRENT_EPOCH=$((CURRENT_EPOCH + 86400))
        continue
    fi

    TARGET=$((RANDOM % (MAX_COMMITS - MIN_COMMITS + 1) + MIN_COMMITS))

    echo -n "  $CURRENT_DATE — $TARGET commits..."

    for i in $(seq 1 "$TARGET"); do
        # Random hour between 9 (9am) and 22 (10pm)
        HOUR=$((RANDOM % 14 + 9))
        MINUTE=$((RANDOM % 60))
        SECOND=$((RANDOM % 60))
        TIMESTAMP=$(printf "%s %02d:%02d:%02d" "$CURRENT_DATE" "$HOUR" "$MINUTE" "$SECOND")

        HASH=$(openssl rand -hex 4)
        echo "$TIMESTAMP $HASH" >> "$CONTRIBUTIONS_FILE"
        git add "$CONTRIBUTIONS_FILE"

        GIT_AUTHOR_DATE="$TIMESTAMP" \
        GIT_COMMITTER_DATE="$TIMESTAMP" \
        git commit -m "update" --quiet
    done

    TOTAL_COMMITS=$((TOTAL_COMMITS + TARGET))

    # Push after each day so GitHub processes them in small batches
    if [ "$TARGET" -gt 0 ]; then
        git push --quiet
        echo " done (pushed)"
    else
        echo " done (skipped)"
    fi

    # Advance to next day (86400 seconds)
    CURRENT_EPOCH=$((CURRENT_EPOCH + 86400))
done

echo ""
echo "Backfill complete: $TOTAL_COMMITS total commits"
echo "Done!"
