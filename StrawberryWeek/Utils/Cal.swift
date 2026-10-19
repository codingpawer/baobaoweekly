import Foundation

/// Calendar helpers. Weeks start on Monday; a "slot" is 30 minutes (0...47).
enum Cal {
    static let slotsPerDay = 48
    static let hoursPerSlot = 0.5

    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.firstWeekday = 2
        c.minimumDaysInFirstWeek = 4
        c.locale = Locale(identifier: "zh_CN")
        c.timeZone = .current
        return c
    }()

    static let weekdaySymbols = ["一", "二", "三", "四", "五", "六", "日"]

    static func dayStart(_ d: Date) -> Date { calendar.startOfDay(for: d) }

    static func startOfWeek(_ d: Date) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: d)?.start ?? dayStart(d)
    }

    static func add(days: Int, to d: Date) -> Date {
        calendar.date(byAdding: .day, value: days, to: d) ?? d
    }

    static func add(weeks: Int, to d: Date) -> Date { add(days: weeks * 7, to: d) }

    static func days(ofWeek weekStart: Date) -> [Date] {
        (0..<7).map { add(days: $0, to: weekStart) }
    }

    /// 0 = Monday ... 6 = Sunday
    static func weekdayIndex(_ d: Date) -> Int {
        (calendar.component(.weekday, from: d) + 5) % 7
    }

    static func isToday(_ d: Date) -> Bool { calendar.isDateInToday(d) }

    /// "10月 第2周": the week belongs to the month containing its Thursday.
    static func weekTitle(_ weekStart: Date) -> String {
        let thursday = add(days: 3, to: weekStart)
        let month = calendar.component(.month, from: thursday)
        let day = calendar.component(.day, from: thursday)
        return "\(month)月 第\((day - 1) / 7 + 1)周"
    }

    static func shortDate(_ d: Date) -> String {
        "\(calendar.component(.month, from: d))/\(calendar.component(.day, from: d))"
    }

    static func monthDay(_ d: Date) -> String {
        "\(calendar.component(.month, from: d))月\(calendar.component(.day, from: d))日"
    }

    static func weekdayName(_ d: Date) -> String { "周" + weekdaySymbols[weekdayIndex(d)] }

    static func fullDay(_ d: Date) -> String { "\(monthDay(d)) \(weekdayName(d))" }

    static func year(_ d: Date) -> Int { calendar.component(.year, from: d) }

    /// "2026年10月11日 周日"
    static func fullDayWithYear(_ d: Date) -> String { "\(year(d))年\(fullDay(d))" }

    /// Adds the year only when `d` is not in the current year: "10月11日 周日" / "2025年12月31日 周三".
    static func fullDayYearIfNeeded(_ d: Date, now: Date = Date()) -> String {
        year(d) == year(now) ? fullDay(d) : fullDayWithYear(d)
    }

    /// Week range with the year: "2026年 10/5 – 10/11"; across New Year "2026/12/28 – 2027/1/3".
    static func weekRangeText(_ weekStart: Date) -> String {
        let last = add(days: 6, to: weekStart)
        if year(weekStart) == year(last) {
            return "\(year(weekStart))年 \(shortDate(weekStart)) – \(shortDate(last))"
        }
        return "\(year(weekStart))/\(shortDate(weekStart)) – \(year(last))/\(shortDate(last))"
    }

    static func dayNumber(_ d: Date) -> Int { calendar.component(.day, from: d) }

    /// "2026-10-05" in the user's calendar/time zone.
    static func isoDate(_ d: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: d)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func slotTime(_ slot: Int) -> String {
        String(format: "%02d:%02d", slot / 2, (slot % 2) * 30)
    }

    static func slotRange(_ start: Int, count: Int) -> String {
        "\(slotTime(start)) – \(slotTime(start + count))"
    }

    static func hoursText(_ hours: Double) -> String {
        if hours == hours.rounded() { return "\(Int(hours))" }
        return String(format: "%.1f", hours)
    }

    static func hoursText(slots: Int) -> String { hoursText(Double(slots) * hoursPerSlot) }
}
