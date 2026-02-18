#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONTRIBUTIONS_FILE="$SCRIPT_DIR/contributions.log"

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

cd "$SCRIPT_DIR"

if ! git remote get-url origin &>/dev/null; then
    echo "ERROR: No git remote 'origin' configured."
    exit 1
fi

GIT_EMAIL="$(git config user.email || true)"
if [ -z "$GIT_EMAIL" ]; then
    echo "ERROR: git user.email is not set. Run: git config user.email \"your@email.com\""
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
    TARGET=$((RANDOM % 46))  # Random between 0 and 45

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
