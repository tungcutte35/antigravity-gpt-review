$ErrorActionPreference = "Stop"

$chromeDir = "$env:LOCALAPPDATA\Google\Chrome\User Data Antigravity"
if (-not (Test-Path $chromeDir)) {
    New-Item -ItemType Directory -Force -Path $chromeDir | Out-Null
}

Write-Host "[1] Checking for existing Antigravity CDP Chrome processes..."
$existing = Get-CimInstance Win32_Process -Filter "Name = 'chrome.exe'" | Where-Object { $_.CommandLine -like "*User Data Antigravity*" -or $_.CommandLine -like "*9222*" }
if ($existing) {
    $existing | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    Start-Sleep 2
}

Write-Host "[2] Launching Chrome with CDP on port 9222..."
$chromePath = "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
if (-not (Test-Path $chromePath)) {
    $chromePath = "C:\Program Files\Google\Chrome\Application\chrome.exe"
}

Start-Process -FilePath $chromePath -ArgumentList @(
    "--remote-debugging-port=9222",
    "--user-data-dir=`"$chromeDir`"",
    "--no-first-run",
    "--disable-session-crashed-bubble",
    "--hide-crash-restore-bubble",
    "--disable-infobars",
    "--no-default-browser-check",
    "https://chatgpt.com"
)

Write-Host "[3] Waiting 5 seconds for Chrome to start..."
Start-Sleep 5

Write-Host "[4] Testing CDP Connection..."
try {
    $v = Invoke-RestMethod -Uri "http://127.0.0.1:9222/json/version" -TimeoutSec 3
    Write-Host "SUCCESS: CDP is running!" -ForegroundColor Green
    $v | ConvertTo-Json
} catch {
    Write-Host "FAILED: Could not connect to CDP." -ForegroundColor Red
    Write-Host $_
    exit 1
}
