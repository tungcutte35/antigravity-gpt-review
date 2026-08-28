#!/usr/bin/env bash
set -e

CHROME_DIR="$HOME/.config/google-chrome-antigravity"
mkdir -p "$CHROME_DIR"

echo "[1] Checking for existing Antigravity CDP Chrome processes..."
if curl -s "http://127.0.0.1:9222/json/version" > /dev/null 2>&1; then
    echo "CDP Chrome is already running on port 9222."
else
    echo "[2] Launching Chrome with CDP on port 9222..."
    # Remove stale lock files to prevent immediate closure
    rm -f "$CHROME_DIR/SingletonLock" "$CHROME_DIR/SingletonSocket" "$CHROME_DIR/SingletonCookie"

    CHROME_BIN=""
    if command -v google-chrome &> /dev/null; then
        CHROME_BIN="google-chrome"
    elif command -v chromium &> /dev/null; then
        CHROME_BIN="chromium"
    elif command -v chromium-browser &> /dev/null; then
        CHROME_BIN="chromium-browser"
    else
        echo "ERROR: Chrome or Chromium binary not found!"
        exit 1
    fi

    # Reset crashed state in Preferences if present
    if [ -f "$CHROME_DIR/Default/Preferences" ]; then
        sed -i 's/"exit_type":"Crashed"/"exit_type":"Normal"/' "$CHROME_DIR/Default/Preferences" 2>/dev/null || true
        sed -i 's/"exited_cleanly":false/"exited_cleanly":true/' "$CHROME_DIR/Default/Preferences" 2>/dev/null || true
    fi

    # Use setsid to detach process completely from terminal subshell session
    DISPLAY="${DISPLAY:-:0}" setsid "$CHROME_BIN" \
        --remote-debugging-port=9222 \
        --user-data-dir="$CHROME_DIR" \
        --no-first-run \
        --disable-session-crashed-bubble \
        --hide-crash-restore-bubble \
        --disable-infobars \
        --no-default-browser-check \
        "https://chatgpt.com" </dev/null >/dev/null 2>&1 &
    
    echo "[3] Waiting 4 seconds for Chrome to start..."
    sleep 4
fi

echo "[4] Testing CDP Connection..."
if curl -s "http://127.0.0.1:9222/json/version" > /dev/null; then
    echo -e "\033[0;32mSUCCESS: CDP is running on port 9222!\033[0m"
    curl -s "http://127.0.0.1:9222/json/version"
else
    echo -e "\033[0;31mFAILED: Could not connect to CDP on http://127.0.0.1:9222\033[0m"
    exit 1
fi
