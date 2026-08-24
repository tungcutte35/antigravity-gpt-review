# Compact Git Patch Collector (Optimized for ChatGPT Free & Private Repos)
param (
    [string]$TargetBranch = "main",
    [string]$OutputFile = ".gemini/scratch/pr_diff.txt"
)

Write-Host "Collecting Compact Git Patch..." -ForegroundColor Cyan

# Create scratch directory if missing
$ScratchDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
}

# Ensure git repository exists
$IsGitRepo = (git rev-parse --is-inside-work-tree 2>$null)
if ($IsGitRepo -ne "true") {
    git init | Out-Null
    git add . | Out-Null
    git commit -m "feat: initial workspace setup" | Out-Null
}

# Collect diff excluding lockfiles and heavy binary noise
$Exclusions = @(":(exclude)go.sum", ":(exclude)package-lock.json", ":(exclude)yarn.lock", ":(exclude)*.min.js")

$GitDiff = (git diff HEAD~1..HEAD -- . @Exclusions 2>$null)
if (-not $GitDiff) {
    $GitDiff = (git diff HEAD -- . @Exclusions 2>$null)
}
if (-not $GitDiff) {
    $GitDiff = (git diff --staged -- . @Exclusions 2>$null)
}

# Compact formatting
$CompactDiff = @"
=== COMPACT CODE PATCH FOR REVIEW ===
$GitDiff
"@

Set-Content -Path $OutputFile -Value $CompactDiff -Encoding UTF8
Write-Host "Compact patch saved to: $OutputFile" -ForegroundColor Green
