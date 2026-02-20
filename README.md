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
├── mosaic.conf            # Configuration file
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

> **Commits in forked repos do NOT count toward your GitHub contribution graph.** You must detach the fork first. The scripts will detect this and block execution until it's fixed.

1. **Fork** this repo via the GitHub "Fork" button
2. Go to your fork's **Settings > General**, scroll to the **Danger Zone**
3. Click **"Detach fork"** — this converts it into a standalone repo
4. Make it **private**: Settings > General > Danger Zone > Change visibility > Private
5. Clone your repo:

   ```bash
   git clone https://github.com/<your-username>/mosaic.git
   cd mosaic
   ```

6. Set your git email to match your GitHub account:

   ```bash
   git config user.email "your@email.com"
   ```

7. Enable **Private contributions** on your GitHub profile:
   Go to your profile > Contribution Settings > check "Private contributions"

## Daily Usage (Manual)

### macOS / Linux

```bash
./unix/commit.sh
```

### Windows (PowerShell)

```powershell
.\win\commit.ps1
```

It will check your current contribution count for today via the GitHub API, pick a random target, and add only the needed commits.

## Configuration

All settings live in `mosaic.conf` at the repo root:

```ini
MIN_COMMITS=0
MAX_COMMITS=45
WEEKEND_COMMITS=true
ACTIVITY=1.0
```

| Setting            | Default | Description                                                                                                      |
| ------------------ | ------- | ---------------------------------------------------------------------------------------------------------------- |
| `MIN_COMMITS`      | `0`     | Minimum random commits per day                                                                                   |
| `MAX_COMMITS`      | `45`    | Maximum random commits per day                                                                                   |
| `WEEKEND_COMMITS`  | `true`  | Set to `false` to skip Saturdays and Sundays                                                                     |
| `ACTIVITY`         | `1.0`   | Probability of committing on any given day (0.0 = never, 1.0 = always). E.g. `0.4` means 40% chance per day     |

## Backfill Past Dates

### macOS / Linux

```bash
./unix/backfill.sh 2025-06-18 2026-02-18
```

### Windows (PowerShell)

```powershell
.\win\backfill.ps1 2025-06-18 2026-02-18
```

This generates commits per day across the date range based on your `mosaic.conf` settings, with randomized timestamps (9am-10pm).

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

1. Reads settings from `mosaic.conf`
2. Skips if it's a weekend (`WEEKEND_COMMITS=false`) or the activity roll fails
3. Queries the GitHub GraphQL API for today's commit contribution count
4. Picks a random target between `MIN_COMMITS` and `MAX_COMMITS`
5. If current count < target, generates the difference as commits
6. Each commit appends a timestamp line to `contributions.log`
7. Pushes all new commits to the remote at once
