param (
    [string]$BaseBranch = "main"
)

$ErrorActionPreference = "Stop"

# Auto-detect repo info
$remoteUrl = git config --get remote.origin.url
if (-not $remoteUrl) {
    Write-Host "Error: Not a git repository or no remote 'origin' found." -ForegroundColor Red
    exit 1
}

# Parse github url
$repoInfo = $remoteUrl -replace ".*github\.com[:/]", "" -replace "\.git$", ""
$owner = $repoInfo.Split("/")[0]
$repoName = $repoInfo.Split("/")[1]

# Auto-detect current branch and commit SHA
$branch = git branch --show-current
$commitSha = git rev-parse HEAD

if ($branch -eq $BaseBranch) {
    Write-Host "Error: Currently on base branch '$BaseBranch'. Please checkout a feature branch." -ForegroundColor Red
    exit 1
}

# Get last commit message for PR title
$commitMsg = git log -1 --pretty=%B
$prTitle = ($commitMsg -split "`n")[0]
$prBody = "Automated PR created by Antigravity from branch $branch (Commit: $commitSha)"

# Get token
$credInput = "protocol=https`nhost=github.com`n"
$credOutput = $credInput | git credential fill 2>$null
$passwordLine = $credOutput | Where-Object { $_ -like 'password=*' } | Select-Object -First 1

$token = if ($passwordLine) {
    $passwordLine.Substring('password='.Length)
} else {
    $null
}

if ([string]::IsNullOrWhiteSpace($token)) {
    Write-Host "Error: Could not retrieve GitHub token from Git Credential Manager." -ForegroundColor Red
    exit 1
}

$headers = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/vnd.github+json"
}

# Create PR
Write-Host "[1] Creating PR on $owner/$repoName for branch $branch..." -ForegroundColor Yellow
$prPayload = @{
    title = $prTitle
    body = $prBody
    head = $branch
    base = $BaseBranch
} | ConvertTo-Json

$prUrl = $null
$prNumber = $null

try {
    $pr = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/pulls" -Method Post -Headers $headers -Body $prPayload -ContentType "application/json"
    $prUrl = $pr.html_url
    $prNumber = $pr.number
    Write-Host "    PR #${prNumber} created: ${prUrl}" -ForegroundColor Green
} catch {
    $existingPrs = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/pulls?head=${owner}:${branch}&state=open" -Headers $headers
    if ($existingPrs.Count -gt 0) {
        $prUrl = $existingPrs[0].html_url
        $prNumber = $existingPrs[0].number
        Write-Host "    Existing PR #${prNumber}: ${prUrl}" -ForegroundColor Yellow
    } else {
        Write-Host "    Error creating PR: $_" -ForegroundColor Red
        exit 1
    }
}

# Get PR diff & changed files
Write-Host "[2] Fetching PR diff..." -ForegroundColor Yellow
$diffHeaders = @{
    "Authorization" = "Bearer $token"
    "Accept" = "application/vnd.github.diff"
}
$diffText = Invoke-RestMethod -Uri "https://api.github.com/repos/$owner/$repoName/pulls/$prNumber" -Headers $diffHeaders
$changedFiles = git diff --name-only "origin/${BaseBranch}...${branch}" 2>$null

# Write review prompt to file
Write-Host "[3] Building Production Review Pipeline v2 prompt..." -ForegroundColor Yellow
$reviewPrompt = @"
You are reviewing a GitHub Pull Request as a senior software engineer using Production Review Pipeline v2.

==================================================
PHASE 1: DISCOVERY (METADATA, DIFF & CONTEXT)
==================================================
Repository: $owner/$repoName
Pull Request: $prUrl
Commit SHA: $commitSha
Branch: $branch
PR Title: $prTitle

Changed Files:
$changedFiles

DIFF CONTENT:
$diffText

Your task is to perform a SYSTEMATIC, PRODUCTION-LEVEL CODE REVIEW to prove that each important flow is correct or report concrete failures.

==================================================
PHASE 2: ANALYSIS (12-POINT SYSTEMATIC PROTOCOL)
==================================================
Systematically evaluate the change set across all 12 checkpoints:
1. FUNCTIONAL CORRECTNESS: Happy/failure paths, create/update/delete behavior, boundary inputs, UI operation promises.
2. DATA FLOW & STATE CONSISTENCY: Trace values UI → Local State → Payload → API → Store → UI. Check stale/inconsistent state.
3. API & BACKEND CONTRACT: HTTP method, endpoint, payload shape, create vs update consistency, multipart, nullable fields.
4. EDGE CASES & BOUNDARY CONDITIONS: Empty lists, zero, negative/max values, first/last page, rapid clicks, timeouts, cancellation.
5. CONCURRENCY & ASYNC FLOWS: Race conditions, duplicate requests, stale responses, unmount during request, PENDING → SUCCESS/FAILED.
6. SECURITY: Secrets, IDOR, privilege escalation, client-only auth, XSS, injection.
7. FINANCIAL / BUSINESS DATA SAFETY: Numeric boundaries, balance checks, duplicate submission, idempotency, rounding, totals.
8. PAGINATION / FILTERING / SEARCH: Page/pageSize, total count, filter persistence, global vs current-page totals.
9. ERROR HANDLING & RECOVERY: API errors, partial failures, loading states, stale state recovery.
10. REGRESSION ANALYSIS: Compare previous vs changed behavior (What worked before? What changed? Could users lose functionality?).
11. CODE QUALITY: Only report concrete correctness/maintainability risks. No subjective naming/style nitpicks.
12. TEST COVERAGE: Request minimal reproducible test only for concrete bugs found.

==================================================
PHASE 3: VERIFICATION (VERIFICATION & EVIDENCE GATE)
==================================================
Filter every candidate finding through the Verification Gate:
Candidate Issue → Can I reproduce it from code? → Is it caused by this PR? → Could existing code prevent it? → Is impact realistic?

EVIDENCE GATE REQUIREMENT:
Every reported finding MUST contain concrete execution path evidence:
- Trace the exact function calls or state transitions.
- Explain the realistic failure scenario.
- RULE: No concrete evidence → DO NOT output finding. Do not output vague claims like "there might be a race condition".

==================================================
PHASE 4: VALIDATION (BEHAVIOR MATRIX, BLIND-SPOT & DEDUPLICATION)
==================================================
1. CHANGED BEHAVIOR MATRIX: Mentally construct Flow | Before | After | Risk matrix to catch silent default/behavioral shifts.
2. ROOT CAUSE DEDUPLICATION: Group multiple related symptoms across files into ONE single finding based on the underlying root cause.
3. BLIND-SPOT PASS: Internal audit on file scrutiny, multi-file flows, async races, paginated totals, and UI/backend state drift.

==================================================
PHASE 5: REPORTING & FINAL VERDICT
==================================================
Do not output REVIEW_STATUS until all 5 phases are complete.

At the very beginning output EXACTLY one of:

REVIEW_STATUS: APPROVED

or

REVIEW_STATUS: CHANGES_REQUESTED

If CHANGES_REQUESTED, output findings using EXACTLY:

[FINDING]
Severity: CRITICAL|HIGH|MEDIUM|LOW
File: path/to/file
Problem: <specific problem>
Evidence: <concrete execution path / call sequence>
Failure scenario: <realistic failure scenario>
Recommended fix: <practical code snippet or implementation approach>
[/FINDING]

After all findings, optionally provide a short review summary.
"@

$outPath = Join-Path (Get-Location) "pr_review_prompt.txt"
Set-Content -Path $outPath -Value $reviewPrompt -Encoding UTF8

Write-Host "`n=== DONE - Production Review Pipeline v2 Prompt written to: $outPath ===" -ForegroundColor Cyan
