#Requires -Version 5.1
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoDir = Split-Path -Parent $ScriptDir
$LogFile = Join-Path $env:USERPROFILE ".mosaic.log"
$ContributionsFile = Join-Path $RepoDir "contributions.log"

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] $Message"
    Write-Host $entry
    Add-Content -Path $LogFile -Value $entry
}

# --- Pre-flight checks ---

# Try to locate gh on the PATH first.  If that fails, look in the
# standard installation directory used by winget.  If we find it there
# we add the folder to PATH so subsequent calls succeed.
$ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
if (-not $ghCmd) {
    $default = "C:\Program Files\GitHub CLI\gh.exe"
    if (Test-Path $default) {
        # Add its directory to PATH for this session so Get-Command works
        $dir = Split-Path $default
        $env:PATH += ";$dir"
        $ghCmd = Get-Command "gh" -ErrorAction SilentlyContinue
    }
}

if (-not $ghCmd) {
    Write-Log "ERROR: gh CLI is not installed. Install it with: winget install GitHub.cli"
    exit 1
}

$ghAuth = gh auth status 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: gh CLI is not authenticated. Run: gh auth login"
    exit 1
}

Set-Location $RepoDir

$remote = git remote get-url origin 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: No git remote 'origin' configured."
    exit 1
}

$GitEmail = git config user.email 2>$null
if ([string]::IsNullOrEmpty($GitEmail)) {
    Write-Log 'ERROR: git user.email is not set. Run: git config user.email "your@email.com"'
    exit 1
}

# --- Check if repo is a fork (forks don't count toward contributions) ---

$RemoteUrl = git remote get-url origin
$RepoSlug = $RemoteUrl -replace '.*github\.com[:/]' -replace '\.git$'

$IsFork = gh api "repos/$RepoSlug" --jq '.fork' 2>$null
if ($IsFork -eq "true") {
    Write-Log "ERROR: This repo is a GitHub fork. Commits to forks do NOT count as contributions."
    Write-Log "       Create your own repo instead: gh repo create <name> --private"
    Write-Log "       Then update the remote: git remote set-url origin <new-url>"
    exit 1
}

# --- Query today's contribution count ---

$Today = (Get-Date).ToUniversalTime().ToString("yyyy-MM-dd")
$Tomorrow = (Get-Date).ToUniversalTime().AddDays(1).ToString("yyyy-MM-dd")

Write-Log "Checking contributions for $Today..."

$query = @"
{
  viewer {
    contributionsCollection(from: "${Today}T00:00:00Z", to: "${Tomorrow}T00:00:00Z") {
      totalCommitContributions
    }
  }
}
"@

$result = gh api graphql -f query="$query" --jq '.data.viewer.contributionsCollection.totalCommitContributions'
if ($LASTEXITCODE -ne 0) {
    Write-Log "ERROR: Failed to query GitHub API."
    exit 1
}

$ContributionCount = [int]$result
Write-Log "Current contributions today: $ContributionCount"

# --- Calculate how many commits to make ---

$Target = Get-Random -Minimum 0 -Maximum 46  # 0 to 45
$Needed = $Target - $ContributionCount

if ($Needed -le 0) {
    Write-Log "Already at target ($ContributionCount >= $Target). Nothing to do."
    exit 0
}

Write-Log "Target: $Target | Need to add: $Needed commits"

# --- Generate commits ---

$rng = [System.Security.Cryptography.RandomNumberGenerator]::Create()
$bytes = New-Object byte[] 4

for ($i = 1; $i -le $Needed; $i++) {
    $rng.GetBytes($bytes)
    $hash = ($bytes | ForEach-Object { $_.ToString("x2") }) -join ""
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $ContributionsFile -Value "$timestamp $hash"
    git add $ContributionsFile
    git commit -m "update" --quiet
}

Write-Log "Created $Needed commits. Pushing..."

git push --quiet

Write-Log "Done. Total contributions today: $Target"
