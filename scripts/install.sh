#!/bin/bash
# MacMediaPlayer Installation Script
# Usage: ./scripts/install.sh

set -e

APP_NAME="MacMediaPlayer"
INSTALL_DIR="/Applications"

echo "============================================"
echo "  MacMediaPlayer Installer"
echo "============================================"
echo ""

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "Error: Please run this script from the MacMediaPlayer directory"
    echo "  cd MacMediaPlayer && ./scripts/install.sh"
    exit 1
fi

# Check for required tools
if ! command -v swift &> /dev/null; then
    echo "Error: Swift is not installed"
    echo "Please install Xcode or Xcode Command Line Tools:"
    echo "  xcode-select --install"
    exit 1
fi

# Check for media-control dependency
echo "Checking dependencies..."
if ! command -v media-control &> /dev/null; then
    echo ""
    echo "Warning: media-control is not installed"
    echo "This is required for Now Playing functionality."
    echo ""
    read -p "Install media-control via Homebrew? [Y/n] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        if ! command -v brew &> /dev/null; then
            echo "Homebrew is not installed. Please install it from https://brew.sh"
            echo "Then run: brew tap ungive/media-control && brew install media-control"
        else
            brew tap ungive/media-control
            brew install media-control
        fi
    fi
fi

# Kill existing app if running
if pgrep -x "$APP_NAME" > /dev/null; then
    echo "Stopping existing $APP_NAME..."
    pkill -x "$APP_NAME" || true
    sleep 1
fi

# Build and install
echo ""
echo "Building $APP_NAME..."
make bundle

echo ""
echo "Installing to $INSTALL_DIR..."
make install

echo ""
echo "============================================"
echo "  Installation Complete!"
echo "============================================"
echo ""
echo "You can now:"
echo "  - Open $APP_NAME from Applications folder"
echo "  - Use Spotlight (Cmd+Space) and type '$APP_NAME'"
echo "  - Run: open -a $APP_NAME"
echo ""

# Ask to launch
read -p "Launch $APP_NAME now? [Y/n] " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
    open -a "$APP_NAME"
fi
