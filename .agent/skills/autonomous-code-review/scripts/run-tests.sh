#!/usr/bin/env bash
# Execute Quality Gates Test Suite script for Linux / macOS

echo "Checking Quality Gates (Build, Test, Lint)..."

if [ -f "go.mod" ]; then
    echo "Detected Go project..."
    go vet ./... || exit 1
    go test -v ./... || exit 1
elif [ -f "package.json" ]; then
    echo "Detected Node/TypeScript project..."
    npm test || exit 1
fi

echo "✅ ALL LOCAL TESTS PASSED!"
exit 0
