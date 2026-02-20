#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$HOME/.mosaic.log"
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
CONTRIBUTIONS_FILE="$REPO_DIR/contributions.log"
CONFIG_FILE="$REPO_DIR/mosaic.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: Config file not found: $CONFIG_FILE"
    exit 1
fi
source "$CONFIG_FILE"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# --- Weekend check ---

DAY_OF_WEEK=$(date +%u)  # 6=Saturday, 7=Sunday
if [ "$WEEKEND_COMMITS" = "false" ] && [ "$DAY_OF_WEEK" -ge 6 ]; then
    log "Weekend — skipping (WEEKEND_COMMITS=false)."
    exit 0
fi

# --- Activity check ---

ROLL=$(awk "BEGIN {srand(); print rand()}")
if awk "BEGIN {exit !($ROLL >= $ACTIVITY)}"; then
    log "Activity roll $ROLL >= $ACTIVITY — skipping today."
    exit 0
fi

# --- Pre-flight checks ---

if ! command -v gh &>/dev/null; then
    log "ERROR: gh CLI is not installed. Install it with: brew install gh"
    exit 1
fi

if ! gh auth status &>/dev/null; then
    log "ERROR: gh CLI is not authenticated. Run: gh auth login"
    exit 1
fi

cd "$REPO_DIR"

if ! git remote get-url origin &>/dev/null; then
    log "ERROR: No git remote 'origin' configured."
    exit 1
fi

GIT_EMAIL="$(git config user.email || true)"
if [ -z "$GIT_EMAIL" ]; then
    log "ERROR: git user.email is not set. Run: git config user.email \"your@email.com\""
    exit 1
fi

# --- Check if repo is a fork (forks don't count toward contributions) ---

REMOTE_URL="$(git remote get-url origin)"
REPO_SLUG="$(echo "$REMOTE_URL" | sed -E 's#(.*github\.com[:/])##; s#\.git$##')"

IS_FORK=$(gh api "repos/$REPO_SLUG" --jq '.fork' 2>/dev/null || echo "unknown")
if [ "$IS_FORK" = "true" ]; then
    log "ERROR: This repo is a GitHub fork. Commits to forks do NOT count as contributions."
    log "       Create your own repo instead: gh repo create <name> --private"
    log "       Then update the remote: git remote set-url origin <new-url>"
    exit 1
fi

# --- Query today's contribution count ---

TODAY="$(date -u '+%Y-%m-%d')"
TOMORROW="$(date -u -v+1d '+%Y-%m-%d')"

log "Checking contributions for $TODAY..."

CONTRIBUTION_COUNT=$(gh api graphql -f query="
{
  viewer {
    contributionsCollection(from: \"${TODAY}T00:00:00Z\", to: \"${TOMORROW}T00:00:00Z\") {
      totalCommitContributions
    }
  }
}" --jq '.data.viewer.contributionsCollection.totalCommitContributions')

log "Current contributions today: $CONTRIBUTION_COUNT"

# --- Calculate how many commits to make ---

TARGET=$((RANDOM % (MAX_COMMITS - MIN_COMMITS + 1) + MIN_COMMITS))
NEEDED=$((TARGET - CONTRIBUTION_COUNT))

if [ "$NEEDED" -le 0 ]; then
    log "Already at target ($CONTRIBUTION_COUNT >= $TARGET). Nothing to do."
    exit 0
fi

log "Target: $TARGET | Need to add: $NEEDED commits"

# --- Generate commits ---

for i in $(seq 1 "$NEEDED"); do
    HASH=$(openssl rand -hex 4)
    echo "$(date '+%Y-%m-%d %H:%M:%S') $HASH" >> "$CONTRIBUTIONS_FILE"
    git add "$CONTRIBUTIONS_FILE"
    git commit -m "update" --quiet
done

log "Created $NEEDED commits. Pushing..."

git push --quiet

log "Done. Total contributions today: $TARGET"
