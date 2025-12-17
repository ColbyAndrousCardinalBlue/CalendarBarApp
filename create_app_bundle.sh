#!/bin/bash

set -e

echo "🔨 Building CalendarBarApp..."

# Build release version
swift build -c release

# Create app bundle structure
APP_NAME="CalendarBarApp"
APP_BUNDLE="${APP_NAME}.app"
CONTENTS_DIR="${APP_BUNDLE}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "📦 Creating app bundle structure..."
rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy binary
echo "📋 Copying binary..."
cp .build/release/CalendarBarApp "$MACOS_DIR/"

# Create Info.plist
echo "📄 Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>CalendarBarApp</string>
    <key>CFBundleIdentifier</key>
    <string>com.cardinalblue.calendarbarapp</string>
    <key>CFBundleName</key>
    <string>CalendarBarApp</string>
    <key>CFBundleDisplayName</key>
    <string>Calendar Bar</string>
    <key>CFBundleVersion</key>
    <string>1.0.0</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025 Cardinal Blue. All rights reserved.</string>
</dict>
</plist>
EOF

# Ad-hoc code sign (allows it to run on local machine)
echo "✍️  Signing app bundle..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo ""
echo "✅ Success! CalendarBarApp.app created"
echo ""
echo "To install:"
echo "  1. Drag CalendarBarApp.app to /Applications/"
echo "  2. Open from Applications folder (first time: right-click > Open)"
echo ""
echo "Or run directly:"
echo "  open $APP_BUNDLE"
