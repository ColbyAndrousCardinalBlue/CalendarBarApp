# Distribution Guide

## For Distributors (Building the App)

### Quick Start
```bash
# Create app bundle
./create_app_bundle.sh

# Create DMG installer (recommended)
./create_dmg.sh
```

### What Gets Created

1. **CalendarBarApp.app** - The application bundle
   - Can be dragged to Applications folder
   - Properly signed with ad-hoc signature (works on local machine)

2. **CalendarBarApp-v1.0.0.dmg** - DMG installer
   - Professional installation experience
   - Includes Applications folder symlink for easy drag-and-drop
   - Includes README with instructions

### Distribution Options

#### Option A: Share the DMG (Recommended)
- Upload `CalendarBarApp-v1.0.0.dmg` to company file share
- Users double-click DMG and drag app to Applications
- Most user-friendly option

#### Option B: Share the .app Bundle
- Zip the `CalendarBarApp.app` folder
- Share the zip file
- Users unzip and drag to Applications

#### Option C: GitHub Release
```bash
# Create a GitHub release
gh release create v1.0.0 CalendarBarApp-v1.0.0.dmg \
  --title "Calendar Bar v1.0.0" \
  --notes "Initial release"
```

## For End Users (Installing the App)

### Installation from DMG

1. **Download** `CalendarBarApp-v1.0.0.dmg`
2. **Double-click** the DMG to open it
3. **Drag** CalendarBarApp to the Applications folder
4. **Open** Applications folder
5. **Right-click** on CalendarBarApp and select "Open"
6. Click **"Open"** in the security dialog

### First Time Setup

1. The app appears in your menu bar (look for green text)
2. Click the menu bar item
3. Click **"Login with Google"**
4. Authorize calendar access in your browser
5. Done! Events will appear in the menu bar

### Troubleshooting

**"CalendarBarApp cannot be opened"**
- Go to System Settings > Privacy & Security
- Scroll down and click "Open Anyway"

**Or use Terminal:**
```bash
xattr -cr /Applications/CalendarBarApp.app
```

**App not showing in menu bar:**
- Make sure it's running (check Activity Monitor)
- Try quitting and reopening
- Check that your monitor is set as the primary display

**No events showing:**
- Make sure you're logged in (check dropdown menu)
- Verify you have access to the community@cardinalblue.com calendar
- Try clicking "Refresh Now"

## Features

- **All-day events only** - Shows events that are full days or longer
- **Timezone selector** - 27 timezones for international teams
- **Cycling mode** - Toggle "Show other events" to rotate through all events
- **Auto-refresh** - Updates every 30 minutes
- **Manual refresh** - Click "Refresh Now" anytime
- **Multi-monitor support** - Automatically adapts to display changes

## Requirements

- macOS 13.0 or later
- Google account with access to community@cardinalblue.com calendar

## Support

For issues or questions, contact [Your Team/Email]

## Version History

### v1.0.0 (2025-12-17)
- Initial release
- Google Calendar integration
- Timezone support
- Event cycling
- Multi-monitor support
