#!/usr/bin/env bash
set -e

BASE_BRANCH="${1:-main}"

# Auto-detect repo info
REMOTE_URL=$(git config --get remote.origin.url || true)
if [ -z "$REMOTE_URL" ]; then
    echo "Error: Not a git repository or no remote 'origin' found."
    exit 1
fi

REPO_INFO=$(echo "$REMOTE_URL" | sed -E 's/.*github\.com[:\/](.*)/\1/' | sed 's/\.git$//')
OWNER=$(echo "$REPO_INFO" | cut -d'/' -f1)
REPO_NAME=$(echo "$REPO_INFO" | cut -d'/' -f2)

BRANCH=$(git branch --show-current)
COMMIT_SHA=$(git rev-parse HEAD)

if [ "$BRANCH" = "$BASE_BRANCH" ]; then
    echo "Error: Currently on base branch '$BASE_BRANCH'. Please checkout a feature branch."
    exit 1
fi

COMMIT_MSG=$(git log -1 --pretty=%B)
PR_TITLE=$(echo "$COMMIT_MSG" | head -n 1)
PR_BODY="Automated PR created by Antigravity from branch $BRANCH (Commit: $COMMIT_SHA)"

CRED_OUTPUT=$(printf "protocol=https\nhost=github.com\n" | git credential fill 2>/dev/null || true)
TOKEN=$(echo "$CRED_OUTPUT" | grep "^password=" | cut -d'=' -f2-)

if [ -z "$TOKEN" ]; then
    echo "Error: Could not retrieve GitHub token from Git Credential Manager."
    exit 1
fi

echo "[1] Creating PR on $OWNER/$REPO_NAME for branch $BRANCH..."
PAYLOAD=$(jq -n --arg t "$PR_TITLE" --arg b "$PR_BODY" --arg h "$BRANCH" --arg base "$BASE_BRANCH" \
  '{title: $t, body: $b, head: $h, base: $base}')

PR_RES=$(curl -s -X POST "https://api.github.com/repos/$OWNER/$REPO_NAME/pulls" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github+json" \
    -d "$PAYLOAD" || true)

PR_NUMBER=$(echo "$PR_RES" | jq -r '.number // empty')
PR_URL=$(echo "$PR_RES" | jq -r '.html_url // empty')

if [ -z "$PR_NUMBER" ]; then
    EXISTING=$(curl -s "https://api.github.com/repos/$OWNER/$REPO_NAME/pulls?head=${OWNER}:${BRANCH}&state=open" \
        -H "Authorization: Bearer $TOKEN")
    PR_NUMBER=$(echo "$EXISTING" | jq -r '.[0].number // empty')
    PR_URL=$(echo "$EXISTING" | jq -r '.[0].html_url // empty')
fi

if [ -z "$PR_NUMBER" ]; then
    echo "Error creating or fetching PR."
    exit 1
fi

echo "    PR #${PR_NUMBER}: ${PR_URL}"
echo "    Commit SHA: ${COMMIT_SHA}"

echo "[2] Fetching PR diff & changed files..."
DIFF_TEXT=$(curl -s "https://api.github.com/repos/$OWNER/$REPO_NAME/pulls/$PR_NUMBER" \
    -H "Authorization: Bearer $TOKEN" \
    -H "Accept: application/vnd.github.diff")

CHANGED_FILES=$(git diff --name-only origin/$BASE_BRANCH...$BRANCH 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "See diff below")

RELEVANT_CONTEXT=""
if [ -n "$CHANGED_FILES" ]; then
    RELEVANT_CONTEXT=$(git log -n 3 --oneline 2>/dev/null || echo "Recent commits fetched")
fi

echo "[3] Building Production Review Pipeline v2 prompt..."
cat <<EOF > pr_review_prompt.txt
You are reviewing a GitHub Pull Request as a senior software engineer using Production Review Pipeline v2.

==================================================
PHASE 1: DISCOVERY (METADATA, DIFF & CONTEXT)
==================================================
Repository: $OWNER/$REPO_NAME
Pull Request: $PR_URL
Commit SHA: $COMMIT_SHA
Branch: $BRANCH
PR Title: $PR_TITLE

Changed Files:
$CHANGED_FILES

DIFF CONTENT:
$DIFF_TEXT

RELEVANT CODE CONTEXT:
$RELEVANT_CONTEXT

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
EOF

echo -e "\n=== DONE - Production Review Pipeline v2 Prompt written to: pr_review_prompt.txt ==="
