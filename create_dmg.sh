#!/bin/bash

set -e

echo "📦 Creating DMG installer..."

# Build app bundle first if it doesn't exist
if [ ! -d "CalendarBarApp.app" ]; then
    echo "Building app bundle first..."
    ./create_app_bundle.sh
fi

DMG_NAME="CalendarBarApp-v1.0.0.dmg"
VOLUME_NAME="Calendar Bar Installer"
SOURCE_FOLDER="dmg_contents"

# Clean up any previous builds
rm -rf "$SOURCE_FOLDER"
rm -f "$DMG_NAME"

# Create temporary folder
mkdir -p "$SOURCE_FOLDER"

# Copy app to temp folder
cp -R CalendarBarApp.app "$SOURCE_FOLDER/"

# Create symlink to Applications folder
ln -s /Applications "$SOURCE_FOLDER/Applications"

# Create README
cat > "$SOURCE_FOLDER/README.txt" << 'EOF'
Calendar Bar - Installation Instructions
=========================================

INSTALLATION:
1. Drag "CalendarBarApp" to the "Applications" folder
2. Go to Applications folder and RIGHT-CLICK on CalendarBarApp
3. Select "Open" from the menu
4. Click "Open" in the dialog that appears

FIRST TIME SETUP:
- The app will prompt you to login with your Google account
- Click "Login with Google" and authorize calendar access
- The app will show events from: community@cardinalblue.com

FEATURES:
- Shows all-day events in menu bar
- Timezone selector (27 timezones)
- "Show other events" toggle to cycle through all events
- Auto-refresh every 30 minutes
- Manual refresh button

TROUBLESHOOTING:
If you see "CalendarBarApp cannot be opened":
1. Go to System Settings > Privacy & Security
2. Scroll down and click "Open Anyway"
3. Or use Terminal: xattr -cr /Applications/CalendarBarApp.app

For questions, contact: [Your Team Contact]

Copyright © 2025 Cardinal Blue. All rights reserved.
EOF

# Create DMG
echo "Creating DMG..."
hdiutil create -volname "$VOLUME_NAME" \
    -srcfolder "$SOURCE_FOLDER" \
    -ov -format UDZO \
    "$DMG_NAME"

# Clean up
rm -rf "$SOURCE_FOLDER"

echo ""
echo "✅ DMG created: $DMG_NAME"
echo ""
echo "You can now distribute this DMG file!"
echo "Users can double-click to open and drag the app to Applications."
