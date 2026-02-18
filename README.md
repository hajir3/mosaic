# mosaic

A fun little experiment in automating GitHub's contribution graph. Checks your real contribution count for the day and tops up to a random target so your squares stay green.

> **Heads up:** This is a personal hobby project built purely for fun and curiosity — not meant to deceive anyone. It artificially fills your GitHub contribution graph with auto-generated commits. It won't make you a better developer, and anyone reviewing your actual repos will see the difference. Use at your own risk and don't take your green squares too seriously.

## Prerequisites

- [GitHub CLI](https://cli.github.com/) installed and authenticated: `brew install gh && gh auth login`
- Git configured with an email that matches your GitHub account: `git config user.email "your@email.com"`
- A GitHub repo (fork of this repo) with this code pushed to it

## Setup

1. Clone (fork) this repo and set up the remote:

   ```bash
   git clone <your-private-repo-url>
   cd mosaic
   ```
2. Make sure your git email matches your GitHub account:

   ```bash
   git config user.email "your@email.com"
   ```
3. Enable **Private contributions** on your GitHub profile:
   Go to your GitHub profile > Contribution Settings > check "Private contributions"

## Daily Usage (Manual)

Run whenever you want to top up today's contributions:

```bash
./commit.sh
```

It will check your current contribution count for today via the GitHub API, pick a random target (0-45), and add only the needed commits.

## Backfill Past Dates

Fill in historical dates with commits:

```bash
./backfill.sh 2025-06-18 2026-02-18
```

This generates 0-45 commits per day across the date range with randomized timestamps (9am-11pm). GitHub's profile only shows the last ~1 year, so there's no point going further back.

## Automatic Scheduling (launchd)

Install the launchd agent to run `commit.sh` every day at 9 PM:

```bash
cp com.mosaic.daily.plist ~/Library/LaunchAgents/
launchctl load ~/Library/LaunchAgents/com.mosaic.daily.plist
```

To uninstall:

```bash
launchctl unload ~/Library/LaunchAgents/com.mosaic.daily.plist
rm ~/Library/LaunchAgents/com.mosaic.daily.plist
```

To manually trigger a run:

```bash
launchctl kickstart gui/$(id -u)/com.mosaic.daily
```

Logs are written to `~/.mosaic.log`.

## How It Works

1. Queries the GitHub GraphQL API for today's commit contribution count
2. Picks a random target between 0 and 45
3. If current count < target, generates the difference as commits
4. Each commit appends a timestamp line to `contributions.log`
5. Pushes all new commits to the remote at once
