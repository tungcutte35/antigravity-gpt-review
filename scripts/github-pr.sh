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
    echo "    [!] WARNING: Could not create PR via GitHub API (branch may not be pushed to remote yet)."
    if [ "${ALLOW_LOCAL_REVIEW:-1}" = "1" ]; then
        echo "    [!] ALLOW_LOCAL_REVIEW=1 — Falling back to LOCAL mode..."
        PR_NUMBER="LOCAL"
        PR_URL="Local Branch: $BRANCH (Commit: $COMMIT_SHA)"
    else
        echo "    [!] Set ALLOW_LOCAL_REVIEW=1 to use local diff mode. Exiting."
        exit 1
    fi
else
    echo "    PR #${PR_NUMBER}: ${PR_URL}"
fi
echo "    Commit SHA: ${COMMIT_SHA}"

cat << 'EOF' > pr_review_prompt.txt
You are reviewing a GitHub Pull Request as a senior software engineer using Production Review Pipeline v2.

==================================================
PHASE 1: DISCOVERY (METADATA & CONTEXT)
==================================================
Please use your GitHub plugin/tool to read the diff for the PR based on the metadata below.
EOF

printf 'Repository: %s\n' "$OWNER/$REPO_NAME" >> pr_review_prompt.txt
printf 'Pull Request: %s\n' "$PR_URL" >> pr_review_prompt.txt
printf 'Commit SHA: %s\n' "$COMMIT_SHA" >> pr_review_prompt.txt
printf 'Branch: %s\n' "$BRANCH" >> pr_review_prompt.txt
printf 'PR Title: %s\n' "$PR_TITLE" >> pr_review_prompt.txt

cat << 'EOF' >> pr_review_prompt.txt

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
If CHANGES_REQUESTED, output findings using EXACTLY this format:

[FINDING]
Severity: CRITICAL|HIGH|MEDIUM|LOW
File: path/to/file
Problem: <specific problem>
Evidence: <concrete execution path / call sequence>
Failure scenario: <realistic failure scenario>
Recommended fix: <practical code snippet or implementation approach>
[/FINDING]

After all findings, provide a concise review summary.

Output Requirements:
At the VERY END of your response, output EXACTLY one of the following lines based on your verdict:
REVIEW_STATUS: APPROVED
or
REVIEW_STATUS: CHANGES_REQUESTED

Do not put REVIEW_STATUS anywhere else in your response to avoid confusing the parser.
EOF

# If this is a LOCAL fallback review, GPT has no GitHub PR to fetch from, so we MUST supply the diff.
if [ "$PR_NUMBER" = "LOCAL" ]; then
    echo "    [!] LOCAL fallback detected. Appending compact diff directly to prompt..."
    
    BASE_COMMIT=$(git merge-base "$BASE_BRANCH" "$BRANCH" 2>/dev/null || echo "HEAD~1")
    if [ "$BASE_COMMIT" = "HEAD~1" ]; then
        ACTUAL_DIFF=$(git diff HEAD~1 2>/dev/null || echo "No diff available")
        CHANGED_FILES=$(git diff --name-only HEAD~1 2>/dev/null || echo "See diff below")
    else
        ACTUAL_DIFF=$(git diff "$BASE_COMMIT...$BRANCH" 2>/dev/null || echo "No diff available")
        CHANGED_FILES=$(git diff --name-only "$BASE_COMMIT...$BRANCH" 2>/dev/null || echo "See diff below")
    fi
    
    echo "$ACTUAL_DIFF" > pr_raw_diff.txt
    TOTAL_DIFF_LINES=$(echo "$ACTUAL_DIFF" | wc -l)
    MAX_DIFF_LINES=300
    COMPACT_DIFF=$(echo "$ACTUAL_DIFF" | head -n "$MAX_DIFF_LINES")
    TRUNCATION_NOTE=""
    if [ "$TOTAL_DIFF_LINES" -gt "$MAX_DIFF_LINES" ]; then
        REMAINING=$((TOTAL_DIFF_LINES - MAX_DIFF_LINES))
        TRUNCATION_NOTE="[TRUNCATED: $REMAINING more lines not shown. Full diff saved in pr_raw_diff.txt]\n\nIMPORTANT: This diff is truncated.\nDo NOT return APPROVED unless the available diff is sufficient\nto confidently review the change."
    fi

    printf '\nChanged Files:\n%s\n' "$CHANGED_FILES" >> pr_review_prompt.txt
    printf '\nCOMPACT GIT DIFF SUMMARY:\n%s\n' "$COMPACT_DIFF" >> pr_review_prompt.txt
    if [ -n "$TRUNCATION_NOTE" ]; then
        printf '%b\n' "$TRUNCATION_NOTE" >> pr_review_prompt.txt
    fi
    printf '\n[END OF DIFF]\nPlease evaluate the local changes above.\n' >> pr_review_prompt.txt
fi

echo -e "\n=== DONE - Prompt written to: pr_review_prompt.txt ($(wc -l < pr_review_prompt.txt) lines) ==="

