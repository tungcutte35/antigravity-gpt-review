# Launch & Connect User Chrome Session with Remote Debugging (Bí kíp 1 & 2)
param (
    [string]$Url = "https://chatgpt.com"
)

Write-Host "Setting up User Chrome Session Integration..." -ForegroundColor Cyan

$ChromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
}
if (-not (Test-Path $ChromePath)) {
    $ChromePath = "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe"
}

# Check if Chrome is listening on debugging port 9222
$IsPort9222Active = (Get-NetTCPConnection -LocalPort 9222 -ErrorAction SilentlyContinue)

if (-not $IsPort9222Active) {
    Write-Host "Launching User Chrome with profile and Debugging Port 9222..." -ForegroundColor Yellow
    $UserDataDir = "$env:LOCALAPPDATA\Google\Chrome\User Data"
    
    # Launch Chrome attached to User Profile
    Start-Process -FilePath $ChromePath -ArgumentList "--remote-debugging-port=9222 --user-data-dir=`"$UserDataDir`" --restore-last-session `"$Url`""
    Start-Sleep -Seconds 2
    Write-Host "✅ User Chrome launched successfully!" -ForegroundColor Green
} else {
    Write-Host "✅ Connected to existing User Chrome session on port 9222!" -ForegroundColor Green
}
