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

echo "[2] Building minimal GPT review prompt (metadata only)..."
# GPT reads the PR itself via GitHub plugin — only send metadata
printf 'Repository: %s\n' "$OWNER/$REPO_NAME" > pr_review_prompt.txt
printf 'Pull Request: %s\n' "$PR_URL" >> pr_review_prompt.txt
printf 'Commit SHA: %s\n' "$COMMIT_SHA" >> pr_review_prompt.txt
printf 'Branch: %s\n' "$BRANCH" >> pr_review_prompt.txt
printf 'PR Title: %s\n' "$PR_TITLE" >> pr_review_prompt.txt

echo -e "\n=== DONE - Prompt written to: pr_review_prompt.txt ($(wc -l < pr_review_prompt.txt) lines) ==="

