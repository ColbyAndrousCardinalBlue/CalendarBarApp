import SwiftUI
import AppKit

@main
struct CalendarBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var calendarManager = GoogleCalendarManager()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(calendarManager: calendarManager)
        } label: {
            Text(calendarManager.menuBarTitle)
                .foregroundColor(.green)
        }
        .onChange(of: appDelegate.displayChangeCounter) { _ in
            calendarManager.forceRefresh()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate, ObservableObject {
    @Published var displayChangeCounter = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - run as menu bar only app
        NSApp.setActivationPolicy(.accessory)

        // Listen for display configuration changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }

    @objc func screenParametersChanged(_ notification: Notification) {
        NSLog("🖥️ Display configuration changed")

        // Force menu bar to refresh by toggling activation policy
        DispatchQueue.main.async {
            NSApp.setActivationPolicy(.regular)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.setActivationPolicy(.accessory)
                // Trigger UI update
                self.displayChangeCounter += 1
            }
        }
    }
}

struct MenuBarView: View {
    @ObservedObject var calendarManager: GoogleCalendarManager

    // One representative city per timezone offset
    let timezones: [(label: String, identifier: String)] = [
        ("GMT-12 (Baker Island)", "Etc/GMT+12"),
        ("GMT-11 (Samoa)", "Pacific/Samoa"),
        ("GMT-10 (Honolulu)", "Pacific/Honolulu"),
        ("GMT-9 (Anchorage)", "America/Anchorage"),
        ("GMT-8 (Los Angeles)", "America/Los_Angeles"),
        ("GMT-7 (Denver)", "America/Denver"),
        ("GMT-6 (Chicago)", "America/Chicago"),
        ("GMT-5 (New York)", "America/New_York"),
        ("GMT-4 (Santiago)", "America/Santiago"),
        ("GMT-3 (Buenos Aires)", "America/Argentina/Buenos_Aires"),
        ("GMT-2 (South Georgia)", "Atlantic/South_Georgia"),
        ("GMT-1 (Cape Verde)", "Atlantic/Cape_Verde"),
        ("GMT+0 (London)", "Europe/London"),
        ("GMT+1 (Paris)", "Europe/Paris"),
        ("GMT+2 (Cairo)", "Africa/Cairo"),
        ("GMT+3 (Moscow)", "Europe/Moscow"),
        ("GMT+4 (Dubai)", "Asia/Dubai"),
        ("GMT+5 (Karachi)", "Asia/Karachi"),
        ("GMT+5:30 (Mumbai)", "Asia/Kolkata"),
        ("GMT+6 (Dhaka)", "Asia/Dhaka"),
        ("GMT+7 (Bangkok)", "Asia/Bangkok"),
        ("GMT+8 (Taipei)", "Asia/Taipei"),
        ("GMT+9 (Tokyo)", "Asia/Tokyo"),
        ("GMT+10 (Sydney)", "Australia/Sydney"),
        ("GMT+11 (Noumea)", "Pacific/Noumea"),
        ("GMT+12 (Auckland)", "Pacific/Auckland"),
        ("GMT+13 (Tonga)", "Pacific/Tongatapu")
    ]

    var currentTimezoneLabel: String {
        timezones.first(where: { $0.identifier == calendarManager.selectedTimezone })?.label ?? calendarManager.selectedTimezone
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if calendarManager.needsAuthentication {
                Text("Login Required")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Button(action: {
                    calendarManager.authenticate()
                }) {
                    HStack {
                        Image(systemName: "person.circle")
                        Text("Login with Google")
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
                .padding(.vertical, 8)

                Text("Click to authorize calendar access")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

            } else if calendarManager.todayEvents.isEmpty {
                Text("No Events Today")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)
            } else {
                Text("Today's Events")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top, 8)

                Divider()

                ForEach(calendarManager.todayEvents) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(event.displayTitle)
                            .font(.body)
                            .fontWeight(.medium)

                        if let desc = event.description, !desc.isEmpty {
                            Text(desc)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }

            Divider()

            // Timezone Picker
            VStack(alignment: .leading, spacing: 4) {
                Text("Timezone")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)

                Menu {
                    ForEach(timezones, id: \.identifier) { timezone in
                        Button(timezone.label) {
                            calendarManager.selectedTimezone = timezone.identifier
                        }
                    }
                } label: {
                    HStack {
                        Text(currentTimezoneLabel)
                            .font(.body)
                        Spacer()
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
            .padding(.vertical, 4)

            Divider()

            // Show Other Events Toggle
            Toggle(isOn: $calendarManager.showOtherEvents) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Show other events")
                        .font(.body)
                    Text("Rotate through all events every 10 seconds")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)

            Divider()

            Button(action: {
                calendarManager.refreshNow()
            }) {
                HStack {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh Now")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 4)

            if !calendarManager.needsAuthentication {
                Divider()

                Button(action: {
                    calendarManager.logout()
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Logout")
                    }
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
                .padding(.vertical, 4)
            }

            Divider()

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                HStack {
                    Image(systemName: "xmark.circle")
                    Text("Quit")
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.vertical, 4)
            .padding(.bottom, 8)
        }
        .frame(minWidth: 250)
    }
}
