#Requires -RunAsAdministrator
# Registers the Mosaic daily task in Windows Task Scheduler.
# Run this once from an elevated PowerShell prompt.
#
# Usage:
#   .\install-task.ps1                        (uses default C:\mosaic)
#   .\install-task.ps1 -RepoPath "D:\mosaic"  (custom path)

param(
    [string]$RepoPath = "C:\mosaic"
)

$TaskName = "MosaicDaily"
$ScriptPath = Join-Path $RepoPath "win\commit.ps1"

if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: commit.ps1 not found at $ScriptPath"
    Write-Host "Make sure the repo is cloned to $RepoPath or pass -RepoPath."
    exit 1
}

# Remove existing task if present
$existing = Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
if ($existing) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    Write-Host "Removed existing '$TaskName' task."
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-ExecutionPolicy Bypass -NoProfile -File `"$ScriptPath`"" `
    -WorkingDirectory $RepoPath

$Trigger = New-ScheduledTaskTrigger -Daily -At "9:00PM"

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -RunOnlyIfNetworkAvailable

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Settings $Settings `
    -Description "Mosaic - Daily GitHub contribution automation"

Write-Host ""
Write-Host "Task '$TaskName' registered successfully."
Write-Host "  Schedule : Daily at 9:00 PM"
Write-Host "  Script   : $ScriptPath"
Write-Host ""
Write-Host "To uninstall: Unregister-ScheduledTask -TaskName '$TaskName'"
