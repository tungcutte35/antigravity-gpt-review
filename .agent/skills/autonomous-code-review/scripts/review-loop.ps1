# Orchestrator Review Loop Manager for Windows PowerShell
param (
    [int]$MaxIterations = 5,
    [string]$ReviewResultFile = ".gemini/scratch/review-result.json"
)

Write-Host "Initializing Autonomous Review Loop Manager..." -ForegroundColor Cyan

if (-not (Test-Path $ReviewResultFile)) {
    Write-Host "No review result file found at $ReviewResultFile. Waiting for Browser Adapter..." -ForegroundColor Yellow
    exit 0
}

try {
    $ReviewJson = Get-Content $ReviewResultFile -Raw | ConvertFrom-Json
} catch {
    Write-Host "Error parsing review result JSON!" -ForegroundColor Red
    exit 1
}

Write-Host "Status: $($ReviewJson.status)" -ForegroundColor Cyan
Write-Host "Critical: $($ReviewJson.severity_summary.critical) | High: $($ReviewJson.severity_summary.high) | Medium: $($ReviewJson.severity_summary.medium) | Low: $($ReviewJson.severity_summary.low)" -ForegroundColor Yellow

if ($ReviewJson.status -eq "APPROVED" -and $ReviewJson.severity_summary.critical -eq 0 -and $ReviewJson.severity_summary.high -eq 0) {
    Write-Host "🎉 PR APPROVED BY INDEPENDENT REVIEWER!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "⚠️ CHANGES REQUIRED ($($ReviewJson.issues.Count) issues to fix)." -ForegroundColor Red
    exit 2
}
