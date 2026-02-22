#!/bin/bash
set -e

# Configuration
APP_NAME="Focus"
EXECUTABLE_NAME="Focus"
ICON_SOURCE="FocusAppIcon.icns"
OUTPUT_DMG="Focus.dmg"
BUILD_ARCH_DIR=".build/release"

echo "🚀 Starting Packaging Process..."

# 1. Update Icon
echo "🎨 Updating App Icon..."
cp "$ICON_SOURCE" "Resources/AppIcon.icns"
mkdir -p "Sources/Resources"
cp "$ICON_SOURCE" "Sources/Resources/AppIcon.icns"

# 2. Build Release
echo "🔨 Building Release Configuration..."
swift build -c release

# 3. Create Bundle Structure
echo "📦 Creating App Bundle..."
rm -rf "$APP_NAME.app"
mkdir -p "$APP_NAME.app/Contents/MacOS"
mkdir -p "$APP_NAME.app/Contents/Resources"

# Copy Binary
cp ".build/release/$EXECUTABLE_NAME" "$APP_NAME.app/Contents/MacOS/$EXECUTABLE_NAME"
chmod +x "$APP_NAME.app/Contents/MacOS/$EXECUTABLE_NAME"

# Copy Icon
cp "Resources/AppIcon.icns" "$APP_NAME.app/Contents/Resources/AppIcon.icns"

# Copy SwiftPM resource bundle(s) (required for Bundle.module to work once the app is moved)
echo "📎 Embedding SwiftPM resource bundles..."
if [ -d "$BUILD_ARCH_DIR" ]; then
    shopt -s nullglob
    BUNDLES=("$BUILD_ARCH_DIR"/*.bundle)
    shopt -u nullglob
    if [ ${#BUNDLES[@]} -eq 0 ]; then
        echo "⚠️  No .bundle resources found in $BUILD_ARCH_DIR (unexpected for this package)."
    else
        for b in "${BUNDLES[@]}"; do
            echo "  - Copying $(basename "$b")"
            cp -R "$b" "$APP_NAME.app/Contents/Resources/"
        done
    fi
else
    echo "⚠️  Build output directory not found: $BUILD_ARCH_DIR"
fi

# Create Info.plist (ensure icon name matches)
cat <<EOF > "$APP_NAME.app/Contents/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$EXECUTABLE_NAME</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.lungusebi.focus</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.2</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSRemindersUsageDescription</key>
    <string>Focus needs access to your reminders to help you stay on task.</string>
    <key>NSCalendarsUsageDescription</key>
    <string>Focus needs access to your calendar events.</string>
</dict>
</plist>
EOF

# 4. Code Sign
echo "✍️  Code Signing..."
xattr -rc "$APP_NAME.app"
codesign --force --deep --sign - "$APP_NAME.app"

# 5. Create DMG
echo "💿 Creating DMG..."
rm -rf dmg_staging
mkdir -p dmg_staging
cp -r "$APP_NAME.app" dmg_staging/
ln -s /Applications dmg_staging/Applications

rm -f "$OUTPUT_DMG"
hdiutil create -volname "$APP_NAME Installer" -srcfolder dmg_staging -ov -format UDZO "$OUTPUT_DMG"

# Cleanup
rm -rf dmg_staging

echo "✅ Packaging Complete!"
echo "Created: $(pwd)/$OUTPUT_DMG"
