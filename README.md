# mosaic

A fun little experiment in automating GitHub's contribution graph. Checks your real contribution count for the day and tops up to a random target so your squares stay green.

> **Heads up:** This is a personal hobby project built purely for fun and curiosity — not meant to deceive anyone. It artificially fills your GitHub contribution graph with auto-generated commits. It won't make you a better developer, and anyone reviewing your actual repos will see the difference. Use at your own risk and don't take your green squares too seriously.

## Project Structure

```
mosaic/
├── unix/                  # macOS / Linux scripts
│   ├── commit.sh          # Daily commit script
│   ├── backfill.sh        # Backfill historical dates
│   └── com.mosaic.daily.plist  # macOS launchd schedule
├── win/                   # Windows scripts
│   ├── commit.ps1         # Daily commit script (PowerShell)
│   ├── backfill.ps1       # Backfill historical dates (PowerShell)
│   ├── mosaic-daily.xml   # Task Scheduler XML template
│   └── install-task.ps1   # One-click Task Scheduler setup
├── contributions.log      # Auto-generated commit log
└── README.md
```

## Prerequisites

### macOS / Linux

- [GitHub CLI](https://cli.github.com/) installed and authenticated: `brew install gh && gh auth login`
- Git configured with an email that matches your GitHub account: `git config user.email "your@email.com"`
- A GitHub repo with this code pushed to it

### Windows

- [GitHub CLI](https://cli.github.com/) installed and authenticated: `winget install GitHub.cli` then `gh auth login`
- Git for Windows installed: `winget install Git.Git`
- Git configured with an email that matches your GitHub account: `git config user.email "your@email.com"`
- PowerShell 5.1+ (comes with Windows 10/11)

## Setup

1. Clone this repo and set up the remote:

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

### macOS / Linux

```bash
./unix/commit.sh
```

### Windows (PowerShell)

```powershell
.\win\commit.ps1
```

It will check your current contribution count for today via the GitHub API, pick a random target (0-45), and add only the needed commits.

## Backfill Past Dates

### macOS / Linux

```bash
./unix/backfill.sh 2025-06-18 2026-02-18
```

### Windows (PowerShell)

```powershell
.\win\backfill.ps1 2025-06-18 2026-02-18
```

This generates 0-45 commits per day across the date range with randomized timestamps (9am-11pm). GitHub's profile only shows the last ~1 year, so there's no point going further back.

## Automatic Scheduling

### macOS (launchd)

Install the launchd agent to run `commit.sh` every day at 9 PM:

```bash
cp unix/com.mosaic.daily.plist ~/Library/LaunchAgents/
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

### Windows (Task Scheduler)

Run the installer from an elevated (Admin) PowerShell prompt:

```powershell
.\win\install-task.ps1
```

If the repo isn't at `C:\mosaic`, pass the path:

```powershell
.\win\install-task.ps1 -RepoPath "D:\path\to\mosaic"
```

To uninstall:

```powershell
Unregister-ScheduledTask -TaskName "MosaicDaily"
```

Alternatively, import `win\mosaic-daily.xml` directly via Task Scheduler GUI (edit the path inside the XML first).

Logs are written to `~/.mosaic.log` (Unix) or `%USERPROFILE%\.mosaic.log` (Windows).

## How It Works

1. Queries the GitHub GraphQL API for today's commit contribution count
2. Picks a random target between 0 and 45
3. If current count < target, generates the difference as commits
4. Each commit appends a timestamp line to `contributions.log`
5. Pushes all new commits to the remote at once
