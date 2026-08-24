# Get Review Response from Clipboard & Save to review-result.json
param (
    [string]$OutputFile = ".gemini/scratch/review-result.json"
)

Write-Host "Extracting ChatGPT Review Response..." -ForegroundColor Cyan

# Get text from system Clipboard
$ClipboardText = Get-Clipboard -Raw

if (-not $ClipboardText) {
    Write-Host "⚠️ Clipboard is empty! Please click 'Copy' on ChatGPT's JSON response block." -ForegroundColor Yellow
    exit 1
}

# Extract ```json ... ``` block
if ($ClipboardText -match "(?s)```json\s*(.*?)\s*```") {
    $JsonContent = $Matches[1]
} elseif ($ClipboardText -match "(?s)\{.*\}") {
    $JsonContent = $Matches[0]
} else {
    $JsonContent = $ClipboardText
}

# Ensure destination directory exists
$ScratchDir = Split-Path -Path $OutputFile -Parent
if (-not (Test-Path -Path $ScratchDir)) {
    New-Item -ItemType Directory -Path $ScratchDir -Force | Out-Null
}

# Write JSON to file
Set-Content -Path $OutputFile -Value $JsonContent -Encoding UTF8
Write-Host "✅ ChatGPT Review JSON saved successfully to: $OutputFile" -ForegroundColor Green
