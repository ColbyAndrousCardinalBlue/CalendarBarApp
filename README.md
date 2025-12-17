# CalendarBarApp

A macOS menu bar application that displays all-day events from a shared Google Calendar.

<img width="400" alt="Calendar Bar in menu bar" src="https://via.placeholder.com/400x100/ffffff/000000?text=Calendar+Bar+Screenshot">

## Features

- 📅 **Google Calendar Integration** - OAuth 2.0 authentication
- 🌍 **Timezone Support** - 27 timezones for international teams
- 🔄 **Event Cycling** - Rotate through events or show only the current cycle
- ⏰ **Auto-refresh** - Updates every 30 minutes
- 🖥️ **Multi-monitor Support** - Adapts to display changes

## Installation

### For End Users

**Download the latest release:**
1. Download `CalendarBarApp-v1.0.0.dmg` from [Releases](../../releases)
2. Double-click the DMG to open
3. Drag CalendarBarApp to Applications folder
4. Right-click CalendarBarApp in Applications and select "Open"
5. Click "Open" in the security dialog

See [DISTRIBUTION.md](DISTRIBUTION.md) for detailed installation instructions and troubleshooting.

### For Developers

```bash
# Clone the repository
git clone https://github.com/ColbyAndrousCardinalBlue/CalendarBarApp.git
cd CalendarBarApp

# Build and run
swift build -c release
.build/release/CalendarBarApp
```

## Building for Distribution

```bash
# Create app bundle
./create_app_bundle.sh

# Create DMG installer
./create_dmg.sh
```

See [DISTRIBUTION.md](DISTRIBUTION.md) for complete distribution guide.

## Configuration

The app connects to the shared calendar: `community@cardinalblue.com`

**Calendar Settings:**
- Shows only all-day events (events lasting 1+ full days)
- Sorts by duration (longest events first)
- Prioritizes events containing "Cycle" in the title

## Usage

### Menu Bar Display

**Default:** Shows only the longest event
```
Discovery Week
```

**With "Show other events" enabled:** Cycles every 10 seconds
```
Discovery Week (1/2) → AI Hack Day (2/2) → ...
```

### Dropdown Menu

- **Today's Events** - List of all events with descriptions
- **Timezone** - Select your timezone (persists across launches)
- **Show other events** - Toggle event cycling
- **Refresh Now** - Manually refresh calendar
- **Logout** - Clear authentication and re-login
- **Quit** - Exit the application

## Requirements

- macOS 13.0 or later
- Swift 5.9+ (for building from source)
- Google account with access to the shared calendar

## Project Structure

```
CalendarBarApp/
├── Sources/
│   ├── App.swift                  # Main app & UI
│   ├── GoogleCalendarManager.swift # Calendar logic & state
│   └── OAuthManager.swift         # OAuth authentication
├── Package.swift                  # Swift Package Manager config
├── create_app_bundle.sh          # Build .app bundle
├── create_dmg.sh                 # Create DMG installer
└── DISTRIBUTION.md               # Distribution guide
```

## Development

**Build:**
```bash
swift build
```

**Run:**
```bash
.build/debug/CalendarBarApp
```

**Build release:**
```bash
swift build -c release
```

## Technical Details

- **Framework:** SwiftUI
- **Architecture:** MVVM with ObservableObject
- **API:** Google Calendar API v3
- **Authentication:** OAuth 2.0 with local callback server
- **Storage:** UserDefaults for tokens and preferences

## Security Note

OAuth credentials are currently embedded in the code. For production use, consider:
- Using environment variables
- Rotating credentials periodically
- Implementing proper credential management

## Contributing

This is an internal Cardinal Blue project. For questions or issues, contact the development team.

## License

Copyright © 2025 Cardinal Blue. All rights reserved.

## Changelog

### v1.0.0 (2025-12-17)
- Initial release
- Google Calendar OAuth integration
- All-day event filtering with timezone support
- Event cycling with "Show other events" toggle
- Auto-refresh every 30 minutes
- Multi-monitor support
- Logout functionality
