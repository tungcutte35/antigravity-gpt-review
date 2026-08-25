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
    echo "    [!] Notice: Could not create PR via GitHub API (branch may not be pushed to remote yet)."
    echo "    [!] Proceeding with local git diff prompt generation..."
    PR_NUMBER="LOCAL"
    PR_URL="Local Branch: $BRANCH (Commit: $COMMIT_SHA)"
else
    echo "    PR #${PR_NUMBER}: ${PR_URL}"
fi
echo "    Commit SHA: ${COMMIT_SHA}"

echo "[2] Fetching PR metadata & full git diff..."
ACTUAL_DIFF=$(git diff "$BASE_BRANCH...$BRANCH" 2>/dev/null || git diff HEAD~1 2>/dev/null || echo "No diff available")
DIFF_TEXT="$ACTUAL_DIFF"

CHANGED_FILES=$(git diff --name-only "$BASE_BRANCH...$BRANCH" 2>/dev/null || git diff --name-only HEAD~1 2>/dev/null || echo "See diff below")

RELEVANT_CONTEXT=""
if [ -n "$CHANGED_FILES" ]; then
    RELEVANT_CONTEXT=$(git log -n 3 --oneline 2>/dev/null || echo "Recent commits fetched")
fi

echo "$ACTUAL_DIFF" > pr_raw_diff.txt

echo "[3] Building concise Production Review Pipeline v2 prompt for ChatGPT..."
cat <<EOF > pr_review_prompt.txt
You are reviewing a GitHub Pull Request as a senior software engineer using Production Review Pipeline v2.

Repository: $OWNER/$REPO_NAME
Pull Request: $PR_URL
Commit SHA: $COMMIT_SHA
Branch: $BRANCH
PR Title: $PR_TITLE

Changed Files:
$CHANGED_FILES

RELEVANT COMMITS:
$RELEVANT_CONTEXT

Please inspect this PR using your GitHub tools/plugins and evaluate the changes.

Output Requirements:
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

After all findings, provide a concise review summary.
EOF

echo -e "\n=== DONE - Concise prompt written to: pr_review_prompt.txt & Raw diff to: pr_raw_diff.txt ==="
