import Foundation
import SwiftUI

enum ReportScope: String, CaseIterable, Identifiable {
    case week = "周", month = "月", quarter = "季度", year = "年度"
    var id: String { rawValue }

    var bucketName: String {
        switch self {
        case .week, .month: return "每天"
        case .quarter: return "每周"
        case .year: return "每月"
        }
    }
}

struct ReportPeriod: Equatable {
    let scope: ReportScope
    let start: Date
    let end: Date   // exclusive

    static func make(_ scope: ReportScope, containing date: Date) -> ReportPeriod {
        let cal = Cal.calendar
        switch scope {
        case .week:
            let s = Cal.startOfWeek(date)
            return ReportPeriod(scope: scope, start: s, end: Cal.add(days: 7, to: s))
        case .month:
            let s = cal.date(from: cal.dateComponents([.year, .month], from: date))!
            return ReportPeriod(scope: scope, start: s, end: cal.date(byAdding: .month, value: 1, to: s)!)
        case .quarter:
            let y = cal.component(.year, from: date)
            let m = cal.component(.month, from: date)
            let qm = ((m - 1) / 3) * 3 + 1
            let s = cal.date(from: DateComponents(year: y, month: qm, day: 1))!
            return ReportPeriod(scope: scope, start: s, end: cal.date(byAdding: .month, value: 3, to: s)!)
        case .year:
            let y = cal.component(.year, from: date)
            let s = cal.date(from: DateComponents(year: y, month: 1, day: 1))!
            return ReportPeriod(scope: scope, start: s, end: cal.date(byAdding: .year, value: 1, to: s)!)
        }
    }

    func shifted(by n: Int) -> ReportPeriod {
        let cal = Cal.calendar
        let anchor: Date
        switch scope {
        case .week: anchor = Cal.add(weeks: n, to: start)
        case .month: anchor = cal.date(byAdding: .month, value: n, to: start)!
        case .quarter: anchor = cal.date(byAdding: .month, value: 3 * n, to: start)!
        case .year: anchor = cal.date(byAdding: .year, value: n, to: start)!
        }
        return .make(scope, containing: anchor)
    }

    var dayCount: Int {
        Cal.calendar.dateComponents([.day], from: start, to: end).day ?? 0
    }

    var title: String {
        let cal = Cal.calendar
        let y = cal.component(.year, from: start)
        switch scope {
        case .week: return Cal.weekTitle(start)
        case .month: return "\(y)年\(cal.component(.month, from: start))月"
        case .quarter: return "\(y)年 第\((cal.component(.month, from: start) - 1) / 3 + 1)季度"
        case .year: return "\(y)年"
        }
    }

    var subtitle: String {
        if scope == .week { return Cal.weekRangeText(start) }
        return "\(Cal.shortDate(start)) – \(Cal.shortDate(Cal.add(days: -1, to: end)))"
    }

    func contains(_ d: Date) -> Bool { d >= start && d < end }

    /// Every calendar day in the period, in order.
    var days: [Date] { (0..<dayCount).map { Cal.add(days: $0, to: start) } }

    /// Long, unambiguous label for exports, e.g. "2026年10月 第2周 (2026-10-05 ~ 2026-10-11)".
    var exportTitle: String {
        let last = Cal.add(days: -1, to: end)
        let range = "(\(Cal.isoDate(start)) ~ \(Cal.isoDate(last)))"
        switch scope {
        case .week:
            let year = Cal.calendar.component(.year, from: Cal.add(days: 3, to: start))
            return "\(year)年\(title) \(range)"
        case .month, .quarter, .year:
            return "\(title) \(range)"
        }
    }

    /// Chart buckets: days (week), weeks (quarter), months (year).
    func buckets() -> [(key: Date, label: String)] {
        let cal = Cal.calendar
        switch scope {
        case .week:
            return Cal.days(ofWeek: start).map { ($0, Cal.weekdaySymbols[Cal.weekdayIndex($0)]) }
        case .month:
            return (0..<dayCount).map {
                let d = Cal.add(days: $0, to: start)
                return (d, "\(Cal.dayNumber(d))")
            }
        case .quarter:
            var out: [(Date, String)] = []
            var w = Cal.startOfWeek(start)
            while w < end { out.append((w, Cal.shortDate(max(w, start)))); w = Cal.add(weeks: 1, to: w) }
            return out
        case .year:
            return (0..<12).map {
                let m = cal.date(byAdding: .month, value: $0, to: start)!
                return (m, "\($0 + 1)月")
            }
        }
    }

    func bucketKey(for day: Date) -> Date {
        let cal = Cal.calendar
        switch scope {
        case .week, .month: return Cal.dayStart(day)
        case .quarter: return Cal.startOfWeek(day)
        case .year:
            return cal.date(from: cal.dateComponents([.year, .month], from: day)) ?? day
        }
    }
}

struct CategoryTotal: Identifiable {
    let uid: UUID
    let name: String
    let fill: Color
    let text: Color
    let slots: Int
    let share: Double   // of planned time
    var id: UUID { uid }
    var hours: Double { Double(slots) * Cal.hoursPerSlot }
}

struct ReportData {
    let rows: [CategoryTotal]
    let plannedSlots: Int
    let totalSlots: Int
    var plannedHours: Double { Double(plannedSlots) * Cal.hoursPerSlot }
    var freeHours: Double { Double(totalSlots - plannedSlots) * Cal.hoursPerSlot }
    var totalHours: Double { Double(totalSlots) * Cal.hoursPerSlot }
}

struct DayStat: Identifiable {
    /// Label for blocks with no text. UI only; the CSV 明细表 keeps 内容 empty.
    static let untitled = "（未填写）"

    let day: Date
    let slots: Int
    let texts: [(text: String, count: Int)]
    var id: Date { day }
}

enum ReportCalculator {
    static func compute(blocks: [PlanBlock], categories: [PlanCategory], period: ReportPeriod) -> ReportData {
        var counts: [UUID: Int] = [:]
        for b in blocks where period.contains(b.dayStart) {
            if let uid = b.categoryUID { counts[uid, default: 0] += 1 }
        }
        let known = categories.filter { counts[$0.uid] != nil }
        let planned = known.reduce(0) { $0 + (counts[$1.uid] ?? 0) }
        let rows = categories.compactMap { c -> CategoryTotal? in
            guard let n = counts[c.uid], n > 0 else { return nil }
            return CategoryTotal(uid: c.uid, name: c.name, fill: c.fill, text: c.textColor,
                                 slots: n, share: planned > 0 ? Double(n) / Double(planned) : 0)
        }.sorted { $0.slots > $1.slots }
        return ReportData(rows: rows, plannedSlots: planned, totalSlots: period.dayCount * Cal.slotsPerDay)
    }

    static func dayStats(_ blocks: [PlanBlock]) -> [DayStat] {
        let byDay = Dictionary(grouping: blocks) { Cal.dayStart($0.dayStart) }
        return byDay.map { day, bs in
            var order: [String] = []
            var c: [String: Int] = [:]
            for b in bs.sorted(by: { $0.slot < $1.slot }) {
                let trimmed = b.text.trimmingCharacters(in: .whitespacesAndNewlines)
                let t = trimmed.isEmpty ? DayStat.untitled : trimmed
                if c[t] == nil { order.append(t) }
                c[t, default: 0] += 1
            }
            return DayStat(day: day, slots: bs.count, texts: order.map { ($0, c[$0]!) })
        }.sorted { $0.day > $1.day }
    }
}
