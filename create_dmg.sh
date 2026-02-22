#!/bin/bash
set -e

APP_NAME="Focus.app"
DMG_NAME="Focus.dmg"
STAGING_DIR="dmg_staging"

# Clean up previous build artifacts
rm -rf "$DMG_NAME" "$STAGING_DIR"

# Create staging directory
mkdir -p "$STAGING_DIR"

# Check if App exists
if [ ! -d "$APP_NAME" ]; then
    echo "Error: $APP_NAME not found. Please run package_app.sh first."
    exit 1
fi

# Copy App to staging
echo "Copying app to staging..."
cp -R "$APP_NAME" "$STAGING_DIR/"

# Create Link to Applications
echo "Creating Applications link..."
ln -s /Applications "$STAGING_DIR/Applications"

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "Focus" -srcfolder "$STAGING_DIR" -ov -format UDZO "$DMG_NAME"

# Cleanup
echo "Cleaning up..."
rm -rf "$STAGING_DIR"

echo "DMG created successfully: $DMG_NAME"
