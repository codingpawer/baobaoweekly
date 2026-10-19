import Foundation

/// A run of consecutive blocks on one day with the same category and text.
struct GridSegment: Identifiable, Hashable {
    let dayIndex: Int
    let start: Int
    let count: Int
    let categoryUID: UUID?
    let text: String

    var id: String { "\(dayIndex)-\(start)" }
    var end: Int { start + count }
}

enum SegmentBuilder {
    /// `dayIndex(for:)` maps a block's dayStart to a column (nil = ignore).
    static func build(_ blocks: [PlanBlock], dayIndex: (Date) -> Int?) -> [GridSegment] {
        var grid: [Int: [Int: PlanBlock]] = [:]
        for b in blocks {
            guard let col = dayIndex(b.dayStart), b.slot >= 0, b.slot < Cal.slotsPerDay else { continue }
            if b.categoryUID == nil && b.text.isEmpty { continue }
            grid[col, default: [:]][b.slot] = b
        }
        var result: [GridSegment] = []
        for (col, slots) in grid {
            var s = 0
            while s < Cal.slotsPerDay {
                guard let b = slots[s] else { s += 1; continue }
                var e = s + 1
                while e < Cal.slotsPerDay, let n = slots[e], n.categoryUID == b.categoryUID, n.text == b.text { e += 1 }
                result.append(GridSegment(dayIndex: col, start: s, count: e - s, categoryUID: b.categoryUID, text: b.text))
                s = e
            }
        }
        return result.sorted { ($0.dayIndex, $0.start) < ($1.dayIndex, $1.start) }
    }

    static func build(week blocks: [PlanBlock], weekStart: Date) -> [GridSegment] {
        let days = Cal.days(ofWeek: weekStart)
        var index: [Date: Int] = [:]
        for (i, d) in days.enumerated() { index[d] = i }
        return build(blocks) { index[Cal.dayStart($0)] }
    }

    static func build(day blocks: [PlanBlock]) -> [GridSegment] {
        build(blocks) { _ in 0 }
    }
}
