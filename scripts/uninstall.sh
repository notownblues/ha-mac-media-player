#!/bin/bash
# MacMediaPlayer Uninstall Script
# Usage: ./scripts/uninstall.sh

APP_NAME="MacMediaPlayer"
INSTALL_DIR="/Applications"

echo "============================================"
echo "  MacMediaPlayer Uninstaller"
echo "============================================"
echo ""

# Kill app if running
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Stopping $APP_NAME..."
    pkill -x "$APP_NAME" || true
    sleep 1
fi

# Remove app
if [ -d "$INSTALL_DIR/$APP_NAME.app" ]; then
    echo "Removing $APP_NAME.app..."
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    echo "✓ $APP_NAME has been uninstalled"
else
    echo "$APP_NAME is not installed in $INSTALL_DIR"
fi

# Optionally remove preferences
PREFS_FILE="$HOME/Library/Preferences/com.macmediaplayer.app.plist"
if [ -f "$PREFS_FILE" ]; then
    read -p "Remove preferences? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f "$PREFS_FILE"
        echo "✓ Preferences removed"
    fi
fi

echo ""
echo "Uninstall complete."
