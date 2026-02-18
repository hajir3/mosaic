#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$ContributionsFile = Join-Path $RepoDir "contributions.log"

if ($args.Count -ne 2) {
    Write-Host "Usage: .\backfill.ps1 START_DATE END_DATE"
    Write-Host "  Dates in YYYY-MM-DD format"
    Write-Host "  Example: .\backfill.ps1 2025-03-01 2026-02-18"
    exit 1
}

$StartDateStr = $args[0]
$EndDateStr = $args[1]

# Validate date format
try {
    $StartDate = [datetime]::ParseExact($StartDateStr, "yyyy-MM-dd", $null)
} catch {
    Write-Host "ERROR: Invalid start date format. Use YYYY-MM-DD."
    exit 1
}

try {
    $EndDate = [datetime]::ParseExact($EndDateStr, "yyyy-MM-dd", $null)
} catch {
    Write-Host "ERROR: Invalid end date format. Use YYYY-MM-DD."
    exit 1
}

if (-not (Get-Command "gh" -ErrorAction SilentlyContinue)) {
    Write-Host "ERROR: gh CLI is not installed. Install it with: winget install GitHub.cli"
    exit 1
}

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: gh CLI is not authenticated. Run: gh auth login"
    exit 1
}

Set-Location $RepoDir

$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "ERROR: No git remote 'origin' configured."
    exit 1
}

$GitEmail = git config user.email 2>$null
if ([string]::IsNullOrEmpty($GitEmail)) {
    Write-Host 'ERROR: git user.email is not set. Run: git config user.email "your@email.com"'
    exit 1
}

# --- Check if repo is a fork (forks don't count toward contributions) ---

$RemoteUrl = git remote get-url origin
$RepoSlug = $RemoteUrl -replace '.*github\.com[:/]' -replace '\.git$'

$IsFork = gh api "repos/$RepoSlug" --jq '.fork' 2>$null
if ($IsFork -eq "true") {
    Write-Host "ERROR: This repo is a GitHub fork. Commits to forks do NOT count as contributions."
    Write-Host "       Create your own repo instead: gh repo create <name> --private"
    Write-Host "       Then update the remote: git remote set-url origin <new-url>"
    exit 1
}

if ($StartDate -gt $EndDate) {
    Write-Host "ERROR: Start date must be before end date."
    exit 1
}

$TotalCommits = 0
$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 4

Write-Host "Backfilling from $StartDateStr to $EndDateStr..."
Write-Host ""

$CurrentDate = $StartDate
while ($CurrentDate -le $EndDate) {
    $CurrentDateStr = $CurrentDate.ToString("yyyy-MM-dd")
    $Target = Get-Random -Minimum 0 -Maximum 46  # 0 to 45

    Write-Host -NoNewline "  $CurrentDateStr - $Target commits..."

    for ($i = 1; $i -le $Target; $i++) {
        # Random hour between 9 (9am) and 22 (10pm)
        $Hour = Get-Random -Minimum 9 -Maximum 23
        $Minute = Get-Random -Minimum 0 -Maximum 60
        $Second = Get-Random -Minimum 0 -Maximum 60
        $Timestamp = "{0} {1:D2}:{2:D2}:{3:D2}" -f $CurrentDateStr, $Hour, $Minute, $Second

        $rng.GetBytes($bytes)
        $hash = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
        Add-Content -Path $ContributionsFile -Value "$Timestamp $hash"
        git add $ContributionsFile

        $env:GIT_AUTHOR_DATE = $Timestamp
        $env:GIT_COMMITTER_DATE = $Timestamp
        git commit -m "update" --quiet
        Remove-Item Env:\GIT_AUTHOR_DATE
        Remove-Item Env:\GIT_COMMITTER_DATE
    }

    $TotalCommits += $Target

    # Push after each day so GitHub processes them in small batches
    if ($Target -gt 0) {
        git push --quiet
        Write-Host " done (pushed)"
    } else {
        Write-Host " done (skipped)"
    }

    $CurrentDate = $CurrentDate.AddDays(1)
}

Write-Host ""
Write-Host "Backfill complete: $TotalCommits total commits"
Write-Host "Done!"
