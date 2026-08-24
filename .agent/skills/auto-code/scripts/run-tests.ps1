# Execute Quality Gates Test Suite script for Windows PowerShell

Write-Host "Checking Quality Gates (Build, Test, Lint)..." -ForegroundColor Cyan

$Success = $true

# Detect project type
if (Test-Path "go.mod") {
    Write-Host "Detected Go project..." -ForegroundColor Yellow
    Write-Host "Running go vet..."
    go vet ./...
    if ($LASTEXITCODE -ne 0) { $Success = $false }

    Write-Host "Running go test..."
    go test -v ./...
    if ($LASTEXITCODE -ne 0) { $Success = $false }
}
elseif (Test-Path "package.json") {
    Write-Host "Detected Node/TypeScript project..." -ForegroundColor Yellow
    if (Select-String -Path "package.json" -Pattern '"test":') {
        npm test
        if ($LASTEXITCODE -ne 0) { $Success = $false }
    }
}
else {
    Write-Host "No specific project file (go.mod, package.json) found. Skipping automated build runner." -ForegroundColor DarkYellow
}

if ($Success) {
    Write-Host "✅ ALL LOCAL TESTS PASSED!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "❌ LOCAL TESTS FAILED!" -ForegroundColor Red
    exit 1
}
