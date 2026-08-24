# Extract Review JSON from Clipboard & Trigger Auto-Fix Loop
param (
    [string]$OutputFile = ".gemini/scratch/review-result.json"
)

Write-Host "Reading ChatGPT Review from Clipboard..." -ForegroundColor Cyan

$ClipboardText = Get-Clipboard -Raw

if (-not $ClipboardText) {
    Write-Host "⚠️ Clipboard is empty! Click 'Copy' on ChatGPT's JSON response block in Chrome, then run this script." -ForegroundColor Yellow
    exit 1
}

# Extract ```json ... ``` code block
if ($ClipboardText -match "(?s)```json\s*(.*?)\s*```") {
    $JsonContent = $Matches[1]
} elseif ($ClipboardText -match "(?s)\{.*\}") {
    $JsonContent = $Matches[0]
} else {
    $JsonContent = $ClipboardText
}

# Ensure output directory exists
$ScratchDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
}

# Write JSON to file
Set-Content -Path $OutputFile -Value $JsonContent -Encoding UTF8
Write-Host "✅ ChatGPT Review JSON extracted and saved to: $OutputFile" -ForegroundColor Green
Write-Host "🚀 Triggering Fixer Agent to refactor code based on JSON feedback..." -ForegroundColor Yellow
