import Foundation

/// Converts dates to and from "yyyy-MM-dd" keys using the device's local calendar.
struct DayKey {
    var calendar: Calendar

    init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    func key(for date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    func date(for key: String) -> Date? {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Keys for the last `count` days ending today, oldest first.
    func lastDays(_ count: Int, endingAt now: Date) -> [String] {
        let today = calendar.startOfDay(for: now)
        return (0..<count).reversed().compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: today).map(key(for:))
        }
    }
}
