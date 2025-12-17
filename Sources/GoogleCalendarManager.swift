import Foundation
import Combine

struct GoogleCalendarEvent: Identifiable, Codable {
    let id: String
    let summary: String
    let description: String?
    let start: EventDateTime
    let end: EventDateTime

    struct EventDateTime: Codable {
        let dateTime: String?
        let date: String?
    }

    var displayTitle: String {
        // If it's a Cycle event, try to extract day info from description
        if summary.contains("Cycle"), let desc = description {
            // Look for patterns like "15/24"
            let pattern = #"(\d+)/(\d+)"#
            if let regex = try? NSRegularExpression(pattern: pattern),
               let match = regex.firstMatch(in: desc, range: NSRange(desc.startIndex..., in: desc)),
               let currentRange = Range(match.range(at: 1), in: desc),
               let totalRange = Range(match.range(at: 2), in: desc),
               let current = Int(desc[currentRange]),
               let total = Int(desc[totalRange]) {
                return "\(summary), day \(current)/\(total)"
            }
        }
        return summary
    }

    var isAllDay: Bool {
        // All-day events have 'date' instead of 'dateTime'
        return start.date != nil
    }

    func isToday(in timezone: TimeZone) -> Bool {
        var calendar = Calendar.current
        calendar.timeZone = timezone
        let today = calendar.startOfDay(for: Date())

        // Check if today falls within the event's date range
        if let startDateStr = start.date, let endDateStr = end.date {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withFullDate]
            formatter.timeZone = timezone

            if let startDate = formatter.date(from: startDateStr),
               let endDate = formatter.date(from: endDateStr) {
                // Normalize to the specified timezone
                let localStartDate = calendar.startOfDay(for: startDate)
                let localEndDate = calendar.startOfDay(for: endDate)

                // For all-day events, end date is exclusive (next day after event ends)
                // Check if today is >= start and < end
                return today >= localStartDate && today < localEndDate
            }
        }

        return false
    }

    var durationInDays: Int {
        guard let startDateStr = start.date, let endDateStr = end.date else {
            return 0
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]

        if let startDate = formatter.date(from: startDateStr),
           let endDate = formatter.date(from: endDateStr) {
            let calendar = Calendar.current
            let days = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
            return days
        }

        return 0
    }
}

struct CalendarEventsResponse: Codable {
    let items: [GoogleCalendarEvent]?
}

class GoogleCalendarManager: ObservableObject {
    @Published var todayEvents: [GoogleCalendarEvent] = []
    @Published var menuBarTitle: String = "Loading..."
    @Published var needsAuthentication: Bool = false
    @Published var selectedTimezone: String {
        didSet {
            UserDefaults.standard.set(selectedTimezone, forKey: "selectedTimezone")
            fetchEvents() // Refresh when timezone changes
        }
    }
    @Published var showOtherEvents: Bool {
        didSet {
            UserDefaults.standard.set(showOtherEvents, forKey: "showOtherEvents")
            updateCycleTimer()
            updateMenuBarTitle()
        }
    }

    private let oauthManager = OAuthManager.shared
    private var refreshTimer: Timer?
    private var cycleTimer: Timer?
    private var currentEventIndex: Int = 0

    init() {
        // Load saved timezone or use current timezone
        self.selectedTimezone = UserDefaults.standard.string(forKey: "selectedTimezone") ?? TimeZone.current.identifier
        // Load saved showOtherEvents setting (default to false - show only longest event)
        self.showOtherEvents = UserDefaults.standard.bool(forKey: "showOtherEvents")
        checkAuthentication()
    }

    deinit {
        refreshTimer?.invalidate()
        cycleTimer?.invalidate()
    }

    private func checkAuthentication() {
        if oauthManager.hasValidTokens() {
            NSLog("✅ Has valid tokens, fetching events")
            fetchEvents()
            setupRefreshTimer()
        } else {
            NSLog("⚠️ No valid tokens, need authentication")
            DispatchQueue.main.async {
                self.needsAuthentication = true
                self.menuBarTitle = "Login Required"
            }
        }
    }

    func authenticate() {
        oauthManager.startOAuthFlow { [weak self] success in
            DispatchQueue.main.async {
                if success {
                    NSLog("✅ Authentication successful")
                    self?.needsAuthentication = false
                    self?.fetchEvents()
                    self?.setupRefreshTimer()
                } else {
                    NSLog("❌ Authentication failed")
                    self?.menuBarTitle = "Auth Failed"
                }
            }
        }
    }

    private func setupRefreshTimer() {
        // Refresh every 30 minutes
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30 * 60, repeats: true) { [weak self] _ in
            NSLog("⏰ Timer triggered - refreshing events")
            self?.fetchEvents()
        }
    }

    func fetchEvents() {
        guard let accessToken = oauthManager.getAccessToken() else {
            NSLog("❌ No access token available")
            needsAuthentication = true
            return
        }

        // Get today's date range
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else {
            return
        }

        // Format dates for API
        let formatter = ISO8601DateFormatter()
        let timeMin = formatter.string(from: startOfDay)
        let timeMax = formatter.string(from: endOfDay)

        // Build API URL - using specific shared calendar
        let calendarID = "community@cardinalblue.com"
        var components = URLComponents(string: "https://www.googleapis.com/calendar/v3/calendars/\(calendarID)/events")!
        components.queryItems = [
            URLQueryItem(name: "timeMin", value: timeMin),
            URLQueryItem(name: "timeMax", value: timeMax),
            URLQueryItem(name: "singleEvents", value: "true"),
            URLQueryItem(name: "orderBy", value: "startTime")
        ]

        guard let url = components.url else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        NSLog("🔍 Fetching events from Google Calendar...")

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                NSLog("❌ Fetch error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                NSLog("❌ No data received")
                return
            }

            // Check for 401 (token expired)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                NSLog("⚠️ Token expired, refreshing...")
                self?.oauthManager.refreshAccessToken { success in
                    if success {
                        self?.fetchEvents() // Retry
                    } else {
                        DispatchQueue.main.async {
                            self?.needsAuthentication = true
                        }
                    }
                }
                return
            }

            do {
                let decoder = JSONDecoder()
                let response = try decoder.decode(CalendarEventsResponse.self, from: data)

                let allEvents = response.items ?? []
                NSLog("📥 Received \(allEvents.count) total events from API")

                // Get the selected timezone
                guard let selectedTZ = TimeZone(identifier: self?.selectedTimezone ?? "") else {
                    NSLog("❌ Invalid timezone: \(self?.selectedTimezone ?? "")")
                    return
                }

                // Filter to only today's all-day events (in selected timezone)
                var events = allEvents.filter { $0.isToday(in: selectedTZ) && $0.isAllDay }

                // Sort: Longest events first, then by Cycle
                events.sort { a, b in
                    // Primary sort: by duration (longest first)
                    if a.durationInDays != b.durationInDays {
                        return a.durationInDays > b.durationInDays
                    }

                    // Secondary sort: Cycle events first
                    let aCycle = a.summary.contains("Cycle")
                    let bCycle = b.summary.contains("Cycle")

                    if aCycle && !bCycle {
                        return true
                    } else if !aCycle && bCycle {
                        return false
                    }
                    return false
                }

                NSLog("📅 Found \(events.count) all-day events for today")

                DispatchQueue.main.async {
                    self?.updateUI(with: events)
                }
            } catch {
                NSLog("❌ JSON parsing error: \(error.localizedDescription)")
                NSLog("Response: \(String(data: data, encoding: .utf8) ?? "")")
            }
        }.resume()
    }

    private func updateUI(with events: [GoogleCalendarEvent]) {
        self.todayEvents = events
        self.currentEventIndex = 0
        updateMenuBarTitle()
        updateCycleTimer()
    }

    private func updateCycleTimer() {
        // Stop existing cycle timer
        cycleTimer?.invalidate()
        cycleTimer = nil

        // Start cycle timer if "show other events" is enabled and there are multiple events
        if showOtherEvents && todayEvents.count > 1 {
            cycleTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
                self?.cycleToNextEvent()
            }
        }
    }

    private func cycleToNextEvent() {
        guard !todayEvents.isEmpty else { return }
        currentEventIndex = (currentEventIndex + 1) % todayEvents.count
        updateMenuBarTitle()
    }

    private func updateMenuBarTitle() {
        if todayEvents.isEmpty {
            self.menuBarTitle = "No Events Today"
            return
        }

        if showOtherEvents {
            // Cycle mode: show current event with indicator
            let event = todayEvents[currentEventIndex]
            if todayEvents.count > 1 {
                self.menuBarTitle = "\(event.displayTitle) (\(currentEventIndex + 1)/\(todayEvents.count))"
            } else {
                self.menuBarTitle = event.displayTitle
            }
        } else {
            // Show only the longest event (first one, since we sort by duration)
            self.menuBarTitle = todayEvents.first?.displayTitle ?? "No Events"
        }
    }

    func refreshNow() {
        NSLog("🔄 Manual refresh triggered")
        fetchEvents()
    }

    func logout() {
        NSLog("🔓 Logging out")
        oauthManager.clearTokens()
        refreshTimer?.invalidate()
        refreshTimer = nil

        DispatchQueue.main.async {
            self.needsAuthentication = true
            self.todayEvents = []
            self.menuBarTitle = "Login Required"
        }
    }

    func forceRefresh() {
        NSLog("🔄 Force refresh for display change")
        updateMenuBarTitle()
    }
}
