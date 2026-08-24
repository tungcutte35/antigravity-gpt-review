#!/usr/bin/env bash
# Collect Git PR Context & Diff script for Linux / macOS
TARGET_BRANCH="${1:-main}"
OUTPUT_FILE="${2:-.gemini/scratch/pr_diff.txt}"

mkdir -p "$(dirname "$OUTPUT_FILE")"

GIT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
GIT_LOG=$(git log -n 5 --oneline)
GIT_DIFF=$(git diff "$TARGET_BRANCH...HEAD")

cat <<EOF > "$OUTPUT_FILE"
=== BRANCH INFORMATION ===
Current Branch: $GIT_BRANCH
Target Branch: $TARGET_BRANCH

=== RECENT COMMITS ===
$GIT_LOG

=== FULL GIT DIFF ===
$GIT_DIFF
EOF

echo "Git diff successfully saved to: $OUTPUT_FILE"
