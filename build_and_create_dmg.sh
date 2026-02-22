#!/bin/bash
set -e

# Define variables
APP_NAME="Focus.app"
DMG_NAME="Focus.dmg"
BUILD_SCRIPT="package_dmg.sh"

echo "Starting Build Process..."

# Ensure we are in the script's directory
cd "$(dirname "$0")"

# 1. Package the app (script handles release build + DMG creation)
echo "Packaging App..."
if [ -f "$BUILD_SCRIPT" ]; then
    chmod +x "$BUILD_SCRIPT"
    ./"$BUILD_SCRIPT"
else
    echo "Error: $BUILD_SCRIPT not found!"
    exit 1
fi

# 2. Validate output
echo "Validating output..."
if [ -d "$APP_NAME" ]; then
    # package_dmg.sh already creates the DMG in the current directory
    if [ -f "$DMG_NAME" ]; then
        echo "DMG Created Successfully: $DMG_NAME"
        echo "Location: $(pwd)/$DMG_NAME"
    else
        echo "Error: Expected $DMG_NAME to be created by $BUILD_SCRIPT, but it was not found."
        exit 1
    fi
else
    echo "Error: $APP_NAME not found after packaging!"
    exit 1
fi

echo "Done!"
