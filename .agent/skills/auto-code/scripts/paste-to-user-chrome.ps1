# Auto-Focus, Click Input & Paste into User's Chrome Window
param (
    [string]$PromptFile = ".gemini/scratch/full_review_prompt.txt"
)

Write-Host "Focusing YOUR existing Chrome browser window with Mouse Click..." -ForegroundColor Cyan

if (-not (Test-Path $PromptFile)) {
    if (Test-Path "d:\Desktop\test\.gemini\scratch\full_review_prompt.txt") {
        $PromptFile = "d:\Desktop\test\.gemini\scratch\full_review_prompt.txt"
    } elseif (Test-Path "d:\Desktop\skill_ai\.gemini\scratch\full_review_prompt.txt") {
        $PromptFile = "d:\Desktop\skill_ai\.gemini\scratch\full_review_prompt.txt"
    }
}

if (-not (Test-Path $PromptFile)) {
    Write-Host "Error: Prompt file $PromptFile not found!" -ForegroundColor Red
    exit 1
}

# 1. Copy Prompt content to System Clipboard
Get-Content $PromptFile -Raw | Set-Clipboard
Write-Host "1. Prompt copied to Clipboard from $PromptFile." -ForegroundColor Green

# 2. Add Win32 mouse click types
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$Win32Code = @"
using System;
using System.Runtime.InteropServices;

public class Win32Automation {
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);

    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint dwData, UIntPtr dwExtraInfo);

    public const uint MOUSEEVENTF_LEFTDOWN = 0x0002;
    public const uint MOUSEEVENTF_LEFTUP = 0x0004;

    [StructLayout(LayoutKind.Sequential)]
    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

Add-Type -TypeDefinition $Win32Code -ErrorAction SilentlyContinue

$chromeProc = Get-Process -Name "chrome" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -ne "" } | Select-Object -First 1

if ($chromeProc) {
    Write-Host "Found Chrome process: $($chromeProc.MainWindowTitle)" -ForegroundColor Yellow
    [Win32Automation]::SetForegroundWindow($chromeProc.MainWindowHandle) | Out-Null
    Start-Sleep -Milliseconds 500

    $rect = New-Object Win32Automation+RECT
    [Win32Automation]::GetWindowRect($chromeProc.MainWindowHandle, [ref]$rect) | Out-Null

    # Calculate coordinates for #prompt-textarea (middle-center of Chrome window)
    $windowWidth = $rect.Right - $rect.Left
    $windowHeight = $rect.Bottom - $rect.Top

    $clickX = $rect.Left + [int]($windowWidth * 0.5)
    $clickY = $rect.Top + [int]($windowHeight * 0.54)

    Write-Host "Moving mouse to ($clickX, $clickY) and clicking input area..." -ForegroundColor Yellow
    [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($clickX, $clickY)
    Start-Sleep -Milliseconds 200

    [Win32Automation]::mouse_event(0x0002, 0, 0, 0, [UIntPtr]::Zero)
    [Win32Automation]::mouse_event(0x0004, 0, 0, 0, [UIntPtr]::Zero)
    Start-Sleep -Milliseconds 400

    Write-Host "Sending Ctrl+V and Enter..." -ForegroundColor Yellow
    [System.Windows.Forms.SendKeys]::SendWait("^{v}")
    Start-Sleep -Milliseconds 500
    [System.Windows.Forms.SendKeys]::SendWait("{ENTER}")

    Write-Host "✅ PROMPT PASTED AND SUBMITTED TO YOUR CHROME WINDOW!" -ForegroundColor Green
} else {
    Write-Host "⚠️ Chrome process with window not found!" -ForegroundColor Red
}
